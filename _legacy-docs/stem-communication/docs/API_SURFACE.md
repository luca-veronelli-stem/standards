# API Surface - STEM Communication Protocol

> **Versione:** 0.6.0  
> **Ultimo aggiornamento:** 2026-02-27

Questo documento descrive l'API pubblica della libreria STEM Communication Protocol per facilitare l'integrazione in applicazioni .NET.

---

## Indice

- [Quick Start](#quick-start)
- [ProtocolStack](#protocolstack)
- [CancellationToken Support (T-024)](#cancellationtoken-support-t-024)
- [Connection Events (STK-012)](#connection-events-stk-012)
- [Protocol Events (T-021)](#protocol-events-t-021)
- [Driver BLE](#driver-ble)
- [Driver CAN](#driver-can)
- [Tipi Comuni](#tipi-comuni)
- [Breaking Changes v0.6.0](#breaking-changes-v060)

---

## Quick Start

```csharp
using Stem.Communication.Protocol.Layers.Stack;
using Stem.Communication.Protocol.Infrastructure;
using Stem.Communication.Drivers.Ble;

// 1. Crea driver BLE
var bleConfig = new BleChannelConfiguration { DeviceMacAddress = "AA:BB:CC:DD:EE:FF" };
var driver = BleChannelDriverFactory.Create(bleConfig);

// 2. Costruisci lo stack
var stack = new ProtocolStackBuilder()
    .WithLocalDeviceId(0x00030141)
    .WithChannelDriver(driver)
    .Build();

// 3. Sottoscrivi eventi connessione
stack.ConnectionStateChanged += (s, e) =>
{
    Console.WriteLine($"Connection: {e.PreviousState} -> {e.CurrentState}");
    if (!e.IsConnected && !e.WasExpected)
        Console.WriteLine($"Disconnected unexpectedly: {e.Reason}");
};

// 4. Inizializza e usa (con CancellationToken - T-024)
using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
await stack.InitializeAsync(cts.Token);
await stack.SendAsync(data, destinationId, cts.Token);
var received = await stack.ReceiveAsync(cts.Token);

// 5. Cleanup
await stack.DisposeAsync();
```

---

## ProtocolStack

### Namespace
```csharp
using Stem.Communication.Protocol.Layers.Stack;
```

### Creazione con Builder

```csharp
var stack = new ProtocolStackBuilder()
    .WithLocalDeviceId(uint deviceId)           // Obbligatorio
    .WithChannelDriver(IChannelDriver driver)   // Obbligatorio
    .WithEncryption(CryptType type, byte[] key) // Opzionale
    .WithBroadcastAddress(uint address)         // Default: 0x1FFFFFFF
    .Build();
```

### Proprietà

| Proprietà | Tipo | Descrizione |
|-----------|------|-------------|
| `IsInitialized` | `bool` | True se lo stack è inizializzato |
| `LocalDeviceId` | `uint` | ID dispositivo locale |
| `ChannelType` | `ChannelType` | Tipo canale (CAN, BLE, UART, Cloud) |

### Metodi Principali

```csharp
// Inizializzazione
Task InitializeAsync(CancellationToken ct = default);

// Invio dati
Task<LayerResult> SendAsync(byte[] data, uint destinationId, CancellationToken ct = default);

// Ricezione dati
Task<byte[]?> ReceiveAsync(CancellationToken ct = default);

// Cleanup
ValueTask DisposeAsync();
```

### Eventi

| Evento | Tipo | Descrizione |
|--------|------|-------------|
| `ConnectionStateChanged` | `EventHandler<ConnectionStateChangedEventArgs>` | Cambio stato connessione |

---

## CancellationToken Support (T-024)

A partire dalla versione **0.6.0**, tutti i metodi asincroni accettano un `CancellationToken` opzionale per supportare la cancellazione cooperativa.

### Vantaggi

- **Timeout configurabili:** Imposta timeout personalizzati per operazioni lunghe
- **Cancellazione UI:** Permetti all'utente di annullare operazioni in corso
- **Graceful shutdown:** Interrompi operazioni durante lo shutdown dell'applicazione

### Pattern Raccomandato

```csharp
// Timeout globale per l'operazione
using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30));

try
{
    await stack.InitializeAsync(cts.Token);
    await stack.SendAsync(data, destinationId, cts.Token);
    var response = await stack.ReceiveAsync(cts.Token);
}
catch (OperationCanceledException)
{
    _logger.LogWarning("Operation cancelled or timed out");
}
```

### Linked CancellationToken

Per combinare timeout con cancellazione utente:

```csharp
// Token cancellazione utente (es. pulsante "Cancel")
CancellationToken userToken = _userCts.Token;

// Combinato con timeout
using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(userToken);
linkedCts.CancelAfter(TimeSpan.FromSeconds(10));

await stack.SendAsync(data, destination, linkedCts.Token);
```

### Metodi con CancellationToken

| Componente | Metodo | Descrizione |
|------------|--------|-------------|
| **ProtocolStack** | `InitializeAsync(ct)` | Inizializzazione stack |
| **ProtocolStack** | `UninitializeAsync(ct)` | De-inizializzazione |
| **ProtocolStack** | `SendAsync(data, dest, ct)` | Invio dati |
| **ProtocolStack** | `ReceiveAsync(ct)` | Ricezione dati |
| **IProtocolLayer** | `ProcessUpstreamAsync(data, ctx, ct)` | Processing layer |
| **IProtocolLayer** | `ProcessDownstreamAsync(data, ctx, ct)` | Processing layer |
| **IChannelDriver** | `ReadAsync(ct)` | Lettura dal canale |
| **IChannelDriver** | `WriteAsync(data, ct)` | Scrittura sul canale |

---

## Connection Events (STK-012)

### Namespace
```csharp
using Stem.Communication.Protocol.Infrastructure;
```

### ConnectionState Enum

```csharp
public enum ConnectionState
{
    Disconnected = 0,   // Non connesso
    Connecting = 1,     // Connessione in corso
    Connected = 2,      // Connesso e operativo
    Reconnecting = 3    // Riconnessione automatica in corso
}
```

### ConnectionStateChangedEventArgs

```csharp
public sealed class ConnectionStateChangedEventArgs : EventArgs
{
    // Stato precedente
    public ConnectionState PreviousState { get; }
    
    // Stato corrente
    public ConnectionState CurrentState { get; }
    
    // Motivo del cambio (opzionale)
    public string? Reason { get; }
    
    // True se disconnessione richiesta dall'utente
    public bool WasExpected { get; }
    
    // True se verrà tentata riconnessione automatica
    public bool WillAttemptReconnect { get; }
    
    // Timestamp UTC del cambio
    public DateTime Timestamp { get; }
    
    // Convenience: CurrentState == Connected
    public bool IsConnected { get; }
    
    // Convenience: CurrentState è Connecting o Reconnecting
    public bool IsConnecting { get; }
}
```

### Invarianti

- `PreviousState` ≠ `CurrentState` (sempre)
- Se `WasExpected` = true → `WillAttemptReconnect` = false

### Sequenze Tipiche

**Connessione riuscita:**
```
Disconnected -> Connecting -> Connected
```

**Connessione fallita:**
```
Disconnected -> Connecting -> Disconnected (Reason: "Connection failed")
```

**Disconnessione utente:**
```
Connected -> Disconnected (WasExpected: true, WillAttemptReconnect: false)
```

**Disconnessione inattesa con auto-reconnect:**
```
Connected -> Disconnected (WasExpected: false, WillAttemptReconnect: true)
         -> Reconnecting -> Connected
```

**Auto-reconnect fallito:**
```
Connected -> Disconnected -> Reconnecting -> Disconnected (Reason: "Reconnect failed")
```

### Esempio Completo

```csharp
stack.ConnectionStateChanged += (sender, e) =>
{
    // Log transizione
    _logger.LogInformation(
        "Connection state: {Previous} -> {Current}, Reason: {Reason}",
        e.PreviousState, e.CurrentState, e.Reason ?? "N/A");

    // Gestione UI
    switch (e.CurrentState)
    {
        case ConnectionState.Disconnected:
            if (!e.WasExpected)
            {
                ShowNotification("Connection lost!");
                if (e.WillAttemptReconnect)
                    ShowStatus("Reconnecting...");
            }
            break;

        case ConnectionState.Connecting:
            ShowStatus("Connecting...");
            break;

        case ConnectionState.Connected:
            if (e.PreviousState == ConnectionState.Reconnecting)
                ShowNotification("Reconnected!");
            else
                ShowNotification("Connected!");
            break;

        case ConnectionState.Reconnecting:
            ShowStatus($"Reconnecting... ({e.Reason})");
            break;
    }
};
```

---

## Protocol Events (T-021)

Gli eventi del protocollo usano EventArgs tipizzati conformi a [EVENTARGS_STANDARD.md](Standards/EVENTARGS_STANDARD.md).

**Caratteristiche comuni:**
- Tutti derivano da `System.EventArgs`
- Tutti includono `DateTime Timestamp` (UTC)
- Proprietà immutabili (readonly)
- Invarianti validati nel costruttore

### SessionLayer Events

#### SessionExpiredEventArgs

Sollevato quando una sessione scade per timeout di inattività.

```csharp
public sealed class SessionExpiredEventArgs : EventArgs
{
    public uint RemoteDeviceId { get; }      // SRID dispositivo remoto
    public TimeSpan SessionDuration { get; } // Durata prima della scadenza
    public DateTime Timestamp { get; }       // UTC
}
```

**Invarianti:** `RemoteDeviceId ≠ 0`, `SessionDuration ≥ 0`

#### SessionHijackAttemptedEventArgs

Sollevato quando un dispositivo diverso tenta di comunicare durante una sessione attiva.

```csharp
public sealed class SessionHijackAttemptedEventArgs : EventArgs
{
    public uint AttemptedSenderId { get; }  // Chi ha tentato
    public uint CurrentRemoteId { get; }    // Sessione attiva con
    public DateTime Timestamp { get; }      // UTC
}
```

**Invarianti:** `AttemptedSenderId ≠ CurrentRemoteId`, entrambi `≠ 0`

### TransportLayer Events

#### BuffersTimedOutEventArgs

Sollevato quando buffer di riassemblaggio vengono rimossi per timeout.

```csharp
public sealed class BuffersTimedOutEventArgs : EventArgs
{
    public int BufferCount { get; }     // Buffer rimossi
    public int TotalBytesLost { get; }  // Byte persi
    public DateTime Timestamp { get; }  // UTC
}
```

**Invarianti:** `BufferCount > 0`, `TotalBytesLost ≥ 0`

### ApplicationLayer Events

#### MessageReceivedEventArgs / AckReceivedEventArgs

```csharp
public sealed class MessageReceivedEventArgs : EventArgs
{
    public ApplicationMessage Message { get; }
    public LayerContext Context { get; }
    public DateTime Timestamp { get; }
}
```

### NetworkLayer Events

| EventArgs | Proprietà | Descrizione |
|-----------|-----------|-------------|
| `DeviceDiscoveredEventArgs` | `DeviceId`, `Context`, `Timestamp` | Nuovo dispositivo scoperto |
| `DeviceLostEventArgs` | `DeviceId`, `Timestamp` | Dispositivo non più raggiungibile |
| `RouteAddedEventArgs` | `DestinationId`, `NextHop`, `HopCount`, `Timestamp` | Nuova route |
| `LinkQualityAlertEventArgs` | `DeviceId`, `LinkQuality`, `Timestamp` | Qualità link degradata |

### Esempio Sottoscrizione

```csharp
// SessionLayer (via SessionManager)
sessionManager.SessionExpired += (s, e) =>
    _logger.LogWarning("Session expired: device={Device:X8}, duration={Duration}",
        e.RemoteDeviceId, e.SessionDuration);

sessionManager.SessionHijackAttempted += (s, e) =>
    _logger.LogWarning("Hijack attempt: {Attacker:X8} tried to hijack session with {Current:X8}",
        e.AttemptedSenderId, e.CurrentRemoteId);

// NetworkLayer
networkLayer.DeviceDiscovered += (s, e) =>
    Console.WriteLine($"[{e.Timestamp:HH:mm:ss}] Device found: 0x{e.DeviceId:X8}");
```

---

## Driver BLE

### Namespace
```csharp
using Stem.Communication.Drivers.Ble;
```

### Creazione Driver

```csharp
// Via factory (raccomandato)
var config = new BleChannelConfiguration
{
    DeviceMacAddress = "AA:BB:CC:DD:EE:FF",  // Obbligatorio
    RequestedMtu = 185,                       // Default: 185
    AutoReconnectInterval = TimeSpan.FromSeconds(5), // 0 = disabilitato
    OperationTimeout = TimeSpan.FromSeconds(5)
};

IChannelDriver driver = BleChannelDriverFactory.Create(config);
```

### BLE Device Discovery (F-001)

Scansione dispositivi BLE nelle vicinanze con filtri e eventi real-time.

```csharp
await using var scanner = BleScannerFactory.Create();

// Opzione 1: Evento real-time per aggiornare UI durante la scansione
scanner.DeviceDiscovered += (s, device) =>
    Console.WriteLine($"Found: {device.Name} ({device.MacAddress}) RSSI: {device.Rssi} dBm");

// Avvia scansione con configurazione
var devices = await scanner.ScanAsync(new BleScanConfiguration
{
    Timeout = TimeSpan.FromSeconds(10),
    FilterStemDevicesOnly = true,   // Solo dispositivi STEM (default)
    MinimumRssi = -70               // Ignora segnali deboli
});

// Opzione 2: Seleziona il dispositivo più vicino
var selected = devices.OrderByDescending(d => d.Rssi).FirstOrDefault();

if (selected?.IsStemCompatible == true)
{
    // Crea driver dal dispositivo scoperto
    var driver = BleChannelDriverFactory.Create(selected);
}
```

### IBleScanner

```csharp
public interface IBleScanner : IAsyncDisposable
{
    // Evento sollevato per ogni dispositivo scoperto (real-time)
    event EventHandler<BleDeviceInfo>? DeviceDiscovered;

    // Indica se è in corso una scansione
    bool IsScanning { get; }

    // Avvia scansione e restituisce lista completa alla fine
    Task<IReadOnlyList<BleDeviceInfo>> ScanAsync(
        BleScanConfiguration? config = null,
        CancellationToken cancellationToken = default);

    // Ferma scansione in corso
    Task StopScanAsync();
}
```

### BleDeviceInfo

```csharp
public sealed record BleDeviceInfo
{
    public required string? Name { get; init; }          // Nome advertised (può essere null)
    public required string MacAddress { get; init; }     // "AA:BB:CC:DD:EE:FF"
    public required int Rssi { get; init; }              // dBm (-30=vicino, -90=lontano)
    public required bool IsStemCompatible { get; init; } // Espone servizio NUS
    public DateTime LastSeen { get; init; }              // Ultimo rilevamento
}
```

### BleScanConfiguration

| Proprietà | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `Timeout` | `TimeSpan` | 10s | Durata scansione (1-120s) |
| `FilterStemDevicesOnly` | `bool` | true | Solo dispositivi con servizio NUS |
| `NameFilter` | `string?` | null | Filtro substring nome (case-insensitive) |
| `MinimumRssi` | `int` | -90 | RSSI minimo in dBm |
| `UpdateRssiOnDuplicate` | `bool` | true | Aggiorna RSSI dispositivi già visti |

### BleChannelConfiguration

| Proprietà | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `DeviceMacAddress` | `string` | **required** | MAC address dispositivo |
| `RequestedMtu` | `int` | 185 | MTU richiesto (23-517) |
| `AutoReconnectInterval` | `TimeSpan` | 5s | Intervallo retry (0 = disabilitato) |
| `OperationTimeout` | `TimeSpan` | 5s | Timeout operazioni I/O |
| `MaxReceiveBufferSize` | `int` | 100 | Max messaggi in buffer |
| `EnableReassembly` | `bool` | true | Riassembla frame frammentati |

---

## Driver CAN

### Namespace
```csharp
using Stem.Communication.Drivers.Can;
```

### Creazione Driver

```csharp
var config = new CanConfiguration
{
    DevicePath = "PCAN_USBBUS1",  // O PcanHardware enum
    Baudrate = 500000             // 500 kbit/s
};

IChannelDriver driver = new CanChannelDriver(
    new PcanHardware(),
    config
);
```

### CanConfiguration

| Proprietà | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `DevicePath` | `string` | **required** | Path dispositivo PCAN |
| `Baudrate` | `uint` | 500000 | Baudrate CAN |
| `FilterId` | `uint?` | null | Filtro ID CAN (opzionale) |
| `FilterMask` | `uint?` | null | Maschera filtro (opzionale) |

---

## Tipi Comuni

### ChannelType

```csharp
public enum ChannelType
{
    UART_CHANNEL = 0,   // Stream seriale
    CAN_CHANNEL = 1,    // CAN bus
    CLOUD_CHANNEL = 2,  // HTTP/Cloud
    BLE_CHANNEL = 3     // Bluetooth Low Energy
}
```

### LayerResult

```csharp
public readonly struct LayerResult
{
    public LayerStatus Status { get; }      // Success, Error, etc.
    public byte[]? Data { get; }            // Dati processati
    public ProtocolError? Error { get; }    // Dettagli errore (se presente)
    
    public bool IsSuccess => Status == LayerStatus.Success;
}
```

### CryptType

```csharp
public enum CryptType : byte
{
    None = 0x00,        // Nessuna crittografia
    AES128 = 0x01       // AES-128 ECB
}
```

---

## Breaking Changes v0.6.0

### CancellationToken su tutti i metodi asincroni (T-024)

**Chi è impattato:** Chi implementa `IProtocolLayer` o `ICommandHandler` custom.

**Cambiamenti interfacce:**

```csharp
// IProtocolLayer - nuova signature
Task<LayerResult> ProcessUpstreamAsync(byte[] data, LayerContext ctx, CancellationToken ct = default);
Task<LayerResult> ProcessDownstreamAsync(byte[] data, LayerContext ctx, CancellationToken ct = default);

// ICommandHandler - nuova signature  
Task<LayerResult> HandleAsync(ApplicationMessage msg, LayerContext ctx, CancellationToken ct = default);

// IAckHandler - nuova signature
Task HandleAckAsync(ApplicationMessage msg, LayerContext ctx, CancellationToken ct = default);

// IVariableMap - nuove signature
Task<byte[]?> ReadAsync(ushort variableId, CancellationToken ct = default);
Task<bool> WriteAsync(ushort variableId, byte[] value, CancellationToken ct = default);
```

**Migrazione:**
```csharp
// Prima (v0.5.x)
public Task<LayerResult> ProcessUpstreamAsync(byte[] data, LayerContext ctx)
{
    // ...
}

// Dopo (v0.6.0)
public Task<LayerResult> ProcessUpstreamAsync(byte[] data, LayerContext ctx, CancellationToken ct = default)
{
    ct.ThrowIfCancellationRequested();
    // ...
}
```

### ConfigureAwait(false) applicato ovunque (T-019)

**Chi è impattato:** Nessuno (cambiamento interno).

Tutte le chiamate `await` nella libreria ora usano `ConfigureAwait(false)` per evitare deadlock in contesti con `SynchronizationContext` (WPF, WinForms).

---

## Requisiti

- **.NET 10.0** o superiore
- **Windows 10 19041+** per BLE su Windows Desktop
- **PEAK PCAN driver** per CAN

### Pacchetti NuGet

```xml
<PackageReference Include="Stem.Communication.Protocol" Version="0.6.0" />
<PackageReference Include="Stem.Communication.Drivers.Ble" Version="0.6.0" />
<PackageReference Include="Stem.Communication.Drivers.Can" Version="0.6.0" />
```

---

## Links

- [README principale](../README.md)
- [CHANGELOG](../CHANGELOG.md)
- [Protocol README](../Protocol/README.md)
- [Drivers.Ble README](../Drivers.Ble/README.md)
- [Drivers.Can README](../Drivers.Can/README.md)
- [EVENTARGS_STANDARD](Standards/EVENTARGS_STANDARD.md)
- [CANCELLATION_STANDARD](Standards/CANCELLATION_STANDARD.md)
- [API_SURFACE_TEMPLATE](Standards/Templates/API_SURFACE_TEMPLATE.md)

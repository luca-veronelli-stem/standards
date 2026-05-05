# Infrastructure - Contratti per Driver di Canale

## Panoramica

La cartella **Infrastructure** contiene le interfacce, tipi e classi base che definiscono il **contratto** tra lo stack protocollare (`Protocol/`) e le implementazioni dei driver (`Drivers.*/`).

Questo modulo implementa il principio di **Dependency Inversion**: il Protocol dipende da astrazioni (interfacce), non da implementazioni concrete.

> **Ultimo aggiornamento:** 2026-02-24

---

## Ruolo Architetturale

```
┌─────────────────────────────────────────────────────────────┐
│                      Protocol/                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Layers/ (PhysicalLayer usa IChannelDriver)            │  │
│  └─────────────────────────┬─────────────────────────────┘  │
│                            │                                │
│                            ▼                                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Infrastructure/ (Interfacce, Tipi, Eccezioni)         │  │
│  │   • IChannelDriver                                    │  │
│  │   • IChannelConfiguration                             │  │
│  │   • ChannelType, ChannelException, etc.               │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────┬───────────────────────────────────┘
                          │ 
                          ▼ implementa
┌─────────────────────────────────────────────────────────────┐
│                      Drivers.*/                             │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │ Drivers.Can     │  │ Drivers.Ble     │  ...              │
│  │ CanChannelDriver│  │ BleChannelDriver│                   │
│  └─────────────────┘  └─────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
```

**Perché questa separazione?**

1. **Protocol non dipende da librerie hardware** (PCAN, Plugin.BLE)
2. **Driver intercambiabili** senza modificare il Protocol
3. **Testing con mock driver** senza hardware reale
4. **Nuovi driver** implementano solo le interfacce

---

## Contenuto

| File | Tipo | Descrizione |
|------|------|-------------|
| `IChannelDriver.cs` | Interface | Contratto principale per tutti i driver |
| `IChannelConfiguration.cs` | Interface | Contratto per configurazione driver |
| `ChannelType.cs` | Enum | Tipi di canale (CAN, BLE, UART, Cloud) |
| `ConnectionState.cs` | Enum | Stati connessione (Disconnected, Connecting, Connected, Reconnecting) |
| `ConnectionStateChangedEventArgs.cs` | Class | EventArgs per eventi cambio stato connessione |
| `ChannelStatistics.cs` | Class | Statistiche base thread-safe |
| `ChannelMetadata.cs` | Record | Metadata trasporto (routing, priorità) |
| `ChannelException.cs` | Class | Eccezioni base per errori canale |

---

## Componenti

### IChannelDriver

Interfaccia principale che ogni driver deve implementare.

```csharp
public interface IChannelDriver : IDisposable, IAsyncDisposable
{
    // Connessione
    Task<bool> ConnectAsync(PhysicalLayerConfiguration config, CancellationToken ct = default);
    Task DisconnectAsync(CancellationToken ct = default);

    // I/O
    Task<byte[]?> ReadAsync(CancellationToken ct = default);
    Task WriteAsync(byte[] data, CancellationToken ct = default);

    // Con metadata (per CAN Extended ID, etc.)
    Task<(byte[]? Data, ChannelMetadata? Metadata)?> ReadWithMetadataAsync(CancellationToken ct = default);
    Task WriteAsync(byte[] data, ChannelMetadata? metadata, CancellationToken ct = default);

    // Stato
    bool IsConnected { get; }
    ChannelType ChannelType { get; }  // PL-015: usato per inferenza automatica

    // Eventi (STK-012)
    event EventHandler<ConnectionStateChangedEventArgs>? ConnectionStateChanged;
}
```

### ConnectionState (STK-012)

Enum degli stati di connessione del driver.

| Valore | Nome | Descrizione |
|--------|------|-------------|
| `0` | `Disconnected` | Non connesso |
| `1` | `Connecting` | Connessione in corso |
| `2` | `Connected` | Connesso e operativo |
| `3` | `Reconnecting` | Riconnessione automatica in corso |

### ConnectionStateChangedEventArgs (STK-012)

EventArgs per l'evento `ConnectionStateChanged`.

```csharp
public sealed class ConnectionStateChangedEventArgs : EventArgs
{
    public ConnectionState PreviousState { get; }
    public ConnectionState CurrentState { get; }
    public string? Reason { get; }
    public bool WasExpected { get; }           // true = user-initiated disconnect
    public bool WillAttemptReconnect { get; }  // true = auto-reconnect enabled
    public DateTime Timestamp { get; }

    // Convenience properties
    public bool IsConnected => CurrentState == ConnectionState.Connected;
    public bool IsConnecting => CurrentState is Connecting or Reconnecting;
}
```

**Invarianti:**
- `PreviousState` ≠ `CurrentState` (validato nel costruttore)
- Se `WasExpected` = true, allora `WillAttemptReconnect` = false

### ChannelType

Enum dei tipi di canale supportati. I valori numerici sono compatibili con il firmware C.

| Valore | Nome | Chunk Size | Note |
|--------|------|------------|------|
| `0` | `UART_CHANNEL` | 200 bytes | Stream continuo |
| `1` | `CAN_CHANNEL` | 6 bytes | Frame 8B - NetInfo 2B |
| `2` | `CLOUD_CHANNEL` | 1024 bytes | HTTP payload |
| `3` | `BLE_CHANNEL` | 98 bytes | MTU tipico - overhead |

### ChannelStatistics

Statistiche base thread-safe per tutti i driver.

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `BytesSent` | `long` | Totale bytes inviati |
| `BytesReceived` | `long` | Totale bytes ricevuti |
| `MessagesSent` | `long` | Messaggi completi inviati |
| `MessagesReceived` | `long` | Messaggi completi ricevuti |
| `Errors` | `long` | Errori di comunicazione |
| `Reconnects` | `long` | Riconnessioni effettuate |

I driver possono estendere questa classe per statistiche specifiche.

### ChannelMetadata

Record immutabile per metadata di trasporto.

```csharp
public sealed record ChannelMetadata
{
    public ulong SourceAddress { get; init; }
    public ulong DestinationAddress { get; init; }
    public byte Priority { get; init; }
    public DateTime Timestamp { get; init; }
    public ChannelType ChannelType { get; init; }
}
```

**Uso per canale:**
- **CAN:** `DestinationAddress` ? Extended ID (29 bit)
- **BLE:** `DestinationAddress` ? Connection handle
- **UART:** Metadata ignorato (stream continuo)

### ChannelException

Eccezione base per errori di comunicazione.

```csharp
public class ChannelException : Exception
{
    public ChannelType ChannelType { get; }
    public bool IsRecoverable { get; }
}
```

**Eccezioni derivate:**
- `ConnectionLostException` - Connessione persa (recuperabile)
- `ChannelNotConnectedException` - Canale non connesso
- `ChannelTimeoutException` - Timeout operazione

---

## Implementare un Nuovo Driver

### 1. Creare il Progetto

```
Drivers.Uart/
??? UartChannelDriver.cs
??? UartHardware.cs
??? Models/
?   ??? UartConfiguration.cs
??? Drivers.Uart.csproj
```

### 2. Implementare IChannelDriver

```csharp
public class UartChannelDriver : IChannelDriver
{
    private readonly IUartHardware _hardware;
    private readonly ChannelStatistics _statistics = new();
    
    public ChannelType ChannelType => ChannelType.UART_CHANNEL;
    public bool IsConnected => _hardware.IsOpen;
    public ChannelStatistics Statistics => _statistics;
    
    public async Task<bool> ConnectAsync(
        PhysicalLayerConfiguration config, 
        CancellationToken ct = default)
    {
        // Usa config.PortName, config.BaudRate, etc.
        return await _hardware.OpenAsync(config.PortName, config.BaudRate, ct);
    }
    
    public async Task<byte[]?> ReadAsync(CancellationToken ct = default)
    {
        var data = await _hardware.ReadAsync(ct);
        if (data != null)
        {
            Interlocked.Add(ref _statistics._bytesReceived, data.Length);
            Interlocked.Increment(ref _statistics._messagesReceived);
        }
        return data;
    }
    
    // ... altri metodi
}
```

### 3. Registrare nel Builder

```csharp
var uartDriver = new UartChannelDriver(hardware);
var stack = new ProtocolStackBuilder()
    .WithChannelDriver(uartDriver)
    .WithLocalDeviceId(0x00030141)
    .Build();
```

---

## Thread Safety

Tutte le classi in Infrastructure sono thread-safe:

| Classe | Pattern |
|--------|---------|
| `ChannelStatistics` | `Interlocked` + `Volatile.Read` |
| `ChannelMetadata` | Immutabile (`record`) |
| `ChannelException` | Immutabile |

I driver che implementano `IChannelDriver` devono garantire thread-safety per:
- `ReadAsync` / `WriteAsync` concorrenti
- `ConnectAsync` / `DisconnectAsync` durante I/O
- Accesso a `Statistics`

---

## Issue Correlate

→ [Infrastructure/ISSUES.md](./ISSUES.md)

| ID | Titolo | Priorità |
|----|--------|----------|
| INF-001 | ReadWithMetadataAsync Default Implementation | Bassa |
| INF-002 | IChannelConfiguration.Validate() Ambiguo | Bassa |
| INF-003 | ChannelStatistics.StartTime Non Resettabile | Bassa |

**Totale aperte:** 3 | **Totale risolte:** 2

---

## Links

- [PhysicalLayer README](../Layers/PhysicalLayer/README.md) - Usa IChannelDriver
- [Drivers.Can README](../../Drivers.Can/README.md) - Implementazione CAN
- [Drivers.Ble README](../../Drivers.Ble/README.md) - Implementazione BLE

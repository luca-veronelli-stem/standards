# Infrastructure.Protocol

> **Layer di comunicazione BLE per dispositivi STEM.**  
> **Ultimo aggiornamento:** 2026-03-02

---

## Panoramica

Il progetto **Infrastructure.Protocol** fornisce un'astrazione per la comunicazione con dispositivi STEM via BLE:
- **Device Discovery**: Scansione dispositivi BLE con eventi real-time
- **Device Connection**: Connessione, invio/ricezione dati, gestione stato
- **Event-driven**: Notifiche cambio stato connessione e discovery
- **CancellationToken**: Supporto completo per cancellazione operazioni (v0.6.0)

Wrappa `Stem.Communication.Protocol` v0.6.0 e `Stem.Communication.Drivers.Ble` senza duplicare logica.

---

## Caratteristiche

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **Device Discovery** | ✅ | Scansione BLE con filtri |
| **Discovery Real-time** | ✅ | Evento DeviceDiscovered durante scansione |
| **Device Connection** | ✅ | Connessione singleton a un device |
| **Connection Events** | ✅ | Notifiche cambio stato (wrappa Protocol) |
| **CancellationToken** | ✅ | Supporto cancellazione su tutti i metodi async |
| **Auto-Reconnect** | ✅ | Gestito dal driver BLE sottostante |
| **DI Extension** | ✅ | AddProtocol() per registrazione |

---

## Requisiti

- **.NET 10.0** (CI/Linux) o **.NET 10.0-windows10.0.19041.0** (Windows)
- **Windows 10 19041+** per BLE

### Multi-targeting

Il progetto è multi-target per supportare:
- `net10.0` - Test CI su Linux (senza BLE)
- `net10.0-windows10.0.19041.0` - App Windows con BLE

### Dipendenze

| Package | Versione | Uso |
|---------|----------|-----|
| `Stem.Communication.Protocol` | 0.6.0 | Stack protocollare |
| `Stem.Communication.Drivers.Ble` | 0.6.0 | Driver BLE |
| `Microsoft.Extensions.DependencyInjection.Abstractions` | 10.0.3 | DI |

---

## Quick Start

### Registrazione DI

```csharp
services.AddProtocol();
```

### Device Discovery

```csharp
public class DeviceScanViewModel
{
    private readonly IDeviceDiscovery _discovery;

    public DeviceScanViewModel(IDeviceDiscovery discovery)
    {
        _discovery = discovery;

        // Evento real-time per aggiornare UI durante la scansione
        _discovery.DeviceDiscovered += (s, device) =>
        {
            Console.WriteLine($"Found (live): {device.Name} ({device.MacAddress})");
        };
    }

    public async Task ScanAsync()
    {
        var config = new ScanConfiguration
        {
            Timeout = TimeSpan.FromSeconds(15),
            MinRssi = -70,
            FilterStemDevicesOnly = true
        };

        // Il risultato finale include tutti i dispositivi trovati
        await foreach (var device in _discovery.ScanAsync(config))
        {
            Console.WriteLine($"Found: {device.Name} ({device.MacAddress})");
        }
    }
}
```

### Device Connection

```csharp
public class DeviceConnectionViewModel
{
    private readonly IDeviceConnection _connection;
    
    public DeviceConnectionViewModel(IDeviceConnection connection)
    {
        _connection = connection;
        _connection.StateChanged += OnStateChanged;
    }
    
    public async Task ConnectAsync(string macAddress)
    {
        var config = new ConnectionConfiguration
        {
            MacAddress = macAddress,
            AutoReconnectInterval = TimeSpan.FromSeconds(5)
        };
        
        await _connection.ConnectAsync(config);
    }
    
    private void OnStateChanged(object? sender, ConnectionStateChangedEventArgs e)
    {
        // Gestione UI basata su e.CurrentState
        switch (e.CurrentState)
        {
            case ConnectionState.Connected:
                ShowStatus("Connesso!");
                break;
            case ConnectionState.Disconnected:
                if (!e.WasExpected)
                    ShowAlert("Connessione persa");
                break;
            case ConnectionState.Reconnecting:
                ShowStatus("Riconnessione...");
                break;
        }
    }
}
```

---

## Struttura

```
Infrastructure.Protocol/
├── Interfaces/
│   ├── IDeviceDiscovery.cs      # Scansione BLE
│   └── IDeviceConnection.cs     # Connessione device
├── Models/
│   └── DiscoveredDevice.cs      # Device trovato
├── Services/
│   ├── BleDeviceDiscovery.cs    # Implementazione discovery
│   └── BleDeviceConnection.cs   # Implementazione connection
├── DependencyInjection.cs       # AddProtocol()
└── README.md
```

---

## API

### IDeviceDiscovery

| Membro | Tipo | Descrizione |
|--------|------|-------------|
| `DeviceDiscovered` | `event` | Notifica real-time dispositivo trovato |
| `ScanAsync(config?, ct)` | `IAsyncEnumerable` | Scansiona dispositivi BLE |

### IDeviceConnection

| Membro | Tipo | Descrizione |
|--------|------|-------------|
| `State` | `ConnectionState` | Stato corrente |
| `IsConnected` | `bool` | True se connesso |
| `StateChanged` | `event` | Notifica cambio stato |
| `ConnectAsync(config, ct)` | `Task` | Connette al device |
| `DisconnectAsync()` | `Task` | Disconnette (idempotente) |
| `SendAsync(data, dest, ct)` | `Task` | Invia dati |
| `ReceiveAsync(ct)` | `Task<byte[]?>` | Riceve dati |

### ConnectionState (da Protocol)

| Valore | Descrizione |
|--------|-------------|
| `Disconnected` | Non connesso |
| `Connecting` | Connessione in corso |
| `Connected` | Connesso e operativo |
| `Reconnecting` | Riconnessione automatica |

---

## Note Architetturali

### Zero Duplication

Questo layer **non duplica** tipi del Protocol:
- `ConnectionState` → usa `Stem.Communication.Protocol.Infrastructure.ConnectionState`
- `ConnectionStateChangedEventArgs` → usa quello del Protocol

### Singleton Connection

`IDeviceConnection` è registrato come **Singleton**:
- Una sola connessione attiva alla volta
- Adatto per app che connettono a un device per volta

Se in futuro servono connessioni multiple, valutare refactoring a Factory/Manager.

---

## Issue Correlate

→ [Infrastructure.Protocol/ISSUES.md](./ISSUES.md) *(da creare)*

---

## Links

- [Protocol API Reference](../protocol-api.md)
- [Core - Domain Models](../Core/README.md)
- [Services](../Services/README.md)
- [Tests](../Tests/README.md)
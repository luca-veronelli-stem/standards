# Drivers.Ble - Driver BLE per STEM Protocol

> **Driver Bluetooth Low Energy cross-platform per comunicazione con dispositivi STEM.**  

> **Ultimo aggiornamento:** 2026-02-24

---

## Panoramica

Il progetto **Drivers.Ble** fornisce un driver BLE per il protocollo STEM. Implementa l'interfaccia `IChannelDriver` definita in `Protocol.Infrastructure`, permettendo la comunicazione Bluetooth Low Energy con dispositivi embedded STEM.

Il driver agisce come **BLE Central** (GATT Client) e supporta Nordic UART Service (NUS) out-of-the-box.

**Multi-platform (BLE-020):** Un singolo pacchetto NuGet supporta automaticamente sia Windows Desktop che Mobile:
- **Windows Desktop** (WPF, WinUI 3, Console): API native `Windows.Devices.Bluetooth`
- **Mobile** (Android, iOS): Plugin.BLE

---

## Caratteristiche

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **Device Discovery** | ✅ NEW | Scansione dispositivi BLE con filtri (F-001) |
| **Connection Events** | ✅ NEW | Eventi ConnectionStateChanged (STK-012) |
| **Multi-Platform** | ✅ | Windows Desktop + Mobile con selezione automatica |
| **Windows Desktop** | ✅ | WPF, WinUI 3, Console via API native (BLE-020) |
| **Mobile (MAUI)** | ✅ | Android, iOS via Plugin.BLE |
| **Nordic UART Service** | ✅ | UUID NUS configurabili |
| **MTU Negotiation** | ✅ | Negoziazione automatica 23-517 bytes |
| **Chunking/Reassembly** | ✅ | Gestione completa nel driver |
| **Auto-Reconnect** | ✅ | Riconnessione automatica |
| **Thread-Safe** | ✅ | Pattern `Lock` + `Volatile` (.NET 10) |
| **Logging** | ✅ | `Microsoft.Extensions.Logging` |

---

## Requisiti

### Comuni
- **.NET 10.0** o superiore
- **Bluetooth 4.0+** hardware

### Windows Desktop
- **Windows 10 versione 1903** (10.0.19041.0) o superiore
- **Per app packaged:** capability `bluetooth` nel manifest

### Mobile (MAUI)
- **Permessi Bluetooth** (Android/iOS)
- **Plugin.BLE** (incluso automaticamente)

### Dipendenze

| Package | Versione | Target | Uso |
|---------|----------|--------|-----|
| Microsoft.Extensions.Logging.Abstractions | 10.0.2 | Tutti | Logging |
| Plugin.BLE | 3.2.0 | `net10.0` | BLE per Mobile |
| Windows.Devices.Bluetooth | Built-in | `net10.0-windows` | BLE per Windows |
| Protocol | (progetto) | Tutti | IChannelDriver, ChannelType |

---

## Quick Start

### Scan + Connect (Nuovo in 0.5.2)

```csharp
using Stem.Communication.Drivers.Ble;

// 1. Scansiona dispositivi STEM nelle vicinanze
await using var scanner = BleScannerFactory.Create();

scanner.DeviceDiscovered += (s, device) => 
    Console.WriteLine($"Found: {device.Name} ({device.MacAddress}) RSSI: {device.Rssi} dBm");

var devices = await scanner.ScanAsync(new BleScanConfiguration
{
    Timeout = TimeSpan.FromSeconds(10),
    FilterStemDevicesOnly = true
});

// 2. Seleziona dispositivo (UI o logica)
var selected = devices.OrderByDescending(d => d.Rssi).First();

// 3. Crea driver e connetti
await using var driver = BleChannelDriverFactory.Create(selected);
await driver.ConnectAsync(new PhysicalLayerConfiguration());

// 4. Comunica
await driver.WriteAsync([0x01, 0x02, 0x03]);
var data = await driver.ReadAsync();
```

### Connessione Diretta (se MAC noto)

```csharp
// Se conosci già il MAC address
var driver = BleChannelDriverFactory.CreateWithMacAddress("AA:BB:CC:DD:EE:FF");
await driver.ConnectAsync(config);
```

---

## API / Componenti

### Architettura

```
┌─────────────────────────────────────────────────────────────┐
│                  SCAN (F-001)                               │
├─────────────────────────────────────────────────────────────┤
│  BleScannerFactory.Create()                                 │
│           │                                                 │
│           ▼                                                 │
│      IBleScanner                                            │
│       • ScanAsync()                                         │
│       • DeviceDiscovered event                              │
│           │                                                 │
│           ▼                                                 │
│      BleDeviceInfo                                          │
│       • Name, MacAddress, Rssi, IsStemCompatible            │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    PhysicalLayer                            │
└─────────────────────────┬───────────────────────────────────┘
                          │ IChannelDriver
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                  BleChannelDriver                           │
│  • Chunking basato su MTU negoziato                         │
│  • Reassembly basato su Length header                       │
│  • Auto-reconnect                                           │
└─────────────────────────┬───────────────────────────────────┘
                          │ IBleHardware
                          ▼
┌──────────────────────────┬──────────────────────────────────┐
│   WindowsBleHardware     │      PluginBleHardware           │
│  (net10.0-windows)       │         (net10.0)                │
│  Windows.Devices.BT      │        Plugin.BLE                │
└──────────────────────────┴──────────────────────────────────┘
        ↑                              ↑
        │                              │
   Windows Desktop              Mobile (MAUI)
   WPF, WinUI 3, Console        Android, iOS
```

> **Nota (T-009 ✅ Risolto):** Il framing BLE (NetInfo + Address header) è ora gestito da `BleFramingHelper`.
> Il TransportLayer opera in modalità passthrough per BLE.
> Vedi [Protocol/ISSUES.md](../Protocol/ISSUES.md) per dettagli su T-009.

### Componenti

| Componente | Responsabilità |
|------------|----------------|
| **Scanner (F-001)** | |
| `IBleScanner` | Interfaccia scansione dispositivi |
| `BleScannerFactory` | Factory per creazione scanner |
| `BleScanConfiguration` | Configurazione scansione (timeout, filtri) |
| `BleDeviceInfo` | DTO dispositivo scoperto (nome, MAC, RSSI) |
| **Driver** | |
| `BleChannelDriver` | IChannelDriver, chunking/riassemblaggio |
| `BleChannelDriverFactory` | Factory per creazione driver |
| `BleChannelConfiguration` | Record configurazione BLE |
| `BleChannelConstants` | Costanti protocollo e default |
| **Helpers** | |
| `BleFramingHelper` | Wrap/unwrap header BLE (NetInfo + Address) - T-009 |
| `BleMtuHelper` | Utility MTU e chunking |
| `BleReassemblyBuffer` | Buffer riassemblaggio RX |
| **Hardware (internal)** | |
| `IBleHardware` | Astrazione hardware BLE |
| `WindowsBleHardware` | Impl. Windows native |
| `WindowsBleScanner` | Impl. scanner Windows |
| `PluginBleHardware` | Impl. Plugin.BLE |

### Configurazione Driver

| Proprietà | Default | Range | Descrizione |
|-----------|---------|-------|-------------|
| `DeviceMacAddress` | **required** | AA:BB:CC:DD:EE:FF | MAC del dispositivo |
| `ServiceUuid` | NUS | - | UUID servizio GATT |
| `RequestedMtu` | 185 | 23-517 | MTU desiderato |
| `ConnectionTimeout` | 15s | 1-120s | Timeout connessione |
| `OperationTimeout` | 5s | 1-60s | Timeout R/W e ReadAsync |
| `AutoReconnectInterval` | 3s | ≥0 | Intervallo riconnessione (0=disabilitato) |
| `InterChunkDelay` | 10ms | 0-500ms | Delay tra chunk TX |
| `EnableReassembly` | true | - | Riassemblaggio chunk RX |
| `MaxReceiveBufferSize` | 100 | 10-10000 | Buffer RX bounded |

### Configurazione Scanner

| Proprietà | Default | Range | Descrizione |
|-----------|---------|-------|-------------|
| `Timeout` | 10s | 1-120s | Durata scansione |
| `FilterStemDevicesOnly` | true | - | Filtra solo dispositivi NUS |
| `MinimumRssi` | -90 dBm | -120-0 | RSSI minimo |
| `UpdateRssiOnDuplicate` | true | - | Aggiorna RSSI duplicati |
| `NameFilter` | null | - | Filtro nome (substring) |

> **Nota:** La configurazione è validata nel costruttore di `BleChannelDriver` (fail-fast pattern).

### Chunking BLE

> **Importante:** Il chunking BLE è gestito **esclusivamente** dal driver.  
> Il Transport Layer opera in modalità passthrough.

```
MTU 185 → Payload max 182 bytes per write
Messaggio 500 bytes → 3 chunks (182 + 182 + 136)
```

---

## Eventi ConnectionStateChanged (STK-012)

Il driver BLE solleva eventi quando lo stato della connessione cambia.

```csharp
driver.ConnectionStateChanged += (sender, e) =>
{
    Console.WriteLine($"BLE: {e.PreviousState} -> {e.CurrentState}");

    if (e.CurrentState == ConnectionState.Disconnected)
    {
        if (e.WillAttemptReconnect)
            ShowStatus($"Riconnessione in corso... Motivo: {e.Reason}");
        else if (!e.WasExpected)
            ShowError($"Connessione persa: {e.Reason}");
    }
    else if (e.CurrentState == ConnectionState.Reconnecting)
    {
        ShowStatus("Auto-reconnect attivo...");
    }
    else if (e.CurrentState == ConnectionState.Connected)
    {
        ShowStatus("Connesso!");
    }
};
```

**Stati sollevati:**
- `Disconnected → Connecting` (su ConnectAsync)
- `Connecting → Connected` (connessione riuscita)
- `Connecting → Disconnected` (connessione fallita)
- `Connected → Disconnected` (disconnessione user o inattesa)
- `Disconnected → Reconnecting` (auto-reconnect avviato)
- `Reconnecting → Connected` (auto-reconnect riuscito)
- `Reconnecting → Disconnected` (auto-reconnect fallito)

### EventArgs Interni (Hardware)

Gli eventi hardware interni usano `readonly record struct` per performance (EA-011b):

| EventArgs | Tipo | Proprietà |
|-----------|------|-----------|
| `BleDataReceivedEventArgs` | record struct | `Data`, `Timestamp` |
| `BleDisconnectedEventArgs` | record struct | `DeviceName`, `Reason`, `WasExpected`, `Timestamp` |

Questi sono `internal` e ad alta frequenza, quindi usano struct per zero allocazioni heap.

---

## Struttura

```
Drivers.Ble/
├── BleChannelDriver.cs          # Driver principale
├── BleChannelDriverFactory.cs   # Factory driver
├── BleChannelConfiguration.cs   # Configurazione driver
├── BleChannelConstants.cs       # Costanti protocollo
├── IBleScanner.cs               # Interfaccia scanner (F-001)
├── BleScannerFactory.cs         # Factory scanner (F-001)
├── BleScanConfiguration.cs      # Configurazione scanner (F-001)
├── BleDeviceInfo.cs             # DTO dispositivo (F-001)
├── Hardware/
│   ├── IBleHardware.cs          # Interfaccia hardware (internal)
│   ├── BleHardwareException.cs  # Eccezioni BLE
│   ├── PluginBle/               # Implementazione Mobile (net10.0)
│   │   └── PluginBleHardware.cs
│   └── Windows/                 # Implementazione Windows (net10.0-windows)
│       ├── WindowsBleHardware.cs
│       └── WindowsBleScanner.cs  # Scanner Windows (F-001)
├── Helpers/
│   ├── BleFramingHelper.cs      # Wrap/unwrap header BLE (T-009)
│   ├── BleMtuHelper.cs          # Utility MTU
│   └── BleReassemblyBuffer.cs   # Buffer reassembly
├── ISSUES.md
└── README.md
```

---

## Issue Correlate

→ [ISSUES.md](./ISSUES.md)

### Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| Critica | 0 | 2 |
| Alta | 0 | 4 |
| Media | 1 | 9 |
| Bassa | 2 | 3 |
| **Totale** | **3** | **18** *(include 1 Wontfix)*

### Issue Aperte

| ID | Titolo | Priorità |
|----|--------|----------|
| BLE-012 | Logging di Dati Sensibili | Bassa |
| BLE-018 | Volatile.Read Mancante in Event Handlers | Bassa |
| BLE-019 | Chunking MTU che Spezza Header BLE | Media |

### Issue Recentemente Risolte

| ID | Titolo | Priorità | Data |
|----|--------|----------|------|
| BLE-020 | Supporto Windows Desktop Nativo | Alta | 2026-02-17 |
| BLE-009 | Magic Numbers in AutoReconnect | Bassa | 2026-02-11 |
| BLE-011 | XML Comments Mancanti | Bassa | 2026-02-11 |
| BLE-008 | Validazione InterChunkDelay | Media | 2026-02-10 |
| BLE-015 | Timeout su ReadAsync | Media | 2026-02-10 |

---

## Links

- [Protocol/Infrastructure](../Protocol/Infrastructure/README.md) - IChannelDriver
- [Protocol/PhysicalLayer](../Protocol/Layers/PhysicalLayer/README.md) - Usa il driver
- [Plugin.BLE](https://github.com/dotnet-bluetooth-le/dotnet-bluetooth-le)
- [Nordic UART Service](https://developer.nordicsemi.com/nRF_Connect_SDK/doc/latest/nrf/libraries/bluetooth_services/services/nus.html)
- [Tests/Unit/Drivers/Ble](../Tests/Unit/Drivers/Ble/) - 365+ test

---

## Licenza

- **Proprietario:** STEM E.m.s.
- **Autore:** Luca Veronelli (l.veronelli@stem.it)
- **Data di Creazione:** 2026-02-03
- **Licenza:** Proprietaria - Tutti i diritti riservati

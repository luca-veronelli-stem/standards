# Drivers.Can - Driver CAN per STEM Protocol

> **Driver CAN per comunicazione con dispositivi STEM via bus CAN, compatibile con firmware C.**  

> **Ultimo aggiornamento:** 2026-02-24

---

## Panoramica

Il progetto **Drivers.Can** fornisce un driver CAN per il protocollo STEM. Implementa l'interfaccia `IChannelDriver` definita in `Protocol.Infrastructure`, permettendo la comunicazione CAN bus con dispositivi embedded STEM.

Il driver è compatibile con il firmware C originale (`CanDataLayer.c`) e gestisce il chunking NetInfo per frame CAN da 8 byte.

---

## Caratteristiche

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **Frame CAN Raw** | ✅ | Trasmissione frame CAN 2.0B (no ISO-TP) |
| **Extended ID (29 bit)** | ✅ | Supporto completo per routing STEM |
| **Connection Events** | ✅ NEW | Eventi ConnectionStateChanged (STK-012) |
| **Chunking NetInfo** | ✅ | Header 2 byte + dati 6 byte per frame |
| **Riassemblaggio** | ✅ | Ricostruzione messaggi multi-frame |
| **Multi-Hardware** | ✅ | Astrazione `ICanHardware` |
| **Thread-Safe** | ✅ | Pattern `Lock` (.NET 10) |
| **Logging** | ✅ | `Microsoft.Extensions.Logging` |

---

## Requisiti

- **.NET 10.0** o superiore
- **PCAN-Basic API 4.x** ([peak-system.com](https://www.peak-system.com/))
- **Hardware PCAN-USB** (es. IPEH-002022)

### Dipendenze

| Package | Versione | Uso |
|---------|----------|-----|
| Peak.PCANBasic.NET | 4.10.1 | API hardware PCAN |
| Microsoft.Extensions.Logging.Abstractions | 10.0.2 | Logging |
| Protocol | (progetto) | IChannelDriver, ChannelType |

---

## Quick Start

```csharp
using Drivers.Can;
using Drivers.Can.Hardware.Pcan;
using Protocol.Layers.PhysicalLayer.Models;

// Crea hardware e driver
var pcanHardware = new PcanHardware();
var canDriver = new CanChannelDriver(pcanHardware);

// Configura e connetti
var config = new PhysicalLayerConfiguration
{
    ChannelType = ChannelType.CAN_CHANNEL,
    PortName = "PCAN_USBBUS1",
    BaudRate = 500000
};

await canDriver.ConnectAsync(config);

// Invia dati (chunking automatico)
await canDriver.WriteAsync([0x01, 0x02, 0x03, 0x04, 0x05]);

// Ricevi dati (riassemblaggio automatico)
var data = await canDriver.ReadAsync();

// Cleanup
await canDriver.DisposeAsync();
```

---

## API / Componenti

### Architettura

```
┌─────────────────────────────────────────────────────────────┐
│                    PhysicalLayer                            │
└─────────────────────────┬───────────────────────────────────┘
                          │ IChannelDriver
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                  CanChannelDriver                           │
│  • Chunking: NetInfo(2) + Data(6) = 8 byte                  │
│  • Riassemblaggio per packetId                              │
└─────────────────────────┬───────────────────────────────────┘
                          │ ICanHardware
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                   PcanHardware                              │
│  • Peak.PCANBasic.NET wrapper                               │
└─────────────────────────────────────────────────────────────┘
```

> **Nota (T-014/T-015):** È pianificata l'unificazione del NetInfoCodec (T-014) e la revisione dell'architettura chunking (T-015).
> Attualmente il chunking CAN (NetInfo) è gestito nel driver per compatibilità con firmware C.
> Vedi [Protocol/ISSUES.md](../Protocol/ISSUES.md) per dettagli.

### Componenti

| Componente | Responsabilità |
|------------|----------------|
| `CanChannelDriver` | IChannelDriver, chunking/riassemblaggio NetInfo |
| `CanChannelConfiguration` | Baudrate, filtri, device path |
| `CanChannelConstants` | Costanti protocollo e default (T-011) |
| `NetInfoHelper` | Encode/decode header NetInfo (2 byte) |
| `ICanHardware` | Astrazione hardware CAN |
| `PcanHardware` | Implementazione PEAK PCAN |
| `CanFrame` | Struttura frame CAN (ExtendedId, Data, DLC) |
| `CanHardwareException` | Eccezioni specifiche CAN |

### Formato Frame NetInfo

```
| NetInfo (2 byte) | Chunk Data (6 byte) | = 8 byte per frame

NetInfo (Little Endian, 16 bit):
- Bit 0-1:   Version (2 bit)
- Bit 2-4:   PacketId (3 bit, rolling 1-7)
- Bit 5:     SetLength/IsFirst (1 bit)
- Bit 6-15:  RemainingChunks (10 bit, countdown)
```

### Configurazione

| Proprietà | Default | Descrizione |
|-----------|---------|-------------|
| `Baudrate` | 500000 | Velocità CAN (bit/sec) |
| `DevicePath` | null | Es. "PCAN_USBBUS1" |
| `FilterId` | null | Extended ID da filtrare |
| `OperationTimeout` | 5 sec | Timeout I/O |

---

## Struttura

```
Drivers.Can/
├── CanChannelDriver.cs          # Driver principale
├── CanChannelConfiguration.cs   # Configurazione
├── CanChannelConstants.cs       # Costanti protocollo e default
├── Helpers/
│   └── NetInfoHelper.cs         # Encode/decode NetInfo
├── Hardware/
│   ├── ICanHardware.cs          # Interfaccia hardware
│   ├── CanHardwareException.cs  # Eccezioni CAN
│   └── Pcan/
│       └── PcanHardware.cs      # Implementazione PCAN
├── ISSUES.md
└── README.md
```

---

## Eventi ConnectionStateChanged (STK-012)

Il driver CAN solleva eventi quando lo stato della connessione cambia.

```csharp
driver.ConnectionStateChanged += (sender, e) =>
{
    Console.WriteLine($"CAN: {e.PreviousState} -> {e.CurrentState}");

    if (e.CurrentState == ConnectionState.Disconnected && !e.WasExpected)
        ShowError($"CAN disconnesso: {e.Reason}");
    else if (e.CurrentState == ConnectionState.Connected)
        ShowStatus("CAN connesso");
};
```

**Stati sollevati:**
- `Disconnected → Connecting` (su ConnectAsync)
- `Connecting → Connected` (connessione riuscita)
- `Connecting → Disconnected` (connessione fallita)
- `Connected → Disconnected` (disconnessione)

> **Nota:** Il driver CAN non ha auto-reconnect, quindi `Reconnecting` non viene mai usato.

---

## Issue Correlate

→ [ISSUES.md](./ISSUES.md)

### Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| Alta | 1 | 2 |
| Media | 4 | 2 |
| Bassa | 3 | 2 |
| Security | 2 | 0 |
| **Totale** | **10** | **6**

### Issue Principali

| ID | Titolo | Priorità | Status |
|----|--------|----------|--------|
| CAN-003 | Race Condition InitializeAsync | Alta | Aperto |
| CAN-017 | Timeout Chunk Incompleti | Media | Aperto |
| ~~CAN-011~~ | ~~XML Comments Incompleti~~ | ~~Bassa~~ | ✅ Risolto |
| ~~CAN-001~~ | ~~Blocking Disconnect/Dispose~~ | ~~Alta~~ | ✅ Risolto |
| ~~CAN-002~~ | ~~ExtendedId hardcoded~~ | ~~Alta~~ | ✅ Risolto |
| ~~CAN-014~~ | ~~Riassemblaggio Chunk~~ | ~~Media~~ | ✅ Risolto |

---

## Links

- [Protocol/Infrastructure](../Protocol/Infrastructure/README.md) - IChannelDriver
- [Protocol/PhysicalLayer](../Protocol/Layers/PhysicalLayer/README.md) - Usa il driver
- [Peak PCAN Downloads](https://www.peak-system.com/Drivers.523.0.html)
- [Tests/Unit/Drivers/Can](../Tests/Unit/Drivers/Can/) - 130+ test

---

## Licenza

- **Proprietario:** STEM E.m.s.
- **Autore:** Luca Veronelli (l.veronelli@stem.it)
- **Data di Creazione:** 2026-02-02
- **Licenza:** Proprietaria - Tutti i diritti riservati

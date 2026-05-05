# Client - Applicazione Console STEM

> **Applicazione console .NET 10 per comunicazione con dispositivi STEM via CAN o BLE.**  

> **Ultimo aggiornamento:** 2026-02-09

---

## Panoramica

Il progetto **Client** è un'applicazione console che dimostra l'utilizzo dello stack protocollare STEM per comunicare con dispositivi embedded tramite bus CAN o Bluetooth Low Energy. Funge da esempio di riferimento e strumento di debug.

### Caratteristiche

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **Connessione CAN** | ✅ | PCAN-USB (Peak Systems) |
| **Invio Messaggi** | ✅ | Broadcast e unicast |
| **Ricezione Asincrona** | ✅ | Receive loop in background |
| **Crittografia** | ✅ | AES-128 opzionale |
| **Logging** | ✅ | Livelli configurabili |
| **Graceful Shutdown** | ✅ | Gestione CTRL+C |

---

## Requisiti

- **.NET 10.0-windows10.0.19041.0** o superiore
- **Hardware PCAN-USB** (per CAN) o **Bluetooth 4.0+** (per BLE)
- **Driver PCAN** installati per CAN ([Peak Systems](https://www.peak-system.com/))

### Dipendenze

| Package | Versione | Uso |
|---------|----------|-----|
| Microsoft.Extensions.Logging | 10.0.2 | Logging framework |
| Microsoft.Extensions.Logging.Console | 10.0.2 | Console logger |
| Plugin.BLE | 3.2.0 | BLE cross-platform |
| Protocol | (progetto) | Stack protocollare |
| Drivers.Can | (progetto) | Driver CAN |
| Drivers.Ble | (progetto) | Driver BLE |

---

## Quick Start

```bash
# Compilazione
cd Client
dotnet build

# Esecuzione
dotnet run
```

### Esempio Utilizzo

```csharp
var config = new StemClientConfiguration
{
    LocalDeviceId = 0x00000001,
    CanDevice = "PCAN_USBBUS1",
    CanBaudrate = 250_000
};

await using var client = new StemClient(config, loggerFactory);
await client.ConnectAsync();

// Invio
await client.SendBroadcastAsync(data);

// Eventi
client.MessageReceived += (s, e) => Console.WriteLine($"Ricevuto: {e.Message.Command}");
```

---

## Configurazione

### StemClientConfiguration

| Parametro | Default | Descrizione |
|-----------|---------|-------------|
| `ChannelMode` | `Can` | Canale: `Can` o `Ble` |
| `LocalDeviceId` | `0` | SRID del dispositivo locale |
| **CAN** | | |
| `CanDevice` | `"PCAN_USBBUS1"` | Identificativo hardware CAN |
| `CanBaudrate` | `250000` | Baud rate (bit/s) |
| **BLE** | | |
| `BleDeviceNameFilter` | `null` | Filtro nome dispositivo |
| `BleDeviceMacAddress` | `null` | MAC address (non iOS) |
| `BleRequestedMtu` | `185` | MTU desiderato (23-517) |
| **Crittografia** | | |
| `EnableEncryption` | `false` | Abilita AES-128 |
| `AesKey` | `null` | Chiave AES (16 bytes) |
| **Network** | | |
| `EnableRouting` | `false` | Routing multi-hop |
| `EnableBroadcast` | `true` | Ricezione broadcast |
| `EnableHeartbeat` | `false` | Heartbeat periodico |

### Validazione

```csharp
var config = new StemClientConfiguration { ... };
config.Validate();  // Chiamato anche in ConnectAsync()
```

---

## Esecuzione

### Comandi Interattivi

| Tasto | Comando | Descrizione |
|-------|---------|-------------|
| `v` | PROTOCOL_VERSION broadcast | Richiesta versione a tutti |
| `p` | PROTOCOL_VERSION unicast | Richiesta versione a dispositivo specifico |
| `b` | Broadcast generico | Invia dati di test |
| `s` | Invio unicast | Invia a dispositivo specifico |
| `q` | Quit | Esce dall'applicazione |
| `CTRL+C` | Shutdown | Graceful shutdown |

### Output Esempio

```
[12:34:56] info: Program[0]
      === STEM Protocol Client ===
[12:34:56] info: Program[0]
      Configuration: DeviceId=00000001, CAN=PCAN_USBBUS1@250000
[12:34:57] info: Program[0]
      Connesso! Premi CTRL+C per uscire.
```

### Troubleshooting

| Problema | Soluzione |
|----------|-----------|
| "PCAN device not found" | Verificare hardware e driver Peak |
| "BusWarning" continuo | Normale se PCAN è solo dispositivo sul bus |
| Nessun messaggio | Verificare baudrate (250000) e EnableBroadcast |

---

## Struttura

```
Client/
├── Program.cs                    # Entry point, UI
├── StemClient.cs                 # Facade per lo stack
├── StemClientConfiguration.cs    # Configurazione
├── ISSUES.md
└── README.md
```

---

## Issue Correlate

→ [ISSUES.md](./ISSUES.md)

### Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| Alta | 1 | 0 |
| Media | 5 | 0 |
| Bassa | 6 | 0 |
| Security | 1 | 0 |
| **Totale** | **13** | **0** |

### Issue Principali

| ID | Titolo | Priorità |
|----|--------|----------|
| CLI-001 | PcanHardware.Dispose() Sincrono | Alta |

---

## Links

- [Protocol/README.md](../Protocol/README.md) - Stack protocollare
- [Drivers.Can/README.md](../Drivers.Can/README.md) - Driver CAN
- [Drivers.Ble/README.md](../Drivers.Ble/README.md) - Driver BLE

---

## Licenza

- **Proprietario:** STEM E.m.s.
- **Autore:** Luca Veronelli (l.veronelli@stem.it)
- **Data di Creazione:** 2026-02-04
- **Licenza:** Proprietaria - Tutti i diritti riservati

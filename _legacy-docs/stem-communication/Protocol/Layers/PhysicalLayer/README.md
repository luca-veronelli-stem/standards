# Physical Layer (Layer 1)

## Panoramica

Il **Physical Layer** è il primo e più basso livello dello stack protocollare STEM, corrispondente al Layer 1 del modello OSI. Si occupa della comunicazione diretta con l'hardware attraverso driver specifici per canale (CAN, BLE, UART, Cloud).

> **Ultimo aggiornamento:** 2026-02-24

---

## Responsabilità

- **Gestione connessione** al canale hardware
- **Buffer management** per trasmissione (TX) e ricezione (RX)
- **Lettura/scrittura** byte stream verso/dal driver
- **Propagazione eventi** ConnectionStateChanged dal driver (STK-012)
- **Gestione timeout** per operazioni I/O
- **Gestione errori** di comunicazione hardware
- **Raccolta statistiche** su buffer, canale, throughput e errori

---

## Architettura

```
PhysicalLayer/
├── PhysicalLayer.cs                    # Implementazione principale del layer
├── Models/
│   ├── PhysicalLayerConfiguration.cs   # Configurazione runtime
│   ├── PhysicalLayerConstants.cs       # Costanti (buffer size, timeout)
│   ├── PhysicalLayerStatistics.cs      # Statistiche aggregate del layer
│   ├── ProtocolTxBuffer.cs             # Buffer di trasmissione
│   ├── ProtocolRxBuffer.cs             # Buffer di ricezione circolare
│   └── BufferStatistics.cs             # Statistiche per diagnostica buffer
└── (Driver in progetti separati)
    ├── Drivers.Can/                    # Driver CAN (PCAN)
    └── Drivers.Ble/                    # Driver BLE (Plugin.BLE)
```

---

## Formato Dati

### Flusso Dati

Il Physical Layer è un **passthrough** per i dati: non modifica il formato, ma gestisce la trasmissione fisica.

```
┌─────────────────────────────────────────────────────────────┐
│                    Dati dal DataLinkLayer                   │
│                    (frame completo con CRC)                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     PhysicalLayer                           │
│                    (TX Buffer → Driver)                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     IChannelDriver                          │
│              (WriteAsync → Hardware fisico)                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Componenti Principali

### PhysicalLayer

Classe principale che eredita da `ProtocolLayerBase`. Gestisce la comunicazione con il driver del canale.

```csharp
public class PhysicalLayer : ProtocolLayerBase
{
    public override string LayerName => "Physical";
    public override int LayerLevel => 1;

    // STK-012: Propaga eventi dal driver
    public event EventHandler<ConnectionStateChangedEventArgs>? ConnectionStateChanged;
}
```

**Nota:** Essendo il layer più basso, `LowerLayer` è sempre `null`.

### Interface: IChannelDriver

Interfaccia che tutti i driver di canale devono implementare (definita in `Protocol.Infrastructure`).

```csharp
public interface IChannelDriver : IDisposable, IAsyncDisposable
{
    ChannelType ChannelType { get; }  // PL-015: usato per inferenza automatica
    bool IsConnected { get; }

    Task<bool> ConnectAsync(PhysicalLayerConfiguration config, CancellationToken ct = default);
    Task DisconnectAsync(CancellationToken ct = default);
    Task WriteAsync(byte[] data, CancellationToken ct = default);
    Task<byte[]?> ReadAsync(CancellationToken ct = default);
}
```

### Helper: ProtocolTxBuffer

Buffer di trasmissione con statistiche.

**Nota (PL-001):** Dopo il fix, il buffer TX ha ruolo **diagnostico** - scritto DOPO `WriteAsync` riuscito.

### Helper: ProtocolRxBuffer

Buffer di ricezione circolare con statistiche.

**Nota (PL-001):** Dopo il fix, il buffer RX ha ruolo **diagnostico** - scritto DOPO ricezione dal driver.

---

## Configurazione

Classe: `PhysicalLayerConfiguration`

| Proprietà | Tipo | Default | Min | Max | Descrizione |
|-----------|------|---------|-----|-----|-------------|
| `ChannelType` | `ChannelType` | `CAN_CHANNEL` | - | - | Tipo di canale |
| `TxBufferSize` | `int` | `1100` | `64` | `65535` | Dimensione buffer TX |
| `RxBufferSize` | `int` | `1100` | `64` | `65535` | Dimensione buffer RX |
| `ReadTimeoutMs` | `int` | `1000` | `50` | `60000` | Timeout lettura (ms) |
| `WriteTimeoutMs` | `int` | `1000` | `50` | `60000` | Timeout scrittura (ms) |
| `PortName` | `string?` | `null` | - | - | Porta seriale (UART) |
| `BaudRate` | `int` | `500000` | `9600` | `1000000` | Baud rate |

### Tipi di Canale

Enum: `ChannelType`

| Valore | Descrizione |
|--------|-------------|
| `CAN_CHANNEL` | Comunicazione CAN bus |
| `BLE_CHANNEL` | Bluetooth Low Energy |
| `UART_CHANNEL` | Comunicazione seriale |
| `CLOUD_CHANNEL` | Comunicazione cloud/HTTP |

### Validazione

Il metodo `Validate()` verifica:
- `TxBufferSize` tra 64 e 65535 bytes
- `RxBufferSize` tra 64 e 65535 bytes
- `ReadTimeoutMs` tra 50ms e 60s
- `WriteTimeoutMs` tra 50ms e 60s
- `BaudRate` tra 9600 e 1000000

### Esempio

```csharp
var config = new PhysicalLayerConfiguration
{
    ChannelType = ChannelType.CAN_CHANNEL,
    TxBufferSize = 2048,
    RxBufferSize = 2048,
    ReadTimeoutMs = 2000,
    WriteTimeoutMs = 2000
};
config.Validate();
```

---

## Costanti

Classe: `PhysicalLayerConstants`

### Valori Default

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `DEFAULT_TX_BUFFER_SIZE` | `1100` | Corrisponde a `BUFFER_TX_LEN_MAX` in C |
| `DEFAULT_RX_BUFFER_SIZE` | `1100` | Corrisponde a `BUFFER_RX_LEN_MAX` in C |
| `DEFAULT_UART_BAUDRATE` | `115200` | Baud rate UART default |
| `DEFAULT_CAN_BAUDRATE` | `500000` | Baud rate CAN default |
| `DEFAULT_READ_TIMEOUT_MS` | `1000` | Timeout lettura default |
| `DEFAULT_WRITE_TIMEOUT_MS` | `1000` | Timeout scrittura default |

### Limiti Validazione

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `MIN_BUFFER_SIZE` | `64` | Buffer minimo |
| `MAX_BUFFER_SIZE` | `65535` | Buffer massimo |
| `MIN_TIMEOUT_MS` | `50` | Timeout minimo |
| `MAX_TIMEOUT_MS` | `60000` | Timeout massimo (1 min) |
| `MIN_BAUDRATE` | `9600` | Baud rate minimo |
| `MAX_BAUDRATE` | `1000000` | Baud rate massimo |

---

## Flusso Dati

### Downstream (Trasmissione)

```
DataLinkLayer (Layer 2)
      │
      ▼
┌──────────────────────────────┐
│   ProcessDownstreamAsync     │
│   ─────────────────────────  │
│   1. Valida driver           │
│   2. WriteAsync(data)        │
│   3. [OK] Log in TX buffer   │
│   4. [Err] Gestione errore   │
│   5. Aggiorna statistiche    │
└──────────────────────────────┘
      │
      ▼
IChannelDriver → Hardware
```

### Upstream (Ricezione)

```
Hardware → IChannelDriver
      │
      ▼
┌──────────────────────────────┐
│   ProcessUpstreamAsync       │
│   ─────────────────────────  │
│   1. ReadAsync() dal driver  │
│   2. [Dati?] Log in RX buffer│
│   3. [Timeout?] Retry/Error  │
│   4. Aggiorna statistiche    │
│   5. Passa a layer superiore │
└──────────────────────────────┘
      │
      ▼
DataLinkLayer (Layer 2)
```

---

## Statistiche

Classe: `PhysicalLayerStatistics`

### Buffer Statistics (Aggregate)

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `BytesWrittenToTx` | `long` | Byte scritti nel buffer TX |
| `BytesReadFromRx` | `long` | Byte ricevuti nel buffer RX |
| `BytesDiscarded` | `long` | Byte scartati per overflow (TX+RX) |
| `BufferOverflows` | `long` | Overflow totali (TX+RX) |
| `TxBufferOverflows` | `long` | Overflow buffer TX |
| `RxBufferOverflows` | `long` | Overflow buffer RX |

### Channel Statistics

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `ChannelWrites` | `long` | Operazioni WriteAsync eseguite |
| `ChannelReads` | `long` | Operazioni ReadAsync eseguite |
| `ChannelErrors` | `long` | Errori canale rilevati |
| `FramesSent` | `long` | Frame inviati con successo |
| `FramesReceived` | `long` | Frame ricevuti con successo |

### Buffer Levels

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `CurrentTxBufferLevel` | `int` | Byte attualmente nel buffer TX |
| `CurrentRxBufferLevel` | `int` | Byte attualmente nel buffer RX |
| `LastChannelWriteAt` | `DateTime?` | Timestamp ultima scrittura |
| `LastChannelReadAt` | `DateTime?` | Timestamp ultima lettura |

### Accesso

```csharp
var stats = (PhysicalLayerStatistics)layer.Statistics;
Console.WriteLine($"Byte inviati: {stats.BytesWrittenToTx}");
Console.WriteLine($"Errori canale: {stats.ChannelErrors}");
Console.WriteLine($"Buffer RX level: {stats.CurrentRxBufferLevel}");
```

---

## Esempi di Utilizzo

### Inizializzazione con Driver Iniettato

```csharp
// Il driver viene creato e configurato esternamente
var canDriver = new CanChannelDriver(hardware);

var layer = new PhysicalLayer(canDriver);
await layer.InitializeAsync(new PhysicalLayerConfiguration
{
    ChannelType = ChannelType.CAN_CHANNEL,
    TxBufferSize = 2048,
    RxBufferSize = 2048
});
```

### Con Configurazione UART

```csharp
var config = new PhysicalLayerConfiguration
{
    ChannelType = ChannelType.UART_CHANNEL,
    PortName = "COM3",
    BaudRate = 115200,
    ReadTimeoutMs = 500,
    WriteTimeoutMs = 500
};

var layer = new PhysicalLayer();
await layer.InitializeAsync(config);
```

### Trasmissione Dati

```csharp
// Trasmissione (downstream)
var context = new LayerContext { Direction = FlowDirection.Downstream };
var result = await layer.ProcessDownstreamAsync(frameBytes, context);

if (!result.IsSuccess)
{
    Console.WriteLine($"Errore trasmissione: {result.Error}");
}
```

---

## Driver Supportati

| Driver | Progetto | Hardware | Note |
|--------|----------|----------|------|
| `CanChannelDriver` | `Drivers.Can` | PEAK PCAN | NetInfo chunking |
| `BleChannelDriver` | `Drivers.Ble` | Plugin.BLE | MTU negotiation, auto-reconnect |
| `UartChannelDriver` | (Pianificato) | Serial ports | - |
| `CloudChannelDriver` | (Pianificato) | HTTP/WebSocket | - |

### Nota Architetturale (PL-012)

Il driver viene **iniettato** dall'applicazione, non creato dal Protocol:
- Protocol non dipende da librerie hardware (PCAN, Plugin.BLE)
- Permette testing con mock driver
- Separazione responsabilità: Protocol = logica, Driver = hardware

---

## Issue Correlate

→ [PhysicalLayer/ISSUES.md](./ISSUES.md)

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| Alta | 0 | 3 |
| Media | 2 | 1 |
| Bassa | 4 | 5 |
| **Totale** | **6** | **9** |

### Issue Aperte Principali

| ID | Titolo | Priorità |
|----|--------|----------|
| PL-003 | Config TxBufferSize/RxBufferSize Ignorata | Media |
| PL-007 | Timeout Configurabile I/O (Parziale) | Media |
| PL-004 | ProtocolRxBuffer.IndexOf() O(n*m) | Bassa |
| PL-013 | RxBuffer.IndexOf() Lettura Fuori Lock | Bassa |

### Issue Risolte Recenti

| ID | Titolo | Data |
|----|--------|------|
| PL-015 | ChannelType Property su Driver | 2026-02-11 |
| PL-016 | Config Validation nel Costruttore | 2026-02-11 |
| PL-001 | Buffer TX Sync Issue | 2026-02-06 |
| PL-012 | CreateChannelDriver Rimosso | 2026-02-06 |

---

## Riferimenti Firmware C

| Componente C# | File C | Struttura/Funzione |
|---------------|--------|-------------------|
| `PhysicalLayer` | `SP_Physical.c` | `SP_Phy_*()` |
| `ProtocolTxBuffer` | `SP_Physical.c` | `SP_Phy_TxBuffer[]` |
| `ProtocolRxBuffer` | `SP_Physical.c` | `SP_Phy_RxBuffer[]` |
| `DEFAULT_TX_BUFFER_SIZE` | `SP_Physical.h` | `BUFFER_TX_LEN_MAX` |
| `DEFAULT_RX_BUFFER_SIZE` | `SP_Physical.h` | `BUFFER_RX_LEN_MAX` |

**Repository:** `stem-fw-protocollo-seriale-stem/` (read-only)

---

## Links

- [Stack README](../Stack/README.md) - Orchestrazione layer
- [Base README](../Base/README.md) - Interfacce e classi base

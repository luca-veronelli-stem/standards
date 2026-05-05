# Transport Layer (Layer 4)

## Panoramica

Il **Transport Layer** è il quarto livello dello stack protocollare STEM, corrispondente al Layer 4 del modello OSI. Si occupa della frammentazione dei payload di grandi dimensioni in chunk e del loro riassemblaggio lato ricevitore, garantendo l'affidabilità end-to-end della trasmissione.

> **Ultimo aggiornamento:** 2026-02-13

---

## Responsabilità

- **Frammentazione (chunking)** di payload grandi in chunk (dimensione variabile per canale)
- **Riassemblaggio** chunk in payload completi
- **Gestione Packet ID** rolling (1-7) per tracking pacchetti concorrenti
- **Serializzazione/deserializzazione** chunk per la trasmissione
- **Timeout buffer** per cleanup riassemblaggi incompleti
- **Channel-Aware Chunking** (T-008): dimensioni chunk ottimizzate per canale
- **Raccolta statistiche** su chunking, riassemblaggio, buffer e errori

---

## Architettura

```
TransportLayer/
├── TransportLayer.cs                   # Implementazione principale del layer
├── Helpers/
│   ├── PacketChunker.cs                # Frammentazione payload in chunk
│   ├── ChunkReassembler.cs             # Riassemblaggio chunk in payload
│   ├── ChunkSerializer.cs              # Serializzazione/deserializzazione chunk
│   ├── ChunkSizeResolver.cs            # Risoluzione dimensione chunk per canale
│   └── PacketIdGenerator.cs            # Generatore ID rolling (1-7)
├── Models/
│   ├── TransportLayerConfiguration.cs  # Configurazione runtime
│   ├── TransportLayerConstants.cs      # Costanti chunking e bit fields
│   ├── TransportLayerStatistics.cs     # Statistiche aggregate
│   ├── TransportChunk.cs               # Struttura dati del chunk
│   ├── ChunkMetadata.cs                # Metadata impacchettati (16 bit)
│   └── ReassemblyResult.cs             # Risultato del riassemblaggio
└── Enums/
    └── ReassemblyError.cs              # Errori riassemblaggio
```

---

## Formato Dati

### Struttura Chunk (UART/Cloud)

```
┌───────────────┬───────────────┬────────────────────────┐
│ ChunkMetadata │ DestinationId │         Data           │
│    2 bytes    │    4 bytes    │      max N bytes       │
└───────────────┴───────────────┴────────────────────────┘
        └──────── Header (6 bytes) ────────┘
```

| Campo | Offset | Size | Endianness | Descrizione |
|-------|--------|------|------------|-------------|
| `ChunkMetadata` | 0 | 2 bytes | Little-Endian | Metadata impacchettati (vedi sotto) |
| `DestinationId` | 2 | 4 bytes | Big-Endian | SRID dispositivo destinazione |
| `Data` | 6 | N bytes | - | Payload del chunk |

### ChunkMetadata (16 bit) - Little-Endian

```
Bit:  15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
      │─── ChunksRemaining(10) ───│SL│──PktId(3)──│Ver(2)│
```

| Campo | Bit | Mask | Descrizione |
|-------|-----|------|-------------|
| `Version` | 0-1 | `0x03` | Versione protocollo (attuale: 0) |
| `PacketId` | 2-4 | `0x07` | ID pacchetto rolling (1-7) |
| `SetLength` | 5 | `0x01` | 1 = primo chunk, 0 = chunk successivi |
| `ChunksRemaining` | 6-15 | `0x3FF` | Chunk rimanenti (countdown, 0 = ultimo) |

### Packet ID Rolling (1-7)

Il Packet ID permette di tracciare fino a 7 pacchetti concorrenti:
- Range: 1-7 (0 non usato)
- Rolling: dopo 7 torna a 1
- Permette riassemblaggio multi-sorgente

---

## Componenti Principali

### TransportLayer

Classe principale che eredita da `ProtocolLayerBase`. Orchestra `PacketChunker` e `ChunkReassembler`.

```csharp
public class TransportLayer : ProtocolLayerBase
{
    public override string LayerName => "Transport";
    public override int LayerLevel => 4;
}
```

### Helper: PacketChunker

Frammenta payload grandi in chunk con dimensione configurabile per canale.

**Metodi principali:**
- `CreateChunks(byte[], uint destinationId)` - Payload → Lista chunk
- `GetChunkDataSize()` - Dimensione dati per chunk attuale

### Helper: ChunkReassembler

Riassembla chunk in payload completi, gestendo timeout e cleanup.

**Metodi principali:**
- `AddChunk(TransportChunk)` - Aggiunge chunk al buffer
- `TryGetCompletePacket(packetId)` - Ottiene pacchetto completato
- `CleanupStaleBuffers()` - Rimuove buffer scaduti

### Helper: ChunkSerializer

Serializza/deserializza chunk per trasmissione wire.

**Metodi principali:**
- `Serialize(TransportChunk)` - Chunk → byte[]
- `Deserialize(byte[])` - byte[] → TransportChunk

### Helper: ChunkSizeResolver

Determina la dimensione chunk ottimale per canale (T-008).

**Metodi principali:**
- `GetChunkDataSize(ChannelType)` - Canale → dimensione chunk

### Helper: PacketIdGenerator

Genera Packet ID rolling (1-7) thread-safe.

**Metodi principali:**
- `GetNextId()` - Ottiene prossimo ID (1-7, rolling)

---

## Configurazione

Classe: `TransportLayerConfiguration`

| Proprietà | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `ChannelType` | `ChannelType` | `UART_CHANNEL` | Tipo canale per dimensione chunk |
| `MaxChunkDataSize` | `int` | `0` (auto) | 0 = auto da ChannelType, >0 = override |
| `MaxChunksPerPacket` | `int` | `1023` | Massimo chunk per pacchetto |
| `ReassemblyTimeout` | `TimeSpan` | `30s` | Timeout buffer incompleti |
| `CleanupInterval` | `TimeSpan` | `10s` | Intervallo cleanup buffer stale |

### Channel-Aware Chunk Sizes (T-008)

| ChannelType | Chunk Data Size | Note |
|-------------|-----------------|------|
| `CAN_CHANNEL` | Passthrough | Chunking nel driver (NetInfo) |
| `BLE_CHANNEL` | Passthrough | Chunking nel driver (MTU-based) |
| `UART_CHANNEL` | 200 bytes | Buffer seriali standard |
| `CLOUD_CHANNEL` | 1024 bytes | Payload HTTP ottimali |

### Validazione

Il metodo `Validate()` verifica:
- `MaxChunkDataSize` deve essere 0 (auto) o ≥ 1
- `MaxChunksPerPacket` deve essere tra 1 e 1023
- `ReassemblyTimeout` deve essere tra 5s e 300s
- `CleanupInterval` deve essere tra 1s e 60s

### Esempio

```csharp
var config = new TransportLayerConfiguration
{
    ChannelType = ChannelType.UART_CHANNEL,
    ReassemblyTimeout = TimeSpan.FromSeconds(60),
    CleanupInterval = TimeSpan.FromSeconds(15)
};
config.Validate();
```

---

## Costanti

Classe: `TransportLayerConstants`

### Costanti Protocollo - Chunking

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `MAX_CHUNK_DATA_SIZE` | `200` | Dimensione massima dati chunk (default) |
| `MAX_CHUNKS_REMAINING` | `1023` | Campo a 10 bit |
| `MIN_PACKET_ID` | `1` | Packet ID minimo |
| `MAX_PACKET_ID` | `7` | Packet ID massimo |
| `FIRST_CHUNK` | `1` | SetLength = primo chunk |
| `OTHER_CHUNK` | `0` | SetLength = chunk successivi |
| `HEADER_SIZE` | `6` | ChunkMetadata(2) + DestId(4) |

### Costanti Protocollo - Bit Fields

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `PROTOCOL_VERSION_MASK` | `0x03` | Maschera versione (2 bit) |
| `PACKET_ID_MASK` | `0x07` | Maschera PacketId (3 bit) |
| `SET_LENGTH_MASK` | `0x01` | Maschera SetLength (1 bit) |
| `CHUNKS_REM_MASK` | `0x3FF` | Maschera ChunksRemaining (10 bit) |

### Costanti Protocollo - Channel-Specific

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `CAN_CHUNK_DATA_SIZE` | `6` | Frame CAN - NetInfo header |
| `BLE_CHUNK_DATA_SIZE` | `98` | MTU tipico BLE |
| `UART_CHUNK_DATA_SIZE` | `200` | Buffer seriale |
| `CLOUD_CHUNK_DATA_SIZE` | `1024` | Payload HTTP |

### Valori Default

| Costante | Valore | Usato da |
|----------|--------|----------|
| `DEFAULT_REASSEMBLY_TIMEOUT_SECONDS` | `30` | `Configuration.ReassemblyTimeout` |
| `DEFAULT_CLEANUP_INTERVAL_SECONDS` | `10` | `Configuration.CleanupInterval` |

### Limiti Validazione

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `MIN_REASSEMBLY_TIMEOUT_SECONDS` | `5` | Timeout minimo |
| `MAX_REASSEMBLY_TIMEOUT_SECONDS` | `300` | Timeout massimo (5 min) |
| `MIN_CLEANUP_INTERVAL_SECONDS` | `1` | Cleanup minimo |
| `MAX_CLEANUP_INTERVAL_SECONDS` | `60` | Cleanup massimo |
| `MAX_REASSEMBLED_PAYLOAD_SIZE` | `65536` | Limite payload riassemblato (64KB) |

---

## Flusso Dati

### Downstream (Trasmissione - Chunking)

```
SessionLayer (Layer 5)
      │
      ▼
┌──────────────────────────────┐
│   ProcessDownstreamAsync     │
│   ─────────────────────────  │
│   1. Genera PacketId (1-7)   │
│   2. Calcola chunk size      │
│   3. Frammenta in chunk      │
│   4. Serializza ogni chunk   │
│   5. Invia a layer inferiore │
└──────────────────────────────┘
      │
      ▼ (per ogni chunk)
NetworkLayer (Layer 3)
```

### Upstream (Ricezione - Riassemblaggio)

```
NetworkLayer (Layer 3)
      │
      ▼
┌──────────────────────────────┐
│   ProcessUpstreamAsync       │
│   ─────────────────────────  │
│   1. Deserializza chunk      │
│   2. Estrae PacketId         │
│   3. Aggiunge a buffer       │
│   4. [Completo?] Riassembla  │
│   5. Passa a layer superiore │
└──────────────────────────────┘
      │
      ▼ (quando completo)
SessionLayer (Layer 5)
```

---

## Statistiche

Classe: `TransportLayerStatistics`

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `PacketsFragmented` | `long` | Pacchetti frammentati (downstream) |
| `PacketsReassembled` | `long` | Pacchetti riassemblati (upstream) |
| `ChunksCreated` | `long` | Chunk totali creati |
| `ChunksProcessed` | `long` | Chunk totali processati |
| `ReassemblyErrors` | `long` | Errori durante riassemblaggio |
| `OrphanChunks` | `long` | Chunk senza buffer associato |
| `TimedOutBuffers` | `long` | Buffer scaduti per timeout |
| `DuplicateChunks` | `long` | Chunk duplicati ricevuti |
| `OutOfOrderChunks` | `long` | Chunk fuori ordine |
| `PendingBuffers` | `int` | Buffer attualmente pendenti |
| `LastFragmentationAt` | `DateTime?` | Timestamp ultima frammentazione |
| `LastReassemblyAt` | `DateTime?` | Timestamp ultimo riassemblaggio |

### Accesso

```csharp
var stats = (TransportLayerStatistics)layer.Statistics;
Console.WriteLine($"Chunk creati: {stats.ChunksCreated}");
Console.WriteLine($"Buffer pendenti: {stats.PendingBuffers}");
```

---

## Eventi

Il ChunkReassembler espone i seguenti eventi (conformi a [EVENTARGS_STANDARD.md](../../../Docs/Standards/EVENTARGS_STANDARD.md)):

| Evento | EventArgs | Descrizione |
|--------|-----------|-------------|
| `BuffersTimedOut` | `BuffersTimedOutEventArgs` | Buffer di riassemblaggio rimossi per timeout |

### BuffersTimedOutEventArgs

| Proprietà | Tipo | Descrizione |
|-----------|------|-------------|
| `BufferCount` | `int` | Numero di buffer rimossi |
| `TotalBytesLost` | `int` | Totale byte persi (dati parziali accumulati) |
| `Timestamp` | `DateTime` | Timestamp UTC del cleanup |

**Invarianti:** `BufferCount > 0`, `TotalBytesLost ≥ 0`

### Esempio Sottoscrizione

```csharp
// Sottoscrizione interna in TransportLayer
_reassembler.BuffersTimedOut += (sender, e) =>
{
    _logger?.LogWarning(
        "Reassembly buffers timed out: count={Count}, bytesLost={Bytes}",
        e.BufferCount, e.TotalBytesLost);

    for (int i = 0; i < e.BufferCount; i++)
        _statistics.RecordTimedOutBuffer();
};
```

---

## Esempi di Utilizzo

### Inizializzazione Base (UART)

```csharp
var layer = new TransportLayer();
await layer.InitializeAsync(new TransportLayerConfiguration
{
    ChannelType = ChannelType.UART_CHANNEL
});
// Chunk size: 200 bytes
```

### Per Canale CAN (Passthrough)

```csharp
var config = new TransportLayerConfiguration
{
    ChannelType = ChannelType.CAN_CHANNEL
    // Chunking gestito dal driver CAN
};

var layer = new TransportLayer();
await layer.InitializeAsync(config);
```

### Con Timeout Personalizzati

```csharp
var config = new TransportLayerConfiguration
{
    ChannelType = ChannelType.CLOUD_CHANNEL,
    ReassemblyTimeout = TimeSpan.FromMinutes(2),
    CleanupInterval = TimeSpan.FromSeconds(30)
};

var layer = new TransportLayer();
await layer.InitializeAsync(config);
```

### Frammentazione Manuale

```csharp
// Payload grande (1000 bytes) su UART (chunk 200 bytes)
// Risultato: 5 chunk
byte[] payload = new byte[1000];
var context = new LayerContext 
{ 
    Direction = FlowDirection.Downstream,
    DestinationId = 0x12345678
};

var result = await layer.ProcessDownstreamAsync(payload, context);
// Invia 5 chunk al NetworkLayer
```

---

## Passthrough CAN e BLE

Per i canali **CAN** e **BLE**, il TransportLayer opera in modalità **passthrough**:

| Canale | Gestito da | Motivo |
|--------|------------|--------|
| CAN | `CanChannelDriver` | NetInfo header (2 byte) specifico CAN |
| BLE | `BleChannelDriver` | MTU negoziato runtime (23-517 bytes) |

**Comportamento passthrough:**
1. Genera `PacketId` (rolling 1-7)
2. Passa dati raw al layer inferiore
3. Il driver gestisce chunking specifico

**Benefici:**
- Ottimizzazione basata su info runtime (MTU BLE)
- Nessun doppio chunking
- Header specifici per canale

---

## Issue Correlate

→ [TransportLayer/ISSUES.md](./ISSUES.md)

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| Alta | 0 | 3 |
| Media | 7 | 2 |
| Bassa | 3 | 2 |
| **Totale** | **10** | **7** |

### Issue Aperte Principali

| ID | Titolo | Priorità |
|----|--------|----------|
| TL-004 | PacketChunker Non Valida Limiti Input | Media |
| TL-005 | GetTotalChunksFromFirst Logica Errata | Media |
| TL-013 | ChunkSerializer Non Usa BinaryPrimitives | Media |
| TL-015 | TransportLayerStatistics PendingBuffers Non Aggiornato | Media |

### Issue Risolte Recenti

| ID | Titolo | Data |
|----|--------|------|
| TL-011 | ChunkReassembler Buffer Senza Limite | 2026-02-13 |
| TL-001 | ChunkReassembler Non Ha Timeout | 2026-01-28 |

### Issue Correlate Trasversali

| ID | Titolo | Impatto |
|----|--------|---------|
| T-015 | Architettura Chunking Driver vs TransportLayer | TransportLayer potrebbe gestire chunking per tutti i canali |
| T-013 | Lifecycle Helper: Costruttore vs InitializeAsync | ChunkReassembler creato con default |

---

## Riferimenti Firmware C

| Componente C# | File C | Struttura/Funzione |
|---------------|--------|-------------------|
| `TransportLayer` | `SP_Network_Layer.c` | `SP_NL_*()` |
| `PacketChunker` | `SP_Network_Layer.c` | `SP_NL_Chunk()` |
| `ChunkReassembler` | `SP_Network_Layer.c` | `SP_NL_Reassemble()` |
| `ChunkMetadata` | `SP_Network_Layer.h` | `SP_NL_HEADER_t` |
| `MAX_CHUNK_DATA_SIZE` | `SP_Network_Layer.h` | `MAX_CHUNCK_GEN` |

**Repository:** `stem-fw-protocollo-seriale-stem/` (read-only)

---

## Links

- [Stack README](../Stack/README.md) - Orchestrazione layer
- [Base README](../Base/README.md) - Interfacce e classi base

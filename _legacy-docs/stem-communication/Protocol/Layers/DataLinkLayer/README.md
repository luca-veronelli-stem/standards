# Data Link Layer (Layer 2)

## Panoramica

Il **Data Link Layer** è il secondo livello dello stack protocollare STEM, corrispondente al Layer 2 del modello OSI. Si occupa dell'integrità dei frame, del calcolo e validazione CRC16, dell'identificazione del mittente e dell'indicazione del tipo di crittografia.

> **Ultimo aggiornamento:** 2026-02-13

---

## Responsabilità

- **Integrità dei frame** tramite CRC16 Modbus
- **Identificazione mittente** (SenderId a 32 bit)
- **Indicazione crittografia** (CryptType)
- **Costruzione frame** con header e CRC
- **Parsing frame** da buffer raw
- **Validazione CRC** sui pacchetti ricevuti
- **Raccolta statistiche** su frame, errori CRC, parsing e throughput

---

## Architettura

```
DataLinkLayer/
├── DataLinkLayer.cs                    # Implementazione principale del layer
├── Helpers/
│   ├── Crc16Calculator.cs              # Calcolo CRC16 Modbus
│   ├── DataLinkFrameBuilder.cs         # Costruzione frame con CRC
│   ├── DataLinkFrameParser.cs          # Parsing buffer in frame
│   ├── DataLinkFrameSerializer.cs      # Serializzazione/deserializzazione
│   └── DataLinkFrameValidator.cs       # Validazione CRC
├── Models/
│   ├── DataLinkFrame.cs                # Struttura del frame
│   ├── DataLinkLayerConstants.cs       # Costanti (offset, dimensioni, CRC)
│   ├── DataLinkLayerStatistics.cs      # Statistiche del layer
│   └── ParseResult.cs                  # Risultato del parsing
└── Enums/
    └── ParseError.cs                   # Tipi di errore parsing
```

---

## Formato Dati

### Struttura del Frame DataLink

```
┌───────┬──────────┬────────┬───────────────┬─────────┐
│ Crypt │ SenderId │ Length │     Data      │  CRC16  │
│1 byte │ 4 bytes  │2 bytes │   N bytes     │ 2 bytes │
└───────┴──────────┴────────┴───────────────┴─────────┘
        └──── Header (7 bytes) ────┘
```

| Campo | Offset | Size | Endianness | Descrizione |
|-------|--------|------|------------|-------------|
| `Crypt` | 0 | 1 byte | - | Tipo crittografia (`NO_CRYPT=0`, `AES128=1`) |
| `SenderId` | 1 | 4 bytes | Big-Endian | SRID dispositivo mittente |
| `Length` | 5 | 2 bytes | Big-Endian | Lunghezza payload (N) |
| `Data` | 7 | N bytes | - | Payload dal layer superiore |
| `CRC16` | 7+N | 2 bytes | Big-Endian | CRC16 Modbus (High, Low) |

### CRC16 Modbus

| Parametro | Valore |
|-----------|--------|
| **Polinomio** | `0xA001` (riflesso) |
| **Valore iniziale** | `0xFFFF` |
| **Byte inclusi** | `Crypt` + `SenderId` + `Length` + `Data` |

Il CRC viene calcolato su tutti i byte del frame escluso il CRC stesso (Header + Data).

---

## Componenti Principali

### DataLinkLayer

Classe principale che eredita da `ProtocolLayerBase`. Orchestra tutti i componenti helper.

```csharp
public class DataLinkLayer : ProtocolLayerBase
{
    public override string LayerName => "DataLink";
    public override int LayerLevel => 2;
}
```

**Nota:** Questo layer non richiede configurazione specifica - tutti i parametri sono definiti dal protocollo.

### Helper: Crc16Calculator

Calcola CRC16 Modbus. Metodo centralizzato per calcolo e validazione (DL-001).

**Metodi principali:**
- `Compute(byte[])` - Calcola CRC su array
- `ComputeForFrame(byte[])` - Calcola CRC su frame (esclude ultimi 2 bytes)

### Helper: DataLinkFrameBuilder

Costruisce frame completi con header e CRC.

**Metodi principali:**
- `Build(cryptType, senderId, data)` - Costruisce frame completo

### Helper: DataLinkFrameParser

Parsa buffer raw in struttura `DataLinkFrame`.

**Metodi principali:**
- `Parse(byte[])` - Buffer → ParseResult con Frame o Error

### Helper: DataLinkFrameValidator

Valida CRC dei frame ricevuti.

**Metodi principali:**
- `ValidateCrc(byte[])` - Verifica CRC del frame
- `IsValidFrame(byte[])` - Validazione completa (size + CRC)

### Helper: DataLinkFrameSerializer

Serializza/deserializza frame per trasmissione wire.

**Metodi principali:**
- `Serialize(DataLinkFrame)` - Frame → byte[]
- `Deserialize(byte[])` - byte[] → DataLinkFrame

---

## Configurazione

Classe: `DataLinkLayerConfiguration` *(pianificata - vedere DL-004)*

Attualmente il DataLinkLayer non ha una configurazione dedicata. È pianificata l'aggiunta di `DataLinkLayerConfiguration` per supportare comportamenti diversi in ambienti di produzione e debug.

### Comportamento Attuale

| Parametro | Valore | Note |
|-----------|--------|------|
| Formato frame | Fisso | Definito dal protocollo |
| Algoritmo CRC | CRC16 Modbus | Non configurabile |
| CRC invalido | **Scarta frame** | Comportamento fisso |

### Configurazione Pianificata (DL-004)

| Proprietà | Default | Descrizione |
|-----------|---------|-------------|
| `CrcFailurePolicy` | `RejectPacket` | Comportamento su CRC invalido |

**CrcFailurePolicy:**
| Valore | Ambiente | Comportamento |
|--------|----------|---------------|
| `RejectPacket` | **Produzione** | Scarta frame con CRC invalido |
| `AcceptWithWarning` | Debug | Accetta frame, log warning, flag in metadata |

### Inizializzazione Attuale

```csharp
var layer = new DataLinkLayer();
await layer.InitializeAsync();  // Nessuna config necessaria (per ora)
```

---

## Costanti

Classe: `DataLinkLayerConstants`

### Costanti Protocollo - Formato Frame

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `HEADER_SIZE` | `7` | Crypt(1) + SenderId(4) + Length(2) |
| `CRC_SIZE` | `2` | Dimensione CRC16 |
| `MIN_FRAME_SIZE` | `9` | Header(7) + CRC(2), payload vuoto |
| `CRYPT_OFFSET` | `0` | Offset campo Crypt |
| `SENDER_ID_OFFSET` | `1` | Offset campo SenderId |
| `LENGTH_OFFSET` | `5` | Offset campo Length |
| `DATA_OFFSET` | `7` | Offset inizio Data |

### Costanti Protocollo - CRC16 Modbus

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `CRC_INIT_VALUE` | `0xFFFF` | Valore iniziale CRC |
| `CRC_POLYNOMIAL` | `0xA001` | Polinomio riflesso |

---

## Flusso Dati

### Downstream (Trasmissione)

```
NetworkLayer (Layer 3)
      │
      ▼
┌──────────────────────────────┐
│   ProcessDownstreamAsync     │
│   ─────────────────────────  │
│   1. Estrae CryptType        │
│   2. Estrae SenderId         │
│   3. Costruisce header       │
│   4. Calcola CRC16           │
│   5. Serializza frame        │
│   6. Aggiorna statistiche    │
└──────────────────────────────┘
      │
      ▼
PhysicalLayer (Layer 1)
```

### Upstream (Ricezione)

```
PhysicalLayer (Layer 1)
      │
      ▼
┌──────────────────────────────┐
│   ProcessUpstreamAsync       │
│   ─────────────────────────  │
│   1. Verifica size minimo    │
│   2. Parsa header            │
│   3. Valida CRC16            │
│   4. [CRC OK?] Estrae Data   │
│   5. [CRC Err?] Scarta       │
│   6. Aggiorna statistiche    │
└──────────────────────────────┘
      │
      ▼
NetworkLayer (Layer 3)
```

---

## Statistiche

Classe: `DataLinkLayerStatistics`

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `FramesReceivedOk` | `long` | Frame ricevuti con CRC valido |
| `FramesSentOk` | `long` | Frame inviati con successo |
| `CrcErrors` | `long` | Errori CRC rilevati |
| `ParseErrors` | `long` | Errori di parsing |
| `FrameSizeErrors` | `long` | Frame troppo corti o length mismatch |
| `InvalidCryptType` | `long` | Frame con CryptType non valido |
| `BytesReceived` | `long` | Byte totali ricevuti |
| `BytesSent` | `long` | Byte totali inviati |
| `LastFrameReceivedAt` | `DateTime?` | Timestamp ultimo frame ricevuto |
| `LastFrameSentAt` | `DateTime?` | Timestamp ultimo frame inviato |

### Accesso

```csharp
var stats = (DataLinkLayerStatistics)layer.Statistics;
Console.WriteLine($"Frame ricevuti OK: {stats.FramesReceivedOk}");
Console.WriteLine($"Errori CRC: {stats.CrcErrors}");
Console.WriteLine($"Throughput RX: {stats.BytesReceived / stats.Uptime.TotalSeconds:F1} bytes/s");
```

---

## Esempi di Utilizzo

### Inizializzazione

```csharp
var layer = new DataLinkLayer();
await layer.InitializeAsync();
```

### Costruzione Frame Manuale

```csharp
// Costruisci frame
var frame = DataLinkFrameBuilder.Build(
    cryptType: CryptType.AES128,
    senderId: 0x00030141,  // SRID_EDEN
    data: payloadBytes
);

// Serializza per trasmissione
byte[] wireData = DataLinkFrameSerializer.Serialize(frame);
```

### Parsing Frame Ricevuto

```csharp
// Parsa frame ricevuto
var parseResult = DataLinkFrameParser.Parse(receivedBytes);

if (parseResult.IsSuccess)
{
    var frame = parseResult.Frame;
    Console.WriteLine($"Sender: 0x{frame.SenderId:X8}");
    Console.WriteLine($"Crypt: {frame.CryptType}");
    Console.WriteLine($"Data length: {frame.Data.Length}");
}
else
{
    Console.WriteLine($"Parse error: {parseResult.Error}");
}
```

### Validazione CRC

```csharp
// Valida CRC di un frame
bool isValid = DataLinkFrameValidator.ValidateCrc(frameBytes);

if (!isValid)
{
    Console.WriteLine("CRC error - frame corrotto");
}
```

---

## Errori di Parsing

Enum: `ParseError`

| Valore | Descrizione |
|--------|-------------|
| `None` | Nessun errore |
| `BufferTooShort` | Buffer < MIN_FRAME_SIZE (9 bytes) |
| `LengthMismatch` | Campo Length non corrisponde a dimensione effettiva |

> **Nota:** Buffer `null` lancia `ArgumentNullException` (ERR-040) invece di restituire errore enum.
> Questo segue lo standard ERROR_HANDLING: null è un bug del chiamante, non un errore di protocollo.

---

## Issue Correlate

→ [DataLinkLayer/ISSUES.md](./ISSUES.md)

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| Alta | 1 | 2 |
| Media | 3 | 3 |
| Bassa | 2 | 1 |
| **Totale** | **6** | **6** |

### Issue Aperte Principali

| ID | Titolo | Priorità |
|----|--------|----------|
| DL-002 | Validazione Input in DataLinkFrameBuilder.Build() | Alta |
| DL-004 | Mancanza DataLinkLayerConfiguration | Media |
| DL-005 | Crc16Calculator Nuova Istanza per Ogni Calcolo | Media |
| DL-006 | ProcessUpstreamAsync Non Gestisce Frame Data Vuoto | Media |

### Issue Risolte Recenti

| ID | Titolo | Data |
|----|--------|------|
| DL-001 | CRC Calcolo Duplicato (Centralizzato) | 2026-02-06 |
| DL-003 | Statistiche Thread-Safe | 2026-02-05 |

---

## Riferimenti Firmware C

| Componente C# | File C | Struttura/Funzione |
|---------------|--------|-------------------|
| `DataLinkLayer` | `SP_Transport_Layer.c` | `SP_TL_*()` |
| `DataLinkFrame` | `SP_Transport_Layer.h` | `SP_TL_DATA_t` |
| `Crc16Calculator` | `SP_CRC.c` | `SP_CRC_Calc()` |
| `HEADER_SIZE` | `SP_Transport_Layer.h` | `SP_TL_HEADER_SIZE` |
| `CRC_POLYNOMIAL` | `SP_CRC.h` | `CRC16_POLY` |

**Repository:** `stem-fw-protocollo-seriale-stem/` (read-only)

---

## Links

- [Stack README](../Stack/README.md) - Orchestrazione layer
- [Base README](../Base/README.md) - Interfacce e classi base

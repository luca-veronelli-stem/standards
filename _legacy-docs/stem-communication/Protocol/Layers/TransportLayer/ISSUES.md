# TransportLayer - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunità di refactoring e violazioni di best practice per il componente **TransportLayer**.

> **Ultimo aggiornamento:** 2026-02-13

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 0 | 3 |
| **Media** | 7 | 2 |
| **Bassa** | 3 | 2 |

**Totale aperte:** 10  
**Totale risolte:** 7

---

## Issue Trasversali Correlate

| ID | Titolo | Status | Impatto su TransportLayer |
|----|--------|--------|---------------------------|
| **T-009** | Unificare Chunking CAN/BLE nel TransportLayer | Pianificato | TransportLayer gestirà chunking per tutti i canali |
| **T-013** | Lifecycle Helper: Costruttore vs InitializeAsync | Aperto | `ChunkReassembler` creato con default, config non applicata |

→ [Protocol/ISSUES.md](../../ISSUES.md) per dettagli completi.

---

## Indice Issue Aperte

- [TL-004 - PacketChunker Non Valida Limiti Input](#tl-004---packetchunker-non-valida-limiti-input)
- [TL-005 - GetTotalChunksFromFirst Logica Errata](#tl-005---gettotalchunksfromfirst-logica-errata)
- [TL-007 - CloneContext Metodo Non Utilizzato](#tl-007---clonecontext-metodo-non-utilizzato)
- [TL-008 - ChunkMetadata Struct Mutabile](#tl-008---chunkmetadata-struct-mutabile)
- [TL-011 - ChunkReassembler packetBuffers Non Ha Limite Dimensione](#tl-011---chunkreassembler-packetbuffers-non-ha-limite-dimensione)
- [TL-012 - PacketBuffer GetData Alloca Nuovo Array Ad Ogni Chiamata](#tl-012---packetbuffer-getdata-alloca-nuovo-array-ad-ogni-chiamata)
- [TL-013 - ChunkSerializer Non Usa BinaryPrimitives per Serializzazione](#tl-013---chunkserializer-non-usa-binaryprimitives-per-serializzazione)
- [TL-014 - ChunkMetadata Struct Mutabile con Set Pubblici](#tl-014---chunkmetadata-struct-mutabile-con-set-pubblici)
- [TL-015 - TransportLayerStatistics PendingBuffers Non Viene Aggiornato](#tl-015---transportlayerstatistics-pendingbuffers-non-viene-aggiornato)
- [TL-016 - PacketBuffer data Usa List byte Invece di Buffer Preallocato](#tl-016---packetbuffer-data-usa-list-byte-invece-di-buffer-preallocato)
- [TL-017 - PacketChunker Non Previene Integer Overflow in CalculateChunkCount](#tl-017---packetchunker-non-previene-integer-overflow-in-calculatechunkcount)

## Indice Issue Risolte

- [TL-002 - ProcessDownstreamAsync Concatena Chunk Serializzati Senza Delimitatore](#tl-002---processdownstreamasync-concatena-chunk-serializzati-senza-delimitatore)
- [TL-009 - Mancanza di Statistiche per Monitoraggio](#tl-009---mancanza-di-statistiche-per-monitoraggio)
- [TL-006 - TransportLayerConstants E Internal Ma Usata Esternamente](#tl-006---transportlayerconstants-e-internal-ma-usata-esternamente)
- [TL-010 - Mancanza di Logging](#tl-010---mancanza-di-logging)
- [TL-001 - ChunkReassembler Non Ha Timeout per Buffer Pendenti](#tl-001---chunkreassembler-non-ha-timeout-per-buffer-pendenti)
- [TL-003 - TransportLayer Non Implementa IDisposable](#tl-003---transportlayer-non-implementa-idisposable)

---

## Priorita Media

### TL-004 - PacketChunker Non Valida Limiti Input

**Categoria:** Bug  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

Il metodo `Split()` non valida i parametri di input. Un payload enorme potrebbe superare `MAX_CHUNKS_PER_PACKET` (1023), e `packetId` potrebbe essere fuori range (0 o > 7).

#### File Coinvolti

- `Protocol/Layers/TransportLayer/Helpers/PacketChunker.cs` (righe 41-76)

#### Benefici Attesi

- Fail-fast con messaggi chiari
- Prevenzione overflow silenti
- Chunk sempre validi

---

### TL-005 - GetTotalChunksFromFirst Logica Errata

**Categoria:** Bug  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

Il metodo `GetTotalChunksFromFirst()` ha una logica errata. Ritorna sempre 1 per chunk non-primi, quando dovrebbe ottenere il valore dal buffer del reassembler.

#### File Coinvolti

- `Protocol/Layers/TransportLayer/TransportLayer.cs` (righe 174-182)

#### Benefici Attesi

- Metadata corretti
- Nome metodo riflette comportamento

---

### TL-007 - CloneContext Metodo Non Utilizzato

**Categoria:** Code Smell  
**Priorita:** Media  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

Il metodo privato `CloneContext()` in `TransportLayer` non viene mai chiamato. Dead code.

#### File Coinvolti

- `Protocol/Layers/TransportLayer/TransportLayer.cs` (righe 184-205)

#### Benefici Attesi

- Codice piu pulito
- Meno complessita

---

### TL-012 - PacketBuffer GetData Alloca Nuovo Array Ad Ogni Chiamata

**Categoria:** Performance  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

`GetData()` in `PacketBuffer` usa la sintassi `[.. _data]` che crea un nuovo array ad ogni chiamata, causando allocazioni inutili.

#### File Coinvolti

- `Protocol/Layers/TransportLayer/Helpers/ChunkReassembler.cs` (riga 324)

#### Soluzione Proposta

Caching dell'array:

```csharp
private byte[]? _cachedArray;

public byte[] GetData()
{
    return _cachedArray ??= _data.ToArray();
}
```

#### Benefici Attesi

- Riduzione allocazioni ripetute

---

### TL-013 - ChunkSerializer Non Usa BinaryPrimitives per Serializzazione

**Categoria:** Code Smell  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

`ChunkSerializer.Serialize()` e `Deserialize()` usano manipolazione manuale dei bit invece di `BinaryPrimitives` che e' piu' sicuro, leggibile e performante.

#### File Coinvolti

- `Protocol/Layers/TransportLayer/Helpers/ChunkSerializer.cs` (righe 28-99)

#### Benefici Attesi

- Codice piu conciso (1 riga invece di 4)
- Endianness gestita esplicitamente
- Performance migliorate

---

### TL-015 - TransportLayerStatistics PendingBuffers Non Viene Aggiornato

**Categoria:** Bug  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

La proprieta `PendingBuffers` in `TransportLayerStatistics` non viene mai aggiornata. Rimane sempre a 0, rendendo inutile questa metrica.

#### File Coinvolti

- `Protocol/Layers/TransportLayer/Models/TransportLayerStatistics.cs` (riga 55)
- `Protocol/Layers/TransportLayer/TransportLayer.cs`

#### Soluzione Proposta

Aggiornare ad ogni operazione di riassemblaggio:

```csharp
// TransportLayer.cs - ProcessUpstreamAsync
var result = _reassembler.AddChunk(chunk);
_statistics.RecordChunkProcessed();

// Aggiorna buffer pendenti dopo ogni operazione
_statistics.PendingBuffers = _reassembler.GetPendingCount();
```

#### Benefici Attesi

- Statistiche complete per monitoring
- Identificazione accumulo buffer

---

### TL-017 - PacketChunker Non Previene Integer Overflow in CalculateChunkCount

**Categoria:** Security  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-02-02  

#### Descrizione

Il metodo `CalculateChunkCount()` esegue operazioni aritmetiche senza verificare overflow. Un payload intenzionalmente enorme potrebbe causare overflow silente.

#### File Coinvolti

- `Protocol/Layers/TransportLayer/Helpers/PacketChunker.cs` (righe 89-99)

#### Benefici Attesi

- Defense-in-depth
- Prevenzione overflow silenti

---

## Priorita Bassa

### TL-008 - ChunkMetadata Struct Mutabile

**Categoria:** Design  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

`ChunkMetadata` e' una struct mutabile con proprieta setter. Le struct mutabili in C# possono causare comportamenti inaspettati quando passate per valore.

#### File Coinvolti

- `Protocol/Layers/TransportLayer/Models/ChunkMetadata.cs`

#### Benefici Attesi

- Semantica chiara
- Nessun comportamento inaspettato

---

### TL-014 - ChunkMetadata Struct Mutabile con Set Pubblici

**Categoria:** Design
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

Duplicato di TL-008. `ChunkMetadata` e' struct mutabile. Considerare rendere readonly con factory methods.

#### File Coinvolti

- `Protocol/Layers/TransportLayer/Models/ChunkMetadata.cs`

---

### TL-016 - PacketBuffer data Usa List byte Invece di Buffer Preallocato

**Categoria:** Performance  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

`PacketBuffer` usa `List<byte>` che puo' causare multiple riallocazioni per payload grandi. Considerare pre-allocazione con capacita stimata.

#### File Coinvolti

- `Protocol/Layers/TransportLayer/Helpers/ChunkReassembler.cs` (righe 281-325)

#### Benefici Attesi

- Riduzione riallocazioni

---

## Issue Risolte

### TL-011 - ChunkReassembler packetBuffers Non Ha Limite Dimensione

**Categoria:** Security  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** ✅ Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-02-13  
**Branch:** fix/t-012  

#### Descrizione

Il dizionario `_packetBuffers` non aveva limite sulla dimensione del payload riassemblato.

#### Soluzione Implementata

1. Aggiunta costante `MAX_REASSEMBLED_PAYLOAD_SIZE = 65536` (64KB)
2. Check preventivo al primo chunk basato su `ChunksRemaining * MAX_CHUNK_DATA_SIZE`
3. Check durante l'aggiunta di ogni chunk
4. Nuovo errore `ReassemblyError.PayloadTooLarge`
5. Buffer rimosso quando si supera il limite

```csharp
// Check preventivo al primo chunk
int estimatedMaxSize = (chunk.Metadata.ChunksRemaining + 1) * MAX_CHUNK_DATA_SIZE;
if (estimatedMaxSize > MAX_REASSEMBLED_PAYLOAD_SIZE)
    return ReassemblyResult.Failure(ReassemblyError.PayloadTooLarge);

// Check durante aggiunta chunk
int newSize = existingBuffer.CurrentSize + chunk.Data.Length;
if (newSize > MAX_REASSEMBLED_PAYLOAD_SIZE)
    return ReassemblyResult.Failure(ReassemblyError.PayloadTooLarge);
```

#### File Modificati

- `Protocol/Layers/TransportLayer/Models/TransportLayerConstants.cs` - aggiunta costante
- `Protocol/Layers/TransportLayer/Helpers/ChunkReassembler.cs` - logica limite
- `Protocol/Layers/TransportLayer/Enums/ReassemblyError.cs` - nuovo errore

---

### TL-002 - ProcessDownstreamAsync Concatena Chunk Serializzati Senza Delimitatore

**Categoria:** Bug  
**Priorita:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-29  
**Branch:** fix/tl-002  

#### Descrizione

`ProcessDownstreamAsync()` serializzava tutti i chunk concatenandoli in un unico array. Il layer inferiore non poteva distinguere i chunk individuali.

#### Soluzione Implementata

Ritorna SOLO il primo chunk nei dati, tutti i chunk nei metadata con chiave `"AllChunks"`:

```csharp
var metadata = new Dictionary<string, object>
{
    ["ChunkCount"] = chunks.Count,
    ["PacketId"] = packetId,
    ["AllChunks"] = allChunkBytes,
    ["HasMoreChunks"] = chunks.Count > 1
};

return LayerResult.Success(firstChunkBytes, metadata);
```

#### Benefici Ottenuti

- Compatibile con protocollo C originale
- Chunk inviati individualmente
- MTU-compliant

---

### TL-009 - Mancanza di Statistiche per Monitoraggio

**Categoria:** Observability  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-29  
**Branch:** fix/t-004  

#### Descrizione

Il TransportLayer non tracciava alcuna statistica.

#### Soluzione Implementata

Creata classe `TransportLayerStatistics` che implementa `ILayerStatistics` con pattern T-005 (long Ticks per DateTime).

#### Benefici Ottenuti

- Monitoraggio performance
- Pattern thread-safe

---

### TL-006 - TransportLayerConstants E Internal Ma Usata Esternamente

**Categoria:** API  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-29  
**Branch:** fix/t-003  

#### Descrizione

`TransportLayerConstants` era dichiarata `internal`, ma necessaria per configurazione esterna.

#### Soluzione Implementata

Resa la classe `TransportLayerConstants` pubblica.

#### Benefici Ottenuti

- Costanti accessibili da assembly esterni

---

### TL-010 - Mancanza di Logging

**Categoria:** Observability  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-28  
**Branch:** fix/tl-002  

#### Descrizione

Il TransportLayer non implementava alcun logging.

#### Soluzione Implementata

Aggiunto `ILogger<TransportLayer>?` nel costruttore. Logging strutturato in tutte le operazioni critiche.

#### Benefici Ottenuti

- Troubleshooting semplificato
- Correlazione con log altri layer

---

### TL-001 - ChunkReassembler Non Ha Timeout per Buffer Pendenti

**Categoria:** Bug  
**Priorita:** Alta  
**Impatto:** Critico  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-28  
**Branch:** fix/tl-001  

#### Descrizione

Il `ChunkReassembler` accumulava buffer per pacchetti parzialmente ricevuti senza meccanismo di timeout, causando memory leak.

#### Soluzione Implementata

1. Implementato `IDisposable` in `ChunkReassembler`
2. Aggiunto `TimeSpan _bufferTimeout` (default 30s)
3. Aggiunto `Timer _cleanupTimer` (cleanup ogni 10s)
4. Aggiunto `DateTime CreatedAt` a `PacketBuffer` per tracking eta
5. Implementato `CleanupStaleBuffers()`

#### Test Aggiunti

- `AddChunk_WithTimeout_ShouldRemoveStaleBuffers`
- `Dispose_ShouldStopTimerAndClearBuffers`
- `Dispose_MultipleCalls_ShouldNotThrow`

#### Benefici Ottenuti

- Nessun memory leak
- Buffer orfani rimossi entro 30s
- Overhead minimo

---

### TL-003 - TransportLayer Non Implementa IDisposable

**Categoria:** Resource Management  
**Priorita:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-28  
**Branch:** fix/t-001  

#### Descrizione

TransportLayer non implementava IDisposable, causando resource leak del ChunkReassembler.

#### Soluzione Implementata

`TransportLayer` ora eredita da `ProtocolLayerBase` che implementa `IDisposable`. Il `ChunkReassembler` viene pulito in `DisposeResources()`.

Vedi issue trasversale T-001.

#### Benefici Ottenuti

- Nessun resource leak
- Pattern Dispose completo

# Drivers.Can - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunità di refactoring e violazioni di best practice per il componente **Drivers.Can**.

> **Ultimo aggiornamento:** 2026-02-26

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 1 | 2 |
| **Media** | 4 | 3 |
| **Bassa** | 3 | 2 |
| **Security** | 2 | 0 |

**Totale aperte:** 10  
**Totale risolte:** 7

---

## Issue Trasversali Correlate

| ID | Titolo | Status | Impatto su Drivers.Can |
|----|--------|--------|------------------------|
| **T-014** | Unificazione NetInfoCodec tra Driver CAN e BLE | Aperto | `NetInfoHelper` userà codec condiviso in `Protocol.Infrastructure` |
| **T-015** | Architettura Chunking Driver vs TransportLayer | Aperto | Chunking potrebbe spostarsi a TransportLayer con `OptimalChunkSize` |

→ [Protocol/ISSUES.md](../Protocol/ISSUES.md) per dettagli completi.

---

## Indice Issue Aperte

- [CAN-003 – Race Condition in PcanHardware.InitializeAsync](#can-003--race-condition-in-pcanhardwareinitializeasync)
- [CAN-004 – Allocazione Ripetuta in Loop WriteAsync](#can-004--allocazione-ripetuta-in-loop-writeasync)
- [CAN-005 – CanFrame.Data Non Validato](#can-005--canframedata-non-validato)
- [CAN-006 – FilterMask Non Utilizzata in SetFilterAsync](#can-006--filtermask-non-utilizzata-in-setfilterasync)
- [CAN-017 – Timeout Chunk Incompleti Non Implementato](#can-017--timeout-chunk-incompleti-non-implementato)
- [CAN-007 – Polling Busy-Wait in ReceiveAsync](#can-007--polling-busy-wait-in-receiveasync)
- [CAN-009 – Magic Strings per Device Path](#can-009--magic-strings-per-device-path)
- [CAN-016 – Allocazione in ExtractChunkData](#can-016--allocazione-in-extractchunkdata)
- [CAN-012 – Logging di Device Path Senza Sanitization](#can-012--logging-di-device-path-senza-sanitization)
- [CAN-019 – FilterMask Non Validata in CanConfiguration](#can-019--filtermask-non-validata-in-canconfiguration)

---

## Indice Issue Risolte

- [CAN-011 – XML Comments Incompleti](#can-011--xml-comments-incompleti)
- [CAN-010 – Naming Convention Inconsistente](#can-010--naming-convention-inconsistente)
- [CAN-001 – Blocking Call in Async Method](#can-001--blocking-call-in-async-method-disconnectdispose)
- [CAN-002 – Extended ID Hardcoded a Zero](#can-002--extended-id-hardcoded-a-zero-in-writeasync)
- [CAN-008 – Missing IAsyncDisposable](#can-008--missing-iasyncdisposable)
- [CAN-013 – BusWarning Trattato Come Errore Fatale](#can-013--buswarning-trattato-come-errore-fatale-in-receiveasync)
- [CAN-014 – Riassemblaggio Chunk Basato su NetInfo](#can-014--riassemblaggio-chunk-basato-su-netinfo-mancante)

---

## Priorità Alta

### CAN-003 – Race Condition in PcanHardware.InitializeAsync

**Categoria:** Bug  
**Priorità:** Alta  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-02-03

#### Descrizione

`InitializeAsync` controlla `_initialized` e poi lo imposta dentro un `lock`, ma il metodo è dichiarato async (ritorna `Task<bool>`) senza usare `await`. Il lock protegge solo operazioni sync, creando pattern confuso.

#### File Coinvolti

- `Drivers.Can\Hardware\Pcan\PcanHardware.cs` (righe 37-85)

#### Snippet Problematico

```csharp
public Task<bool> InitializeAsync(uint baudrate, string devicePath, CancellationToken cancellationToken = default)
{
    ThrowIfDisposed();
    
    lock (_lock)  // Lock sync in metodo "async"
    {
        if (_initialized)
            return Task.FromResult(true);
            
        // Operazioni SYNC
        PcanStatus status = Api.Initialize(_channel, pcanBitrate);
        _initialized = true;
    }
}
```

#### Problema Specifico

- Metodo dichiarato async ma internamente completamente sync
- Se in futuro si aggiungesse `await`, il `lock` non sarebbe più valido
- Pattern confuso per i consumer dell'API

#### Soluzione Proposta

Usare `SemaphoreSlim` per consistenza async:

```csharp
private readonly SemaphoreSlim _initLock = new(1, 1);

public async Task<bool> InitializeAsync(uint baudrate, string devicePath, CancellationToken ct = default)
{
    ThrowIfDisposed();
    
    await _initLock.WaitAsync(ct);
    try
    {
        if (_initialized)
            return true;
        // ... init logic ...
        _initialized = true;
        return true;
    }
    finally
    {
        _initLock.Release();
    }
}
```

#### Benefici Attesi

- Pattern async corretto e future-proof
- Supporto CancellationToken durante attesa lock
- Nessuna confusione tra sync lock e async signature

---

## Priorità Media

### CAN-004 – Allocazione Ripetuta in Loop WriteAsync

**Categoria:** Performance  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-02-03

#### Descrizione

In `WriteAsync()`, viene allocato un nuovo `byte[]` per ogni frame CAN trasmesso, causando GC pressure durante trasmissioni frequenti.

#### File Coinvolti

- `Drivers.Can\CanChannelDriver.cs` (righe 210-230)

#### Snippet Problematico

```csharp
for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++)
{
    // Allocazione per ogni frame
    byte[] frameData = new byte[NetInfoHelper.NET_INFO_SIZE + chunkDataSize];
    frameData[0] = netInfoBytes[0];
    frameData[1] = netInfoBytes[1];
    Array.Copy(data, offset, frameData, NetInfoHelper.NET_INFO_SIZE, chunkDataSize);
    // ...
}
```

#### Soluzione Proposta

Usare `ArrayPool<byte>` o `stackalloc`:

```csharp
Span<byte> frameData = stackalloc byte[8];  // Max CAN frame size
frameData[0] = netInfoBytes[0];
frameData[1] = netInfoBytes[1];
data.AsSpan(offset, chunkDataSize).CopyTo(frameData[2..]);
```

#### Benefici Attesi

- Zero allocazioni heap nel hot path
- Riduzione GC pressure
- Migliore latenza per messaggi grandi

---

### CAN-005 – CanFrame.Data Non Validato

**Categoria:** Bug  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-02-03

#### Descrizione

`CanFrame` è un record struct con `required byte[] Data`, ma non valida che `Data.Length <= 8` (limite CAN classico). Il DLC usa `Math.Min` nascondendo il problema.

#### File Coinvolti

- `Drivers.Can\Hardware\ICanHardware.cs` (righe 68-84)

#### Snippet Problematico

```csharp
public readonly record struct CanFrame
{
    public required byte[] Data { get; init; }  // Nessuna validazione
    public byte DLC => (byte)Math.Min(Data.Length, 8);  // Clamping silenzioso
}
```

#### Soluzione Proposta

Aggiungere validazione nell'init:

```csharp
public required byte[] Data 
{ 
    get => _data;
    init 
    {
        ArgumentNullException.ThrowIfNull(value);
        if (value.Length > 8)
            throw new ArgumentException("CAN frame data cannot exceed 8 bytes");
        _data = value;
    }
}
```

#### Benefici Attesi

- Fail-fast per dati invalidi
- DLC sempre accurato

---

### CAN-006 – FilterMask Non Utilizzata in SetFilterAsync

**Categoria:** Bug  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-02-03

#### Descrizione

`SetFilterAsync` accetta `filterMask` come parametro ma non lo usa, passando solo `filterId` all'API PCAN.

#### File Coinvolti

- `Drivers.Can\Hardware\Pcan\PcanHardware.cs` (righe 305-330)

#### Snippet Problematico

```csharp
public Task SetFilterAsync(uint filterId, uint filterMask, CancellationToken ct = default)
{
    PcanStatus status = Api.FilterMessages(
        _channel,
        filterId,
        filterId,  // Ignora filterMask!
        FilterMode.Extended);
}
```

#### Soluzione Proposta

Usare correttamente l'API PCAN per range filter:

```csharp
uint fromId = filterId & filterMask;
uint toId = filterId | ~filterMask;
PcanStatus status = Api.FilterMessages(_channel, fromId, toId, FilterMode.Extended);
```

#### Benefici Attesi

- Filtro hardware funziona come documentato
- Riduzione carico CPU per bus affollati

---

### CAN-017 – Timeout Chunk Incompleti Non Implementato

**Categoria:** Bug  
**Priorità:** Media  
**Impatto:** Alto  
**Status:** Aperto  
**Data Apertura:** 2026-02-06

#### Descrizione

`ReadWithMetadataAsync` accumula chunk per `packetId` in `_chunkQueues`, ma non ha timeout per chunk incompleti. Se un messaggio viene perso, i chunk parziali rimangono in memoria indefinitamente.

#### File Coinvolti

- `Drivers.Can\CanChannelDriver.cs` (righe 280-400)

#### Snippet Problematico

```csharp
// Accumula chunk per packetId
lock (_chunkLock)
{
    if (!_chunkQueues.TryGetValue(packetId, out var queue))
    {
        queue = new List<byte>(256);
        _chunkQueues[packetId] = queue;
    }
    queue.AddRange(chunkData);
    
    // Nessun timeout per chunk incompleti!
}
```

#### Problema Specifico

- Memory leak potenziale con 7 packetId possibili
- Chunk orfani dopo errori di trasmissione
- Nessuna pulizia periodica

#### Soluzione Proposta

Aggiungere timestamp e cleanup timer:

```csharp
private readonly Dictionary<int, (List<byte> Data, long TimestampTicks)> _chunkQueues = new();
private const long CHUNK_TIMEOUT_TICKS = TimeSpan.TicksPerSecond; // 1 secondo

// Nel loop, dopo accumulo:
CleanupTimedOutChunks();

private void CleanupTimedOutChunks()
{
    var now = DateTime.UtcNow.Ticks;
    lock (_chunkLock)
    {
        var timedOut = _chunkQueues
            .Where(kv => now - kv.Value.TimestampTicks > CHUNK_TIMEOUT_TICKS)
            .Select(kv => kv.Key)
            .ToList();
        
        foreach (var packetId in timedOut)
        {
            _logger?.LogWarning("Chunk timeout for packetId={PacketId}", packetId);
            _chunkQueues.Remove(packetId);
        }
    }
}
```

#### Benefici Attesi

- Nessun memory leak
- Chunk orfani rimossi automaticamente
- Logging per debug

---

## Priorità Bassa

### CAN-007 – Polling Busy-Wait in ReceiveAsync

**Categoria:** Performance  
**Priorità:** Bassa  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-02-03

#### Descrizione

`ReceiveAsync` usa polling con `Task.Delay(1)` quando la coda è vuota.

#### File Coinvolti

- `Drivers.Can\Hardware\Pcan\PcanHardware.cs` (righe 170-255)

#### Snippet Problematico

```csharp
if (status == PcanStatus.ReceiveQueueEmpty)
{
    await Task.Delay(1, cancellationToken);  // Polling 1ms
    continue;
}
```

#### Soluzione Proposta

Usare eventi PCAN nativi o Channel<T> con background receiver.

---

### CAN-009 – Magic Strings per Device Path

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-03

#### Descrizione

Device path come "PCAN_USBBUS1" sono magic strings sparse nel codice.

#### File Coinvolti

- `Drivers.Can\CanChannelDriver.cs` (riga 541)
- `Drivers.Can\Hardware\Pcan\PcanHardware.cs` (righe 314-324)

#### Soluzione Proposta

Creare classe `PcanDevicePaths` con costanti.

---

### CAN-016 – Allocazione in ExtractChunkData

**Categoria:** Performance  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-06

#### Descrizione

`NetInfoHelper.ExtractChunkData` alloca un nuovo `byte[]` per ogni chunk ricevuto.

#### File Coinvolti

- `Drivers.Can\Helpers\NetInfoHelper.cs` (righe 170-185)

#### Snippet Problematico

```csharp
public static byte[] ExtractChunkData(byte[] canFrameData)
{
    var chunkData = new byte[canFrameData.Length - NET_INFO_SIZE];  // Allocazione
    Array.Copy(canFrameData, NET_INFO_SIZE, chunkData, 0, chunkData.Length);
    return chunkData;
}
```

#### Soluzione Proposta

Fornire overload con `Span<byte>`:

```csharp
public static ReadOnlySpan<byte> ExtractChunkData(ReadOnlySpan<byte> canFrameData)
    => canFrameData[NET_INFO_SIZE..];
```

---

## Security

### CAN-012 – Logging di Device Path Senza Sanitization

**Categoria:** Security  
**Priorità:** Security  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-03

#### Descrizione

Device path vengono loggati direttamente senza sanitization.

#### File Coinvolti

- `Drivers.Can\CanChannelDriver.cs` (righe 82-85)
- `Drivers.Can\Hardware\Pcan\PcanHardware.cs` (righe 51-54)

#### Soluzione Proposta

Sanitizzare input prima del logging con filtro caratteri.

---

### CAN-019 – FilterMask Non Validata in CanConfiguration

**Categoria:** Security  
**Priorità:** Security  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-06

#### Descrizione

`CanConfiguration.Validate()` valida baudrate e timeout, ma non valida che `FilterMask` sia un valore sensato (es. non 0 se `FilterId` è impostato).

#### File Coinvolti

- `Drivers.Can\CanConfiguration.cs` (righe 68-78)

#### Snippet Problematico

```csharp
public void Validate()
{
    if (Baudrate == 0 || Baudrate > 1_000_000)
        throw new ArgumentException(...);
    if (OperationTimeout <= TimeSpan.Zero)
        throw new ArgumentException(...);
    // FilterMask non validata!
}
```

#### Soluzione Proposta

Aggiungere validazione:

```csharp
if (FilterId.HasValue && FilterMask == 0)
    throw new ArgumentException("FilterMask cannot be 0 when FilterId is set");
```

---

## Issue Risolte

### CAN-011 – XML Comments Incompleti

**Categoria:** Documentation  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** ✅ Risolto  
**Data Apertura:** 2026-02-03  
**Data Risoluzione:** 2026-02-12  
**Branch:** fix/t-018

#### Descrizione

Alcune eccezioni (`CanBusOffException`, `CanBufferOverrunException`) mancavano di XML docs dettagliati.

#### Soluzione Implementata

Tutti i file in Drivers.Can sono stati allineati allo standard `STANDARD_COMMENTS.md` v1.1:
- XML docs completi per tutte le classi pubbliche
- Regole R-005 (param minuscola) e R-006 (returns bool) applicate
- Parte dell'operazione globale T-018

#### File Modificati

- `Drivers.Can/CanChannelDriver.cs`
- `Drivers.Can/Hardware/ICanHardware.cs`
- `Drivers.Can/Helpers/NetInfoHelper.cs`
- `Drivers.Can/Hardware/CanHardwareException.cs`

---

### CAN-010 – Naming Convention Inconsistente

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** ✅ Risolto  
**Data Apertura:** 2026-02-03  
**Data Risoluzione:** 2026-02-11
**Branch:** `docs/aggiorna-issues-2026-02-11`

#### Descrizione

Metodi privati usavano camelCase invece di PascalCase.

#### Soluzione Implementata

I metodi in `PcanHardware.cs` ora usano PascalCase corretto:
- `ConvertDevicePathToChannel()` (linea 371)
- `ConvertBaudrateToBitrate()` (linea 388)

#### Benefici Ottenuti

- Naming convention C# standard rispettata
- Consistenza con il resto della codebase

---

### CAN-001 – Blocking Call in Async Method (Disconnect/Dispose)

**Categoria:** Anti-Pattern  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-02-01  
**Data Risoluzione:** 2026-02-02  
**Branch:** `fix/can-001`

#### Descrizione

I metodi `Disconnect()` e `Dispose()` usavano `.GetAwaiter().GetResult()` causando deadlock.

#### Soluzione Implementata

- Aggiunto `DisconnectAsync()` a `IChannelDriver`
- Implementato `IAsyncDisposable` in `CanChannelDriver` e `PcanHardware`
- Rimosso metodo `Disconnect()` sincrono

#### Test Aggiunti

7 nuovi test per async dispose pattern.

#### Benefici Ottenuti

- Eliminato rischio deadlock
- Pattern moderno `await using` supportato

---

### CAN-002 – Extended ID Hardcoded a Zero in WriteAsync

**Categoria:** Bug  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-02-01  
**Data Risoluzione:** 2026-02-02  
**Branch:** `fix/can-002`

#### Descrizione

Extended ID del frame CAN era sempre 0, impedendo routing STEM.

#### Soluzione Implementata

- Aggiunto overload `WriteAsync(byte[], ChannelMetadata?, CancellationToken)`
- Estrazione ExtendedId da `ChannelMetadata.DestinationAddress`

#### Test Aggiunti

14 nuovi test.

#### Benefici Ottenuti

- Routing STEM corretto
- Compatibilità con firmware C

---

### CAN-008 – Missing IAsyncDisposable

**Categoria:** Design  
**Priorità:** Media  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-02-01  
**Data Risoluzione:** 2026-02-02  
**Branch:** `fix/can-001`

#### Descrizione

Risolto come parte di CAN-001.

---

### CAN-013 – BusWarning Trattato Come Errore Fatale in ReceiveAsync

**Categoria:** Bug  
**Priorità:** Media  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-02-02  
**Data Risoluzione:** 2026-02-02  
**Branch:** `feature/app-client`

#### Descrizione

`PcanHardware.ReceiveAsync()` lanciava eccezione su `BusWarning`.

#### Soluzione Implementata

- BusWarning gestito come warning con log throttled
- Backoff 100ms durante BusWarning
- Eccezioni solo per BusOff/BusPassive

#### Benefici Ottenuti

- Sviluppo possibile con solo PCAN-USB
- Nessun log spam

---

### CAN-014 – Riassemblaggio Chunk Basato su NetInfo Mancante

**Categoria:** Bug / Architecture  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** ? Risolto  
**Data Apertura:** 2026-02-02  
**Data Risoluzione:** 2026-02-02  
**Branch:** `fix/t-008`

#### Descrizione

`ReadAsync` riassemblava frame basandosi su Extended ID, incompatibile con protocollo STEM.

#### Soluzione Implementata

- Creato `NetInfoHelper` per encode/decode NetInfo
- Riscritto `CanChannelDriver.ReadAsync()` con riassemblaggio basato su NetInfo

#### Test Aggiunti

26 test per NetInfoHelper.

#### Benefici Ottenuti

- Compatibilità protocollo STEM originale
- Riassemblaggio robusto

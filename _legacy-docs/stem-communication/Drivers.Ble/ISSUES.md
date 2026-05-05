# Drivers.Ble - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunita di refactoring e violazioni di best practice per il componente **Drivers.Ble**.

> **Ultimo aggiornamento:** 2026-02-26

---

## Riepilogo

| Priorita | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 2 |
| **Alta** | 0 | 4 |
| **Media** | 1 | 8 |
| **Bassa** | 2 | 3 |

**Totale aperte:** 3  
**Totale risolte:** 17 *(include 1 Wontfix)*

> **Nota:** Le feature request sono tracciate in [FEATURES.md](../FEATURES.md)

---

## Issue Trasversali Correlate

| ID | Titolo | Status | Impatto su Drivers.Ble |
|----|--------|--------|------------------------|
| **T-014** | Unificazione NetInfoCodec tra Driver | Aperto | `BleFramingHelper` userà codec condiviso |
| **T-015** | Architettura Chunking Driver vs TransportLayer | Aperto | Impatto su `OptimalChunkSize` e MTU handling |
| **T-009** | Header BLE Mancante (NetInfo + RecipientId) | ✅ Risolto | Implementato `BleFramingHelper` per wrap/unwrap |

→ [Protocol/ISSUES.md](../Protocol/ISSUES.md) per dettagli completi.

---

## Indice Issue Aperte

- [BLE-012 - Logging di Dati Sensibili](#ble-012--logging-di-dati-sensibili)
- [BLE-018 - Volatile.Read Mancante in Event Handlers](#ble-018--volatileread-mancante-in-event-handlers)
- [BLE-019 - Chunking MTU che Spezza Header BLE](#ble-019--chunking-mtu-che-spezza-header-ble)

---

## Indice Issue Risolte/Chiuse

- [BLE-020 - Supporto Windows Desktop Nativo (Multi-Targeting)](#ble-020--supporto-windows-desktop-nativo-multi-targeting)
- [BLE-011 - XML Comments Mancanti](#ble-011--xml-comments-mancanti)
- [BLE-009 - Magic Numbers in AutoReconnect](#ble-009--magic-numbers-in-autoreconnect)
- [BLE-007 - Config.Validate() Chiamato in ConnectAsync](#ble-007--configvalidate-chiamato-in-connectasync)
- [BLE-008 - InterChunkDelay Non Validato](#ble-008--interchunkdelay-non-validato)
- [BLE-015 - Nessun Timeout su ReadAsync](#ble-015--nessun-timeout-su-readasync)
- [BLE-010 - BleChannelDriver Non Dichiara IAsyncDisposable](#ble-010--blechanneldriver-non-dichiara-iasyncdisposable) *(Wontfix)*
- [BLE-017 - Adottare ChunkDataAsMemory e Rimuovere ChunkData](#ble-017--adottare-chunkdataasmemory-e-rimuovere-chunkdata)
- [BLE-005 - Allocazione Array in ChunkData()](#ble-005--allocazione-array-in-chunkdata)
- [BLE-006 - MTU Massimo Non Validato](#ble-006--mtu-massimo-non-validato)
- [BLE-003 - Memory Leak nel Buffer di Ricezione](#ble-003--memory-leak-nel-buffer-di-ricezione)
- [BLE-004 - ClearReceiveBuffer() usa Semaphore.Wait(0)](#ble-004--clearreceivebuffer-usa-semaphorewait0)
- [BLE-014 - Race Condition in OnDataReceived durante Dispose](#ble-014--race-condition-in-ondatareceived-durante-dispose)
- [BLE-002 - Fire-and-Forget Task Senza Error Handling](#ble-002--fire-and-forget-task-senza-error-handling)
- [BLE-001 - Blocking Call in Dispose()](#ble-001--blocking-call-in-dispose)
- [BLE-013 - Manca Reassembly dei Chunk in Ricezione](#ble-013--manca-reassembly-dei-chunk-in-ricezione)
- [BLE-016 - Doppio Chunking TX/RX](#ble-016--doppio-chunking-txrx)

---

## Priorita Alta

(Nessuna issue alta priorità aperta)

---

## Priorita Media

### BLE-012 - Logging di Dati Sensibili

**Categoria:** Security  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-03  
**Ultimo Aggiornamento:** 2026-02-10

#### Descrizione

I log includono dati potenzialmente sensibili in più punti:

1. **MAC address e nomi dispositivi** (livello Information): loggati senza sanitizzazione
2. **Dati TX/RX raw** (livello Trace): payload completi loggati in formato hex

#### File Coinvolti

- `Drivers.Ble\BleChannelDriver.cs` (righe 96-99)
- `Drivers.Ble\Hardware\PluginBle\PluginBleHardware.cs` (righe 169-172, 182, 314, 561)

#### Codice Problematico

**1. MAC address e nomi (Information level):**
```csharp
// BleChannelDriver.cs riga 96-99
_logger?.LogInformation(
    "Connecting to BLE: DeviceFilter={Filter}, MAC={Mac}",
    _config.DeviceNameFilter ?? "(any)",
    _config.DeviceMacAddress ?? "(any)");  // MAC address loggato

// PluginBleHardware.cs riga 169-172
_logger?.LogInformation(
    "Scanning for BLE device: NameFilter={NameFilter}, MAC={Mac}",
    config.DeviceNameFilter ?? "(any)",
    config.DeviceMacAddress ?? "(any)");  // MAC address loggato

// PluginBleHardware.cs riga 182
_logger?.LogInformation("Found device: {Name} ({Id})", device.Name, device.Id);  // Device ID loggato
```

**2. Dati TX/RX raw (Trace level):**
```csharp
// PluginBleHardware.cs riga 314
_logger?.LogTrace("TX data: {HexData}", BitConverter.ToString(dataArray));

// PluginBleHardware.cs riga 561
_logger?.LogTrace("RX data: {HexData}", BitConverter.ToString(data));
```

#### Soluzione Proposta

**Per MAC/nomi (opzione 1 - sanitizzazione):**
```csharp
_logger?.LogInformation(
    "Connecting to BLE: hasDeviceFilter={HasFilter}, hasMacFilter={HasMac}",
    !string.IsNullOrEmpty(_config.DeviceNameFilter),
    !string.IsNullOrEmpty(_config.DeviceMacAddress));
```

**Per dati TX/RX (opzione 2 - troncamento):**
```csharp
// Logga solo i primi N bytes
var preview = data.Length > 16 
    ? BitConverter.ToString(data, 0, 16) + "..." 
    : BitConverter.ToString(data);
_logger?.LogTrace("TX data ({Length} bytes): {Preview}", data.Length, preview);
```

**Alternativa:** Aggiungere flag `LogSensitiveData` in configurazione (default: false).

#### Rischio

- A livello **Information**: MAC address e device ID potrebbero violare GDPR
- A livello **Trace**: accettabile in dev, ma problematico se abilitato in produzione

#### Benefici Attesi

- Nessun dato sensibile nei log di produzione
- Compliance privacy (GDPR)
- Debug ancora possibile con flag esplicito

---

### BLE-018 - Volatile.Read Mancante in Event Handlers

**Categoria:** Bug  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-10  
**Ultimo Aggiornamento:** 2026-02-11

#### Descrizione

Alcuni metodi controllano `_disposed` senza usare `Volatile.Read`, a differenza di `OnDataReceived()` che usa il pattern corretto. Questa inconsistenza può causare lettura di valori stale in scenari multi-thread.

#### File Coinvolti

- `Drivers.Ble\BleChannelDriver.cs`

#### Codice Problematico

```csharp
// Riga 517 - OnDisconnected - PROBLEMATICO
private void OnDisconnected(object? sender, BleDisconnectedEventArgs e)
{
    if (_disposed) return;  // ← Manca Volatile.Read!
    // ...
}

// Riga 568 - AutoReconnectLoopAsync - PROBLEMATICO
if (_disposed)
    return;  // ← Manca Volatile.Read!
```

#### Confronto con Pattern Corretto

```csharp
// Riga 436 - OnDataReceived - CORRETTO
private void OnDataReceived(object? sender, BleDataReceivedEventArgs e)
{
    if (Volatile.Read(ref _disposed)) return;  // ✓ Lettura atomica
    // ...
}
```

#### Soluzione Proposta

Uniformare il pattern in tutti i punti:

```csharp
private void OnDisconnected(object? sender, BleDisconnectedEventArgs e)
{
    if (Volatile.Read(ref _disposed)) return;
    // ...
}

// In AutoReconnectLoopAsync:
if (Volatile.Read(ref _disposed))
    return;
```

#### Benefici Attesi

- Consistenza con pattern T-005 (thread safety)
- Nessun rischio di stale read
- Codice uniforme

---

### BLE-019 - Chunking MTU che Spezza Header BLE

**Categoria:** Bug / Enhancement  
**Priorita:** Media  
**Impatto:** Medio - 10 test skippati, scenari edge-case non gestiti  
**Status:** Aperto  
**Data Apertura:** 2026-02-11

#### Descrizione

Con l'implementazione di T-009 (`BleFramingHelper`), l'unwrap dell'header BLE avviene **ad ogni notifica BLE ricevuta**. Questo funziona quando ogni notifica contiene un frame completo, ma fallisce se il chunking MTU spezza l'header BLE (6 bytes) tra due notifiche.

**Scenario problematico:**
```
Frame BLE completo: [NetInfo(2)][Address(4)][Payload(N)] = 100 bytes
MTU = 50 bytes

Notifica 1: [NetInfo(2)][Address(4)][Payload(44)] = 50 bytes - OK, unwrap funziona
Notifica 2: [Payload(50)] = 50 bytes - FAIL! Non ha header, unwrap fallisce
```

**Scenario peggiore:**
```
MTU = 5 bytes (edge case estremo)

Notifica 1: [NetInfo(2)][Addr_parte1(3)] = 5 bytes - FAIL! Header incompleto
Notifica 2: [Addr_parte2(1)][Payload(4)] = 5 bytes
...
```

#### Test Skippati

10 test sono stati skippati con il messaggio:
> "T-009: Il chunking MTU che spezza l'header BLE richiede accumulo buffer PRIMA dell'unwrap"

| File | Test |
|------|------|
| `BleChannelDriverTests.cs` | `ReadAsync_WithReassemblyEnabled_ShouldReassembleChunks` |
| `BleChannelDriverTests.cs` | `ReadAsync_WithReassemblyEnabled_MultipleFrames_ShouldDeliverInOrder` |
| `BleChannelDriverTests.cs` | `ReadAsync_WithReassemblyEnabled_LargeFrame_ShouldReassemble` |
| `BleReassemblyIntegrationTests.cs` | `ProcessUpstream_FrameInTwoChunks_ShouldReassembleCorrectly` |
| `BleReassemblyIntegrationTests.cs` | `ProcessUpstream_FrameInManySmallChunks_ShouldReassembleCorrectly` |
| `BleReassemblyIntegrationTests.cs` | `ProcessUpstream_TwoFramesConcatenated_ShouldDeliverBothInOrder` |
| `BleReassemblyIntegrationTests.cs` | `ProcessUpstream_InterleavedChunks_ShouldReassembleCorrectly` |
| `BleReassemblyIntegrationTests.cs` | `ProcessUpstream_LargeFrameInMtuChunks_ShouldReassembleCorrectly` |
| `BleReassemblyIntegrationTests.cs` | `ProcessUpstream_LargeFrameInMinimumMtuChunks_ShouldReassembleCorrectly` |
| `BleReassemblyIntegrationTests.cs` | `ProcessUpstream_ReassembledFrame_ShouldRecordTotalBytesReceived` |

#### Soluzione Proposta

Modificare `OnDataReceived()` per accumulare i bytes **prima** di fare l'unwrap:

```csharp
private readonly MemoryStream _rawBuffer = new();

private void OnDataReceived(object? sender, BleDataReceivedEventArgs e)
{
    // 1. Accumula bytes grezzi
    _rawBuffer.Write(e.Data);
    
    // 2. Prova a estrarre frame completi
    while (TryExtractBleFrame(out var bleFrame))
    {
        // 3. Ora fai unwrap (header garantito completo)
        var unwrapped = BleFramingHelper.UnwrapReceived(bleFrame);
        
        // 4. Passa al reassembly o alla queue
        ProcessUnwrappedFrame(unwrapped);
    }
}
```

#### Impatto su Altri Componenti

- `BleReassemblyBuffer` potrebbe diventare obsoleto (accumulazione gia' nel driver)
- Oppure: rinominare in `BleRawBuffer` e usarlo per accumulo pre-unwrap

#### Effort Stimato

**Media** (4-8h) - Richiede refactoring del flusso RX nel driver.

#### Benefici Attesi

- Gestione corretta di tutti gli scenari MTU
- 10 test riabilitati
- Robustezza migliorata per MTU piccoli

---

## Issue Risolte

### BLE-011 - XML Comments Mancanti

**Categoria:** Documentation  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** ✅ Risolto  
**Data Apertura:** 2026-02-03  
**Data Risoluzione:** 2026-02-11
**Branch:** `docs/aggiorna-issues-2026-02-11`

#### Descrizione

Alcuni metodi privati e helper mancavano di XML comments.

#### Soluzione Implementata

Aggiunti XML comments ai metodi privati principali in `BleChannelDriver.cs`:
- `ExtractRecipientId()` - documenta estrazione RecipientId da metadata
- `ExtractPacketId()` - documenta estrazione PacketId da metadata
- `OnDataReceived()` - documenta logica di unwrap T-009
- `WriteChunkedAsync()` - documenta chunking MTU

#### Benefici Ottenuti

- Migliore documentazione interna
- IntelliSense più informativo

---

### BLE-009 - Magic Numbers in AutoReconnect

**Categoria:** Code Smell  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-02-03  
**Data Risoluzione:** 2026-02-11  
**Branch:** `fix/pl-016`

#### Descrizione

Il metodo `AutoReconnectLoopAsync()` conteneva due magic numbers hardcoded:
- `maxAttempts = 5`
- `maxBackoffDelay = 30000`

#### Soluzione Implementata

Aggiunte costanti in `BleDriverConstants`:

```csharp
/// <summary>Numero massimo di tentativi di riconnessione automatica.</summary>
public const int DEFAULT_AUTO_RECONNECT_MAX_ATTEMPTS = 5;

/// <summary>Delay massimo (ms) per exponential backoff durante riconnessione.</summary>
public const int MAX_RECONNECT_BACKOFF_MS = 30_000;
```

Aggiornato il codice in `BleChannelDriver.AutoReconnectLoopAsync()`:

```csharp
var maxAttempts = BleDriverConstants.DEFAULT_AUTO_RECONNECT_MAX_ATTEMPTS;

delay = TimeSpan.FromMilliseconds(
    Math.Min(delay.TotalMilliseconds * 2, BleDriverConstants.MAX_RECONNECT_BACKOFF_MS));
```

#### File Modificati

- `Drivers.Ble\BleDriverConstants.cs` (aggiunte costanti)
- `Drivers.Ble\BleChannelDriver.cs` (usa costanti)

#### Benefici Ottenuti

- Nessun magic number nel codice
- Costanti centralizzate e documentate
- Pattern T-011 rispettato

---

### BLE-007 - Config.Validate() Chiamato in ConnectAsync

**Categoria:** Design  
**Priorita:** Media  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-02-03  
**Data Risoluzione:** 2026-02-10  
**Branch:** `fix/ble-007`

#### Descrizione

La validazione della configurazione avveniva in `ConnectAsync()` invece che nel costruttore, permettendo istanze invalide in memoria.

#### Soluzione Implementata

Spostata la chiamata `config.Validate()` dal metodo `ConnectAsync()` al costruttore:

```csharp
public BleChannelDriver(IBleHardware hardware, BleConfiguration config, ILogger<BleChannelDriver>? logger = null)
{
    _hardware = hardware ?? throw new ArgumentNullException(nameof(hardware));
    _config = config ?? throw new ArgumentNullException(nameof(config));
    _logger = logger;

    // Fail-fast: valida configurazione nel costruttore (BLE-007)
    config.Validate();

    // resto inizializzazione...
}
```

#### File Modificati

- `Drivers.Ble\BleChannelDriver.cs` (costruttore + `ConnectAsync`)

#### Test Aggiunti

**BleChannelDriverTests.cs (2 test):**
- `Constructor_WithInvalidConfig_ShouldThrowArgumentException` - verifica che config senza identificativo dispositivo lanci eccezione
- `Constructor_WithNegativeInterChunkDelay_ShouldThrowArgumentException` - verifica che InterChunkDelay negativo lanci eccezione

#### Benefici Ottenuti

- Fail-fast pattern: nessuna istanza invalida può esistere in memoria
- Errori di configurazione rilevati immediatamente alla creazione
- Comportamento più predicibile

---

### BLE-008 - InterChunkDelay Non Validato

**Categoria:** Bug  
**Priorita:** Media  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-02-03  
**Data Risoluzione:** 2026-02-10  
**Branch:** `fix/ble-008`

#### Descrizione

`BleConfiguration.InterChunkDelay` poteva essere negativo o eccessivamente lungo senza validazione, causando comportamenti imprevedibili nel chunking BLE.

#### Soluzione Implementata

Aggiunta costante e validazione in `Validate()`:

```csharp
// Costante
public const int MAX_INTER_CHUNK_DELAY_MS = 500;

// Validazione InterChunkDelay (BLE-008)
if (InterChunkDelay < TimeSpan.Zero)
    throw new ArgumentException($"InterChunkDelay cannot be negative. Got: {InterChunkDelay}");

if (InterChunkDelay.TotalMilliseconds > MAX_INTER_CHUNK_DELAY_MS)
    throw new ArgumentException(
        $"InterChunkDelay cannot exceed {MAX_INTER_CHUNK_DELAY_MS}ms. Got: {InterChunkDelay.TotalMilliseconds}ms");
```

**Range valido:** 0 - 500 ms
- `TimeSpan.Zero` è valido (nessun delay tra chunk)
- Massimo 500ms per evitare timeout eccessivi

#### File Modificati

- `Drivers.Ble\BleConfiguration.cs` (costante + metodo `Validate()`)

#### Test Aggiunti

**BleConfigurationTests.cs (5 test):**
- `Validate_WhenInterChunkDelayIsNegative_ShouldThrowArgumentException` - Theory con 3 casi (-1, -10, -1000 ms)
- `Validate_WhenInterChunkDelayInValidRange_ShouldNotThrow` - Theory con 7 casi (0, 1, 10, 50, 100, 500 ms)
- `Validate_WhenInterChunkDelayExceedsMaximum_ShouldThrowArgumentException` - Theory con 3 casi (501, 1000, 5000 ms)
- `InterChunkDelay_ShouldHaveCorrectDefaultValue` - verifica default 10ms
- `MaxInterChunkDelayConstant_ShouldBe500` - verifica costante

#### Benefici Ottenuti

- Fail-fast su valori invalidi
- Comportamento predicibile
- Messaggio di errore chiaro

---

### BLE-015 - Nessun Timeout su ReadAsync

**Categoria:** Design  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-02-03  
**Data Risoluzione:** 2026-02-10  
**Branch:** `fix/ble-015`

#### Descrizione

`ReadAsync()` poteva bloccarsi indefinitamente se l'evento `DataReceived` non veniva mai sollevato e il chiamante non forniva un `CancellationToken` con timeout.

#### Soluzione Implementata

Aggiunto timeout interno basato su `BleConfiguration.OperationTimeout` (default: 5 secondi) usando `CancellationTokenSource.CreateLinkedTokenSource`:

```csharp
public async Task<byte[]?> ReadAsync(CancellationToken cancellationToken = default)
{
    ThrowIfDisposed();

    try
    {
        // Combina il token del chiamante con il timeout configurato (BLE-015)
        using var timeoutCts = new CancellationTokenSource(_config.OperationTimeout);
        using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(
            cancellationToken, timeoutCts.Token);

        // Attende dati nel channel (bounded, previene memory leak - BLE-003)
        var data = await _receiveChannel.Reader.ReadAsync(linkedCts.Token);

        _statistics.RecordBytesReceived(data.Length);
        return data;
    }
    catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
    {
        // Timeout interno scaduto (non cancellazione esterna)
        return null;
    }
    catch (OperationCanceledException)
    {
        // Cancellazione esterna richiesta dal chiamante
        return null;
    }
    catch (ChannelClosedException)
    {
        return null;
    }
}
```

**Comportamento:**
- Se il chiamante passa un `CancellationToken`, rispetta anche quello (il più veloce vince)
- Se il timeout interno scade, ritorna `null` senza eccezioni
- Se la cancellazione esterna scade, ritorna `null` senza eccezioni
- Entrambi i `CancellationTokenSource` vengono disposti correttamente

#### File Modificati

- `Drivers.Ble\BleChannelDriver.cs` (metodo `ReadAsync`)

#### Test Aggiunti

**BleChannelDriverTests.cs (3 test):**
- `ReadAsync_WhenNoDataAndTimeoutExpires_ShouldReturnNull` - verifica che scaduto il timeout interno ritorna null
- `ReadAsync_WhenDataArrivesBeforeTimeout_ShouldReturnData` - verifica che dati arrivati prima del timeout vengono restituiti
- `ReadAsync_WhenExternalCancellationOccurs_ShouldReturnNull` - verifica che cancellazione esterna ritorna null

#### Benefici Ottenuti

- Nessun hang indefinito: `ReadAsync()` ritorna sempre entro `OperationTimeout`
- Comportamento predicibile e testabile
- Retrocompatibile: chiamanti esistenti con CancellationToken continuano a funzionare

---

### BLE-010 - BleChannelDriver Non Dichiara IAsyncDisposable

**Categoria:** Design  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Wontfix  
**Data Apertura:** 2026-02-03  
**Data Chiusura:** 2026-02-09

#### Descrizione

`BleChannelDriver` implementa `IAsyncDisposable` ma non lo dichiara nella class signature.

#### Motivo Wontfix

**Non è un problema.** `IAsyncDisposable` è già ereditato tramite `IChannelDriver`:

```csharp
public interface IChannelDriver : IAsyncDisposable { ... }

public sealed class BleChannelDriver : IChannelDriver, IDisposable
// IAsyncDisposable è già incluso via IChannelDriver
```

Il pattern `await using` funziona correttamente senza dichiarazione esplicita.

#### Issue Correlata

Tuttavia, `IChannelDriver` dovrebbe ereditare anche `IDisposable` per uniformità.  
→ Vedi **INF-005** in `Protocol/Infrastructure/ISSUES.md`

---

### BLE-017 - Adottare ChunkDataAsMemory e Rimuovere ChunkData

**Categoria:** Performance / Refactoring  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-02-10  
**Data Risoluzione:** 2026-02-10  
**Branch:** `fix/ble-017`

#### Descrizione

Con l'aggiunta di `ChunkDataAsMemory()` (BLE-005), esisteva un metodo zero-allocation per il chunking che non poteva essere utilizzato perché `IBleHardware.WriteAsync()` accettava solo `byte[]`.

#### Soluzione Implementata

**Tutte e 4 le fasi completate:**

**Fase 1:** Aggiunto overload `WriteAsync(ReadOnlyMemory<byte>)` a `IBleHardware`:
```csharp
Task WriteAsync(ReadOnlyMemory<byte> data, CancellationToken cancellationToken = default);
```

**Fase 2:** Implementato in `PluginBleHardware` con ottimizzazione:
```csharp
public async Task WriteAsync(ReadOnlyMemory<byte> data, CancellationToken ct = default)
{
    // Ottimizzazione: se il Memory è backed da un array completo, usalo direttamente
    byte[] dataArray;
    if (MemoryMarshal.TryGetArray(data, out ArraySegment<byte> segment)
        && segment.Offset == 0
        && segment.Count == segment.Array!.Length)
    {
        dataArray = segment.Array;  // Zero-copy!
    }
    else
    {
        dataArray = data.ToArray();  // Fallback: crea copia
    }
    await _txCharacteristic.WriteAsync(dataArray, ct);
}
```

**Fase 3:** Aggiornato `BleChannelDriver.WriteChunkedAsync()`:
```csharp
private async Task WriteChunkedAsync(byte[] data, int mtu, CancellationToken cancellationToken)
{
    var chunkCount = BleMtuHelper.CalculateChunkCount(data.Length, mtu);
    foreach (var chunk in BleMtuHelper.ChunkDataAsMemory(data, mtu))
    {
        await _hardware.WriteAsync(chunk, cancellationToken);
        _statistics.RecordBytesSent(chunk.Length);
    }
}
```

**Fase 4:** Consolidamento API:
- Rimosso `ChunkData()` deprecato da `BleMtuHelper.cs`
- Rimosso overload `WriteAsync(byte[])` da `IBleHardware` (usa solo `ReadOnlyMemory<byte>`)
- Rimossi 20 test obsoleti da `BleMtuHelperTests.cs`
- Aggiornati tutti i mock nei test per usare `ReadOnlyMemory<byte>`

#### Test Aggiornati

- Aggiornati mock per usare `WriteAsync(ReadOnlyMemory<byte>)` in:
  - `BleChannelDriverTests.WriteAsync_WhenDataRequiresChunking_ShouldWriteMultipleChunks`
  - `BleDriverPhysicalIntegrationTests.ProcessDownstream_WithDataLargerThanMtuPayload_ShouldChunkCorrectly`
  - `BleDriverPhysicalIntegrationTests.ProcessDownstream_ChunkedData_ShouldPreserveDataIntegrity`
  - `BleDriverPhysicalIntegrationTests.ProcessDownstream_WithMinimumMtu_ShouldChunkInSmallPieces`

#### Nota sulle Prestazioni

L'ottimizzazione `MemoryMarshal.TryGetArray()` permette zero-copy quando:
- Il chiamante passa un `byte[]` completo (conversione implicita)
- Il `BleChannelDriver` invia dati non-chunkati (fit in single packet)

Il chunking con `ChunkDataAsMemory()` produce slice, quindi richiede `ToArray()`. Ma il beneficio è che:
- Non si allocano array intermedi per i chunk nel driver
- L'allocazione avviene solo al momento della write hardware

#### Benefici Ottenuti

- API semplificata: un solo metodo `WriteAsync(ReadOnlyMemory<byte>)`
- Zero-copy per `byte[]` completi grazie a `MemoryMarshal.TryGetArray()`
- Zero allocazioni nel loop di chunking
- `byte[]` funziona ancora grazie a conversione implicita

---

### BLE-005 - Allocazione Array in ChunkData()

**Categoria:** Performance  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-02-03  
**Data Risoluzione:** 2026-02-09  
**Branch:** `fix/ble-005`

#### Descrizione

`BleMtuHelper.ChunkData()` allocava un nuovo `byte[]` per ogni chunk, causando GC pressure durante trasmissioni frequenti.

#### Soluzione Implementata

**Aggiunto metodo `ChunkDataAsMemory()` con zero-allocation slicing:**

```csharp
public static IEnumerable<ReadOnlyMemory<byte>> ChunkDataAsMemory(
    ReadOnlyMemory<byte> data, int negotiatedMtu)
{
    if (data.IsEmpty)
        yield break;

    var maxPayload = GetMaxPayloadSize(negotiatedMtu);

    for (int offset = 0; offset < data.Length; offset += maxPayload)
    {
        var chunkSize = Math.Min(maxPayload, data.Length - offset);
        yield return data.Slice(offset, chunkSize);
    }
}
```

**Note:**
- Il metodo originale `ChunkData()` è mantenuto per retrocompatibilità
- `ChunkDataAsMemory()` può essere usato quando l'hardware supporta `WriteAsync(ReadOnlyMemory<byte>)`
- I chunk sono slice della memoria originale, non copie

#### Test Aggiunti

**BleMtuHelperTests.cs (10 test):**
- `ChunkDataAsMemory_WithEmptyData_ShouldReturnEmptySequence`
- `ChunkDataAsMemory_WhenDataFitsInSingleChunk_ShouldReturnSingleChunk`
- `ChunkDataAsMemory_WhenDataRequiresMultipleChunks_ShouldReturnCorrectChunks`
- `ChunkDataAsMemory_ChunksShouldBeSlicesOfOriginalData`
- `ChunkDataAsMemory_ShouldReturnExpectedNumberOfChunks`
- `ChunkDataAsMemory_ShouldMatchChunkDataResults`
- `ChunkDataAsMemory_ShouldNotAllocateNewArrays`
- `ChunkDataAsMemory_WithMaximumMtu_ShouldWorkCorrectly`

#### Benefici Ottenuti

- Zero allocazioni heap nel hot path (quando usato con hardware compatibile)
- Riduzione GC pressure per trasmissioni frequenti
- API alternativa per scenari ad alte prestazioni

---

### BLE-006 - MTU Massimo Non Validato

**Categoria:** Bug  
**Priorita:** Media  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-02-03  
**Data Risoluzione:** 2026-02-09  
**Branch:** `fix/ble-005` (fix collaterale)

#### Descrizione

`BleMtuHelper.GetMaxPayloadSize()` non validava che `negotiatedMtu <= MAX_MTU (517)`.

#### Soluzione Implementata

Aggiunta validazione massimo:

```csharp
public static int GetMaxPayloadSize(int negotiatedMtu)
{
    ArgumentOutOfRangeException.ThrowIfLessThan(negotiatedMtu, MIN_MTU, nameof(negotiatedMtu));
    ArgumentOutOfRangeException.ThrowIfGreaterThan(negotiatedMtu, MAX_MTU, nameof(negotiatedMtu));
    return negotiatedMtu - ATT_HEADER_SIZE;
}
```

#### Test Aggiunti

**BleMtuHelperTests.cs (4 test):**
- `GetMaxPayloadSize_WhenMtuAboveMaximum_ShouldThrowArgumentOutOfRangeException` (3 casi)
- `GetMaxPayloadSize_AtMaximumMtu_ShouldReturn514`

#### Benefici Ottenuti

- Fail-fast su valori MTU invalidi
- Prevenzione comportamenti imprevedibili

---

### BLE-003 - Memory Leak nel Buffer di Ricezione

**Categoria:** Bug  
**Priorita:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-02-03  
**Data Risoluzione:** 2026-02-09  
**Branch:** `fix/ble-003`

#### Descrizione

Se `ReadAsync()` non viene chiamato regolarmente, i dati continuavano ad accumularsi in `_receiveBuffer` (ConcurrentQueue) senza limite, causando OutOfMemoryException.

#### Soluzione Implementata

**Sostituzione ConcurrentQueue + SemaphoreSlim con Channel bounded:**

- Rimosso `ConcurrentQueue<byte[]>` e `SemaphoreSlim`
- Aggiunto `Channel<byte[]>` con `BoundedChannelOptions`
- Policy `DropOldest` quando buffer pieno (con log warning)
- Configurazione `MaxReceiveBufferSize` in `BleConfiguration` (default: 100, range: 10-10000)
- Fix collaterale BLE-014: aggiunto `Volatile.Read` per check `_disposed` (T-005 conforme)

**Codice Implementato:**

```csharp
// BleConfiguration.cs
public const int DEFAULT_RECEIVE_BUFFER_SIZE = 100;
public const int MIN_RECEIVE_BUFFER_SIZE = 10;
public const int MAX_RECEIVE_BUFFER_SIZE = 10000;

public int MaxReceiveBufferSize { get; init; } = DEFAULT_RECEIVE_BUFFER_SIZE;

// BleChannelDriver.cs
private readonly Channel<byte[]> _receiveChannel;

public BleChannelDriver(IBleHardware hardware, BleConfiguration config, ...)
{
    _receiveChannel = Channel.CreateBounded<byte[]>(new BoundedChannelOptions(config.MaxReceiveBufferSize)
    {
        FullMode = BoundedChannelFullMode.DropOldest,
        SingleReader = true,
        SingleWriter = false
    });
}

private void OnDataReceived(object? sender, BleDataReceivedEventArgs e)
{
    if (Volatile.Read(ref _disposed)) return;  // Fix BLE-014
    
    if (!_receiveChannel.Writer.TryWrite(message))
    {
        _logger?.LogWarning("Receive channel full, dropping oldest message");
    }
}

public async Task<byte[]?> ReadAsync(CancellationToken cancellationToken)
{
    return await _receiveChannel.Reader.ReadAsync(cancellationToken);
}
```

#### Test Aggiunti

**BleConfigurationTests.cs (8 test):**
- `MaxReceiveBufferSize_ShouldHaveCorrectDefaultValue`
- `BufferSizeConstants_ShouldHaveCorrectValues`
- `Validate_WhenMaxReceiveBufferSizeInValidRange_ShouldNotThrow` (6 casi)
- `Validate_WhenMaxReceiveBufferSizeBelowMinimum_ShouldThrowArgumentException` (5 casi)
- `Validate_WhenMaxReceiveBufferSizeAboveMaximum_ShouldThrowArgumentException` (3 casi)
- `MaxReceiveBufferSize_WithExpression_ShouldCreateModifiedCopy`

**BleChannelDriverTests.cs (6 test):**
- `Constructor_WithCustomBufferSize_ShouldCreateChannelWithCorrectCapacity`
- `ReceiveChannel_WhenBufferFull_ShouldDropOldestMessages`
- `ReceiveChannel_WhenBufferNotFull_ShouldRetainAllMessages`
- `ReadAsync_AfterChannelClosed_ShouldReturnNull`
- `ReceiveChannel_WithReassembly_WhenBufferFull_ShouldDropOldestReassembledMessages`
- `ClearReceiveBuffer_ShouldDrainAllPendingMessages`

#### Benefici Ottenuti

- Limite massimo di memoria garantito (configurabile)
- Back-pressure con DropOldest policy
- Nessun rischio OOM
- Thread-safety migliorata con Volatile.Read (fix collaterale BLE-014)
- ClearReceiveBuffer semplificato (fix collaterale BLE-004)

---

### BLE-004 - ClearReceiveBuffer() usa Semaphore.Wait(0)

**Categoria:** Code Smell  
**Priorita:** Media  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-02-03  
**Data Risoluzione:** 2026-02-09  
**Branch:** `fix/ble-003` (fix collaterale)

#### Descrizione

Il metodo `ClearReceiveBuffer()` usava `_receiveSemaphore.Wait(0)` per drenare il semaphore, pattern non-standard.

#### Soluzione Implementata

Risolto come fix collaterale di BLE-003. Con la sostituzione di `ConcurrentQueue` + `SemaphoreSlim` con `Channel<byte[]>`, il metodo `ClearReceiveBuffer()` è stato semplificato:

```csharp
private void ClearReceiveBuffer()
{
    // Drain channel - leggi tutti i messaggi disponibili senza bloccare
    while (_receiveChannel.Reader.TryRead(out _)) { }
}
```

#### Benefici Ottenuti

- Pattern semplice e standard
- Nessun Semaphore.Wait(0) non-standard
- Codice più leggibile

---

### BLE-014 - Race Condition in OnDataReceived durante Dispose

**Categoria:** Bug  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-02-03  
**Data Risoluzione:** 2026-02-09  
**Branch:** `fix/ble-003` (fix collaterale)

#### Descrizione

Il check `if (_disposed) return;` in `OnDataReceived()` non era atomico. Event handler poteva leggere stale value di `_disposed`.

#### Soluzione Implementata

Risolto come fix collaterale di BLE-003. Aggiunto `Volatile.Read` per entrambi i check:

```csharp
private void OnDataReceived(object? sender, BleDataReceivedEventArgs e)
{
    if (Volatile.Read(ref _disposed)) return;  // Lettura atomica

    lock (_syncLock)
    {
        if (Volatile.Read(ref _disposed)) return;  // Double-check atomico
        // ...
    }
}
```

#### Benefici Ottenuti

- Lettura atomica garantita
- Thread-safety conforme pattern T-005

---

### BLE-002 - Fire-and-Forget Task Senza Error Handling

**Categoria:** Bug  
**Priorita:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-02-03  
**Data Risoluzione:** 2026-02-05  
**Branch:** `fix/ble-002`

#### Descrizione

Il metodo `StartAutoReconnect()` lanciava un Task con `_ = Task.Run(...)` senza gestire eccezioni non catturate, che potevano rimanere silenziose.

#### Soluzione Implementata

**Refactoring a metodo separato `AutoReconnectLoopAsync()`:**

- Estratto loop async in metodo dedicato per readability e testability
- Aggiunto try-catch stratificato:
  - **Livello esterno**: Cattura top-level `OperationCanceledException`, `ObjectDisposedException`, `Exception` generica
  - **Livello interno**: Cattura per ogni operazione (`Task.Delay`, `ConnectAsync`)
- Early exit checks espliciti: `_reconnectCts?.Token.IsCancellationRequested`, `_disposed`
- Fallback safe con `?? CancellationToken.None` per null-coalesce

**Codice Implementato:**

```csharp
private void StartAutoReconnect()
{
    if (_config.AutoReconnectInterval <= TimeSpan.Zero)
        return;

    _reconnectCts?.Cancel();
    _reconnectCts = new CancellationTokenSource();

    _ = Task.Run(AutoReconnectLoopAsync, _reconnectCts.Token);
}

private async Task AutoReconnectLoopAsync()
{
    try
    {
        var delay = _config.AutoReconnectInterval;
        var maxAttempts = 5;

        for (int attempt = 1; attempt <= maxAttempts; attempt++)
        {
            if (_reconnectCts?.Token.IsCancellationRequested ?? false)
                return;
            if (_disposed)
                return;

            try
            {
                await Task.Delay(delay, _reconnectCts?.Token ?? CancellationToken.None);
            }
            catch (OperationCanceledException) { return; }

            try
            {
                var success = await _hardware.ConnectAsync(_config, 
                    _reconnectCts?.Token ?? CancellationToken.None);
                if (success)
                {
                    _statistics.RecordReconnect();
                    return;
                }
            }
            catch (OperationCanceledException) { return; }
            catch (ObjectDisposedException) { return; }
            catch (Exception ex)
            {
                _logger?.LogWarning(ex, "Auto-reconnect attempt {Attempt} failed", attempt);
            }

            delay = TimeSpan.FromMilliseconds(Math.Min(delay.TotalMilliseconds * 2, 30000));
        }
    }
    catch (OperationCanceledException) { _logger?.LogDebug("Auto-reconnect loop cancelled"); }
    catch (ObjectDisposedException) { _logger?.LogDebug("Auto-reconnect: driver disposed"); }
    catch (Exception ex) { _logger?.LogError(ex, "Unexpected error in auto-reconnect loop"); }
}
```

#### Test Aggiunti

**Unit Tests - `BleChannelDriverTests.cs` (8 test):**
- `StartAutoReconnect_WhenAutoReconnectDisabledInConfig_ShouldNotStartLoop`
- `AutoReconnectLoopAsync_WhenConnectSucceedsOnFirstAttempt_ShouldExitImmediately`
- `AutoReconnectLoopAsync_WhenConnectFailsMultipleTimes_ShouldRetryWithExponentialBackoff`
- `AutoReconnectLoopAsync_WhenCancelledDuringDelay_ShouldExitGracefully`
- `AutoReconnectLoopAsync_WhenHardwareDisposed_ShouldCatchObjectDisposedExceptionGracefully`
- `AutoReconnectLoopAsync_WhenUnexpectedExceptionOccurs_ShouldLogAndExit`
- `OnDisconnected_WhenUnexpectedAndAutoReconnectEnabled_ShouldStartAutoReconnectLoop`
- `DisposeWhileAutoReconnecting_ShouldCancelLoopAndCleanup`

#### Benefici Ottenuti

- No unobserved exceptions
- Proper cancellation token handling
- Graceful disposal state management
- Granular logging per diagnostica
- Testable code structure

---

### BLE-013 - Manca Reassembly dei Chunk in Ricezione

**Categoria:** Bug  
**Priorita:** Critica  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-02-03  
**Data Risoluzione:** 2026-02-03  
**Branch:** `feature/ble-reassembly`

#### Descrizione

Il driver BLE implementava chunking TX ma non riassemblaggio RX, corrompendo messaggi > MTU.

#### Soluzione Implementata

- Creato `BleReassemblyBuffer` con parsing header DataLink
- Riassembly basato su campo `Length` (offset 5-6)
- Supporto chunking TX/RX simmetrico
- Configurazione `EnableReassembly` per retrocompatibilita

#### Test Aggiunti

- 28 test `BleReassemblyBufferTests`
- 4 test driver reassembly
- 12 test integration

#### Benefici Ottenuti

- Messaggi > MTU gestiti correttamente
- Pattern simmetrico TX/RX

---

### BLE-016 - Doppio Chunking TX/RX

**Categoria:** Design  
**Priorita:** Critica  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-02-03  
**Data Risoluzione:** 2026-02-03  
**Branch:** `feature/ble-reassembly`

#### Descrizione

Messaggio chunkato due volte: TransportLayer + BleDriver.

#### Soluzione Implementata

- TransportLayer opera in passthrough per BLE
- Chunking effettivo nel BleDriver basato su MTU

#### Benefici Ottenuti

- Nessun doppio chunking
- Chunking ottimale

---

### BLE-001 - Blocking Call in Dispose()

**Categoria:** Anti-Pattern  
**Priorita:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-02-02  
**Data Risoluzione:** 2026-02-02  
**Branch:** `fix/ble-001`

#### Descrizione

Il metodo `Dispose()` in `PluginBleHardware` chiamava `.Wait()` su un Task asincrono.

#### Soluzione Implementata

- Rimosso `.Wait()` bloccante da `Dispose()`
- Operazioni async delegate a `DisposeAsync()`
- `Dispose()` esegue solo cleanup sincrono

#### Benefici Ottenuti

- Eliminato rischio deadlock
- Pattern conforme .NET best practices

---

### BLE-020 - Supporto Windows Desktop Nativo (Multi-Targeting)

**Categoria:** Enhancement / Architecture  
**Priorità:** Alta  
**Impatto:** Alto - Abilita uso in applicazioni WinUI 3 / Windows desktop  
**Status:** Risolto  
**Data Apertura:** 2026-02-14  
**Data Risoluzione:** 2026-02-17  
**Branch:** `feature/ble-020`

#### Descrizione

Il driver BLE usava solo **Plugin.BLE**, limitato a mobile. Su Windows desktop (WPF, WinUI 3, Console) non funzionava.

#### Soluzione Implementata

1. **Multi-targeting** in `Drivers.Ble.csproj`: `net10.0` + `net10.0-windows10.0.19041.0`
2. **`IBleHardware` interface** per astrazione hardware
3. **`WindowsBleHardware`** per Windows Desktop (API native `Windows.Devices.Bluetooth`)
4. **`PluginBleHardware`** per Mobile (Plugin.BLE)
5. **`BleChannelDriverFactory`** con selezione automatica platform

#### File Creati/Modificati

| File | Azione |
|------|--------|
| `Drivers.Ble.csproj` | Multi-target |
| `Hardware/IBleHardware.cs` | Nuovo |
| `Hardware/Windows/WindowsBleHardware.cs` | Nuovo |
| `Hardware/PluginBle/PluginBleHardware.cs` | Modificato |
| `BleChannelDriverFactory.cs` | Modificato |

#### Test Aggiunti

- 16 test per `IBleHardware` contract
- 4 test per factory platform selection

#### Benefici Ottenuti

- **Un solo pacchetto NuGet** per tutte le piattaforme
- **Supporto WPF/WinUI 3/Console** su Windows
- **Zero configurazione** per l'utente
- **Architettura pulita** con hardware abstraction

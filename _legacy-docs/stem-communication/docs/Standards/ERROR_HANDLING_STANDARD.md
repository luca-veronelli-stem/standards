# Standard Error Handling - Gestione Errori nel Protocollo

> **Versione:** 1.6  
> **Data:** 2026-02-13  
> **Riferimento Issue:** T-012  
> **Stato:** Active

---

## Scopo

Questo standard definisce le regole per la gestione degli errori nel protocollo STEM, garantendo:
- **Consistenza** tra tutti i layer e componenti
- **Type-safety** eliminando stringhe hardcoded
- **Tracciabilita** per monitoring e logging centralizzato

Si applica a: tutti i layer del protocollo, driver e client.

---

## Principi Guida

1. **Result Types per errori attesi:** Usare `LayerResult` con errori tipizzati per condizioni prevedibili (CRC invalido, buffer troppo corto)
2. **Eccezioni per errori inattesi:** Usare eccezioni per bug, stati impossibili, violazioni di contratto
3. **Contesto completo:** Ogni errore deve includere layer, componente, codice univoco e timestamp
4. **Recuperabilita esplicita:** Indicare sempre se l'errore e recuperabile
5. **Gerarchia di eccezioni:** Le eccezioni specifiche devono derivare da una base comune

---

## Regole

### Scelta del Meccanismo

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| ERR-001 | ✅ DEVE | Usare `LayerResult` per errori attesi nel flusso normale |
| ERR-002 | ✅ DEVE | Usare eccezioni per errori inattesi, bug, stati impossibili |
| ERR-003 | ❌ NON DEVE | Mai usare stringhe hardcoded per messaggi di errore |
| ERR-004 | ⚠️ DOVREBBE | Preferire factory methods statici per creare errori tipizzati |

### Struttura Errori

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| ERR-010 | ✅ DEVE | Ogni errore deve avere un codice univoco (formato: `XX-YYY-NNN`) |
| ERR-011 | ✅ DEVE | Includere Layer, Component, Code, Message in ogni errore |
| ERR-012 | ⚠️ DOVREBBE | Includere timestamp UTC dell'errore |
| ERR-013 | 💡 PUO | Includere eccezione originale se presente |

### Internal Error Enum (Pattern Helper)

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| ERR-030 | 💡 PUO | Usare enum interno per helper con 3+ tipi di errore distinti |
| ERR-031 | ⚠️ DOVREBBE | Creare Result Type dedicato se si usa enum interno |
| ERR-032 | ✅ DEVE | Mappare enum a `ProtocolError` nel layer (non esporre enum) |
| ERR-033 | ⚠️ DOVREBBE | Usare enum per statistiche granulari (`RecordErrorByType`) |

### Gerarchia Eccezioni (Driver/Hardware)

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| ERR-020 | ✅ DEVE | Le eccezioni driver devono derivare da `ChannelException` |
| ERR-021 | ⚠️ DOVREBBE | Eccezioni hardware specifiche derivano da `*HardwareException` |
| ERR-022 | ❌ NON DEVE | Mai lanciare `Exception` generica, usare tipi specifici |

### Eccezioni BCL - Quando Usarle

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| ERR-040 | ✅ DEVE | `ArgumentNullException` per parametri null non ammessi |
| ERR-041 | ✅ DEVE | `ArgumentException` per parametri con valori invalidi |
| ERR-042 | ✅ DEVE | `ArgumentOutOfRangeException` per valori fuori range |
| ERR-043 | ✅ DEVE | `InvalidOperationException` per operazioni su stato invalido |
| ERR-044 | ✅ DEVE | `ObjectDisposedException` per oggetti già disposti |
| ERR-045 | ❌ NON DEVE | NON creare eccezioni custom per casi coperti da BCL |

### Catch Granulari nei Layer

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| ERR-050 | ✅ DEVE | Ogni layer DEVE avere catch specifici per eccezioni attese |
| ERR-051 | ✅ DEVE | `catch (OperationCanceledException)` per shutdown intenzionale |
| ERR-052 | ⚠️ DOVREBBE | `catch (ArgumentException)` prima di `catch (Exception)` |
| ERR-053 | ⚠️ DOVREBBE | `catch (InvalidOperationException)` per stati invalidi |
| ERR-054 | ✅ DEVE | `catch (Exception)` solo come catch-all finale con `LogCritical` |
| ERR-055 | ✅ DEVE | PhysicalLayer: catch per `ChannelException` e derivate |
| ERR-056 | ⚠️ DOVREBBE | PresentationLayer: catch per `CryptographicException` |

### Pattern Catch per Tipo di Layer

**Layer con I/O (PhysicalLayer):**
```csharp
catch (OperationCanceledException) { /* shutdown */ }
catch (ChannelTimeoutException ex) { /* timeout specifico */ }
catch (ConnectionLostException ex) { /* disconnessione */ }
catch (ChannelNotConnectedException ex) { /* non connesso */ }
catch (ChannelException ex) { /* altre eccezioni channel */ }
catch (Exception ex) { LogCritical + UnexpectedError }
```

**Layer di Processing (DataLink, Network, Transport, Session, Application):**
```csharp
catch (ArgumentException ex) { /* validazione */ }
catch (InvalidOperationException ex) { /* stato invalido */ }
catch (Exception ex) { LogCritical + UnexpectedError }
```

**Layer Crypto (PresentationLayer):**
```csharp
catch (CryptographicException ex) { /* errori crypto */ }
catch (ArgumentException ex) { /* validazione */ }
catch (InvalidOperationException ex) { /* stato invalido */ }
catch (Exception ex) { LogCritical + UnexpectedError }
```

**Shutdown/Dispose (swallow pattern):**
```csharp
catch (ObjectDisposedException) { /* già disposto - ok */ }
catch (Exception ex) { LogWarning + continua }
```

### Codici Errore per Layer

| Layer | Prefisso | Esempio |
|-------|----------|---------|
| Physical | PL | `PL-INIT-001` |
| DataLink | DL | `DL-CRC-001` |
| Network | NL | `NL-ROUTE-001` |
| Transport | TL | `TL-CHUNK-001` |
| Session | SL | `SL-STATE-001` |
| Presentation | PR | `PR-CRYPT-001` |
| Application | AL | `AL-CMD-001` |

---

## Esempi

### ✅ Uso Corretto - Result Type per errori attesi

```csharp
// Factory method per errore tipizzato
public static class DataLinkErrors
{
    public static LayerResult CrcMismatch(ushort expected, ushort actual) =>
        LayerResult.Error(
            code: "DL-CRC-001",
            message: $"CRC mismatch: expected {expected:X4}, got {actual:X4}",
            isRecoverable: true);
}

// Utilizzo
if (calculatedCrc != receivedCrc)
    return DataLinkErrors.CrcMismatch(calculatedCrc, receivedCrc);
```

### ✅ Uso Corretto - Eccezione per stato impossibile

```csharp
public class CanChannelDriver : IChannelDriver
{
    public async Task SendAsync(byte[] data, CancellationToken ct)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        
        if (!IsConnected)
            throw new ChannelNotConnectedException("Cannot send on disconnected channel");
        
        // ...
    }
}
```

### ✅ Uso Corretto - Gerarchia eccezioni driver

```csharp
// Base exception per canale
public class ChannelException : Exception
{
    public ChannelType ChannelType { get; }
    // ...
}

// Eccezione specifica CAN
public class CanHardwareException : ChannelException
{
    public PcanStatus ErrorCode { get; }
    // ...
}
```

### ✅ Uso Corretto - Internal Error Enum (Pattern Helper)

```csharp
// 1. Enum interno per l'helper (2+ tipi di errore di protocollo)
internal enum ParseError
{
    None = 0,
    BufferTooShort,
    LengthMismatch
}

// 2. Result Type dedicato per l'helper
internal readonly struct ParseResult
{
    public bool IsSuccess { get; }
    public DataLinkFrame? Frame { get; }
    public ParseError Error { get; }

    public static ParseResult Success(DataLinkFrame frame) => new(frame);
    public static ParseResult Failure(ParseError error) => new(error);
}

// 3. Helper usa enum internamente + ArgumentNullException per bug (ERR-040)
internal static class DataLinkFrameParser
{
    public static ParseResult Parse(byte[] buffer)
    {
        ArgumentNullException.ThrowIfNull(buffer);  // Bug, non errore di protocollo
        if (buffer.Length < MIN_SIZE)
            return ParseResult.Failure(ParseError.BufferTooShort);
        // ...
    }
}

// 4. Layer mappa enum a ProtocolError (ERR-032)
internal sealed class DataLinkLayer
{
    public Task<LayerResult> ProcessUpstreamAsync(byte[] data, LayerContext context)
    {
        ParseResult parseResult = DataLinkFrameParser.Parse(data);

        if (!parseResult.IsSuccess)
        {
            _statistics.RecordParseErrorByType(parseResult.Error); // ERR-033
            return Task.FromResult(
                LayerResult.Error(DataLinkErrors.ParseFailed(parseResult.Error)));
        }
        // ...
    }
}

// 5. Factory mappa enum → ProtocolError
internal static class DataLinkErrors
{
    public static ProtocolError ParseFailed(ParseError error) => new(
        Code: "DL-PARSE-001",
        Message: "Frame parsing failed",
        IsRecoverable: true,
        Details: error.ToString());
}
```

### ❌ Uso Scorretto - Stringa hardcoded

```csharp
// MAI fare questo
return LayerResult.Error("CRC non valido");

// Ne questo
throw new Exception("Errore generico");
```

### ❌ Uso Scorretto - Eccezione per flusso normale

```csharp
// MAI usare eccezioni per errori attesi
try
{
    ValidateCrc(frame);
}
catch (CrcException ex)  // ❌ CRC invalido e un caso normale
{
    return LayerResult.Error(ex.Message);
}
```

### ✅ Uso Corretto - Eccezioni BCL (ERR-040 - ERR-044)

```csharp
// ERR-040: ArgumentNullException per parametri null
public void SetKey(CryptType type, byte[] key)
{
    ArgumentNullException.ThrowIfNull(key);
    // ...
}

// ERR-041: ArgumentException per valori invalidi
public static byte[] Serialize(ApplicationMessage message)
{
    if (message.Data.Length > MAX_SIZE)
        throw new ArgumentException($"Payload too large: {message.Data.Length}", nameof(message));
}

// ERR-042: ArgumentOutOfRangeException per range
public void SetTimeout(int milliseconds)
{
    ArgumentOutOfRangeException.ThrowIfNegativeOrZero(milliseconds);
}

// ERR-043: InvalidOperationException per stato invalido
public async Task SendAsync(byte[] data)
{
    if (!IsConnected)
        throw new InvalidOperationException("Cannot send on disconnected channel");
}

// ERR-044: ObjectDisposedException
public void DoSomething()
{
    ObjectDisposedException.ThrowIf(_disposed, this);
}
```

### ❌ Uso Scorretto - Eccezione custom non necessaria

```csharp
// ❌ NON creare eccezioni custom per casi coperti da BCL
public class ConfigurationInvalidException : Exception { }

// ✅ Usare ArgumentException
throw new ArgumentException("Invalid configuration value", nameof(config));
```

---

## Gerarchia Eccezioni Custom

```
Exception (BCL)
└── ChannelException (Protocol.Infrastructure)
    ├── ConnectionLostException
    ├── ChannelNotConnectedException  
    ├── ChannelTimeoutException
    ├── CanHardwareException (Drivers.Can)
    │   ├── CanTransmitException
    │   ├── CanBusOffException
    │   └── CanBufferOverrunException
    └── BleHardwareException (Drivers.Ble)
```

**Quando creare nuove eccezioni custom:**
- ✅ Errori specifici del dominio hardware/channel
- ✅ Necessità di trasportare dati specifici (es. `LostFrames`, `Timeout`)
- ✅ Differenziare tra tipi di errore per recovery diversi
- ❌ NON per validation di argomenti (usare BCL)
- ❌ NON per stati invalidi generici (usare `InvalidOperationException`)

---

## Meccanismi Attuali

### API Pubblica (Layer → Consumer)

| Componente | Tipo errore | Meccanismo | Stato |
|------------|-------------|------------|-------|
| Layer processing | `LayerResult.Error(ProtocolError)` | Errore tipizzato con codice | ✅ Conforme |
| All Layers | `*Errors` factory | Factory method tipizzati | ✅ Conforme |
| Channel/Driver | `ChannelException` gerarchia | Eccezioni tipizzate | ✅ Conforme |
| Driver specifici | `BleHardwareException`, `CanHardwareException` | Eccezioni specifiche | ✅ Conforme |

### Internal (Helper → Layer) - Pattern ERR-030

| Componente | Enum | Result Type | Mapping | Stato |
|------------|------|-------------|---------|-------|
| DataLinkFrameParser | `ParseError` (2 valori) | `ParseResult` | `DataLinkErrors.ParseFailed()` | ✅ Conforme |
| ChunkReassembler | `ReassemblyError` (5 valori) | `ReassemblyResult` | `TransportErrors.ReassemblyFailed()` | ✅ Conforme |

---

## Eccezioni allo Standard

Nessuna eccezione attualmente - tutti i pattern legacy sono stati rimossi.

---

## Enforcement

- [x] **Code Review:** Verificare che nuovi errori seguano il pattern tipizzato
- [ ] **Analyzer:** Attivare CA1065 (no exceptions in unexpected locations)
- [x] **Test:** Verificare che ogni errore abbia codice univoco

---

## Piano di Migrazione

### Fase 1: Infrastruttura (v0.5.x) ✅ COMPLETATA
- [x] Creare `Protocol/Infrastructure/Errors/ProtocolError.cs`
- [x] Aggiornare `LayerResult` con property `ProtocolError` e factory `Error(ProtocolError)`
- [x] Creare `DataLinkErrors` factory come template
- [x] Test per nuove API (17 test)

### Fase 2: Migrazione Layer (v0.5.x) ✅ COMPLETATA
- [x] Creare factory `*Errors` per ogni layer:
  - [x] `PhysicalErrors` (PL-xxx)
  - [x] `DataLinkErrors` (DL-xxx)
  - [x] `NetworkErrors` (NL-xxx)
  - [x] `TransportErrors` (TL-xxx)
  - [x] `SessionErrors` (SL-xxx)
  - [x] `PresentationErrors` (PR-xxx)
  - [x] `ApplicationErrors` (AL-xxx)
- [x] Migrare 61 occorrenze di `LayerResult.Error(string)` → 0 rimaste
- [x] Documentare pattern Internal Error Enum (ERR-030 - ERR-033)
- [x] Confermare `ParseError` e `ReassemblyError` come pattern valido

### Fase 3: Catch Granulari (v0.5.x) ✅ COMPLETATA
- [x] Fix `BleHardwareException` → deriva da `ChannelException` (ERR-020)
- [x] Documentare regole ERR-050 - ERR-056 per catch granulari
- [x] Migrare 22 `catch(Exception)` generici → 64 catch granulari
- [x] Aggiungere 13 nuovi codici errore `*-999` (UnexpectedError)
- [x] Pattern specifici per layer tipo (I/O, Processing, Crypto, Shutdown)
- [x] `ParseError`: Rimosso `InvalidBuffer` (null → `ArgumentNullException` per ERR-040)
- [x] `ReassemblyError`: Aggiunti `DuplicateChunk` e `PayloadTooLarge`
- [x] `ChunkReassembler`: Logica detection duplicati e payload overflow (max 64KB)
- [x] Test: +32 nuovi test per error handling

| Layer | Catch Prima | Catch Dopo | Nuovi Errori |
|-------|-------------|------------|--------------|
| Physical | 2 | 12 | +6 (PL-CHAN-*) |
| DataLink | 2 | 6 | +1 (DL-INT-999) |
| Network | 3 | 8 | +1 (NL-PROC-999) |
| Transport | 2 | 6 | +1 (TL-PROC-999) |
| Session | 2 | 6 | +1 (SL-PROC-999) |
| Presentation | 2 | 8 | +1 (PR-CRYPT-999) |
| Application | 5 | 11 | +2 (AL-CMD-005/999) |
| Stack/Base | 4 | 7 | - |
| **Totale** | **22** | **64** | **+13** |

### Fase 4: Cleanup (v0.5.x) ✅ COMPLETATA
- [x] Rimosso overload `LayerResult.Error(string)` deprecato
- [x] Aggiornati 5 test per usare `LayerResult.Error(ProtocolError)`
- [x] Nessuna occorrenza rimasta nel codice di produzione

---

## Riferimenti

- [Microsoft Error Handling Guidelines](https://docs.microsoft.com/en-us/dotnet/standard/exceptions/)
- `Protocol/Infrastructure/Errors/ProtocolError.cs` - Record errore tipizzato
- `Protocol/Layers/Base/Models/LayerResult.cs` - Result type principale
- `Protocol/Layers/*/Errors/*Errors.cs` - Factory errori per layer
- `Protocol/Layers/DataLinkLayer/Enums/ParseError.cs` - Esempio Internal Error Enum
- `Protocol/Layers/TransportLayer/Enums/ReassemblyError.cs` - Esempio Internal Error Enum

---

## Changelog

| Data | Versione | Descrizione |
|------|----------|-------------|
| 2026-02-13 | 1.6 | Fase 4 completata: rimosso `LayerResult.Error(string)` deprecato |
| 2026-02-13 | 1.5 | Enum cleanup: ParseError -1 valore, ReassemblyError +2 valori, +32 test |
| 2026-02-13 | 1.4 | Fase 3: catch granulari (22→64), +13 codici errore, pattern per tipo layer |
| 2026-02-13 | 1.3 | Exception Guidelines: ERR-040-045, gerarchia custom, fix BleHardwareException |
| 2026-02-13 | 1.2 | Fase 2 completata: 7 factory `*Errors`, 61→0 migrazioni, pattern Internal Error Enum |
| 2026-02-13 | 1.1 | Fase 1 completata: ProtocolError, LayerResult.Error(ProtocolError), DataLinkErrors |
| 2026-02-12 | 1.0 | Conversione da issue T-012 a standard attivo |
| 2026-02-06 | 0.1 | Bozza iniziale come issue T-012 |

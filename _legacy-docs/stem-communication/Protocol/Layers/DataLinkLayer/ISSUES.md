# DataLinkLayer - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunità di refactoring e violazioni di best practice per il componente **DataLinkLayer**.

> **Ultimo aggiornamento:** 2026-02-09

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 1 | 2 |
| **Media** | 3 | 3 |
| **Bassa** | 2 | 1 |

**Totale aperte:** 6  
**Totale risolte:** 6

---

## Issue Trasversali Correlate

| ID | Titolo | Status | Impatto su DataLinkLayer |
|----|--------|--------|--------------------------|
| **T-012** | Standardizzazione Gestione Errori | Aperto | DL-004 (CrcFailurePolicy) è parte di questa standardizzazione |

→ [Protocol/ISSUES.md](../../ISSUES.md) per dettagli completi.

---

## Indice Issue Aperte

- [DL-002 - Nessuna Validazione Input in DataLinkFrameBuilder.Build()](#dl-002--nessuna-validazione-input-in-datalinkframebuilderbuild)
- [DL-004 - Mancanza di DataLinkLayerConfiguration](#dl-004--mancanza-di-datalinklayerconfiguration)
- [DL-005 - Crc16Calculator Crea Nuova Istanza per Ogni Calcolo](#dl-005--crc16calculator-crea-nuova-istanza-per-ogni-calcolo)
- [DL-006 - ProcessUpstreamAsync Non Gestisce Frame con Data Vuoto](#dl-006--processupstreamasync-non-gestisce-frame-con-data-vuoto)
- [DL-010 - ParseResult.Failure() Alloca DataLinkFrame Inutilmente](#dl-010--parseresultfailure-alloca-datalinkframe-inutilmente)
- [DL-012 - DataLinkFrame.Data Setter Converte Null in Array Vuoto](#dl-012--datalinkframedata-setter-converte-null-in-array-vuoto)

## Indice Issue Risolte

- [DL-001 - Duplicazione Logica Calcolo CRC tra Builder e Validator](#dl-001--duplicazione-logica-calcolo-crc-tra-builder-e-validator)
- [DL-003 - Bounds Checking in Frame Parsing](#dl-003--bounds-checking-in-frame-parsing)
- [DL-007 - Mancanza di Statistiche per Monitoraggio](#dl-007--mancanza-di-statistiche-per-monitoraggio)
- [DL-008 - DataLinkLayer Non Implementa IDisposable](#dl-008--datalinklayer-non-implementa-idisposable)
- [DL-009 - Mancanza di Logging](#dl-009--mancanza-di-logging)
- [DL-011 - DataLinkLayerStatistics Timestamp Non Thread-Safe](#dl-011--datalinklayerstatistics-timestamp-non-thread-safe)

---

## Priorità Critica

(Nessuna issue critica aperta)

---

## Priorità Alta

### DL-002 - Nessuna Validazione Input in DataLinkFrameBuilder.Build()

**Categoria:** Bug  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Aperto  
**Data Apertura:** 2026-01-20  

#### Descrizione

Il metodo `Build()` non valida i parametri di input. Un payload troppo grande può causare overflow di `Length` (ushort max = 65535), e un `data` array enorme può causare problemi di memoria.

#### File Coinvolti

- `Protocol/Layers/DataLinkLayer/Helpers/DataLinkFrameBuilder.cs` (righe 25-40)

#### Codice Problematico

```csharp
public static DataLinkFrame Build(CryptType crypt, uint senderId, byte[] data)
{
    var frame = new DataLinkFrame
    {
        Crypt = crypt,
        SenderId = senderId,
        Length = (ushort)(data?.Length ?? 0),  // Overflow se data.Length > 65535
        Data = data ?? []
    };

    var crc = CalculateCrc(frame);
    frame.Crc16 = crc;

    return frame;
}
```

#### Problema Specifico

- Payload di 70.000 bytes causa `Length = 4464` (overflow silenzioso)
- Frame corrotto: Length dice 4464, Data contiene 70000 bytes
- Nessuna validazione di CryptType enum

#### Soluzione Proposta

```csharp
public static DataLinkFrame Build(CryptType crypt, uint senderId, byte[] data)
{
    // Validazione input
    ArgumentNullException.ThrowIfNull(data, nameof(data));
    
    if (data.Length > DataLinkLayerConstants.MAX_PAYLOAD_SIZE)
    {
        throw new ArgumentOutOfRangeException(
            nameof(data),
            $"Payload size {data.Length} exceeds maximum allowed {DataLinkLayerConstants.MAX_PAYLOAD_SIZE}");
    }
    
    // Validazione CryptType
    if (!Enum.IsDefined(crypt))
    {
        throw new ArgumentOutOfRangeException(nameof(crypt), $"Invalid crypt type: {crypt}");
    }

    var frame = new DataLinkFrame
    {
        Crypt = crypt,
        SenderId = senderId,
        Length = (ushort)data.Length,
        Data = data
    };

    frame.Crc16 = CalculateCrc(frame);

    return frame;
}
```

**Costante da aggiungere a DataLinkLayerConstants:**

```csharp
/// <summary>
/// Dimensione massima del payload in bytes.
/// Compatibile con RX_BUFFER_MAX_LENGTH del PhysicalLayer.
/// </summary>
public const int MAX_PAYLOAD_SIZE = 1100 - HEADER_SIZE - CRC_SIZE;  // = 1091 bytes
```

#### Benefici Attesi

- Prevenzione overflow silenti
- Fail-fast con messaggi chiari
- Frame sempre validi

---

## Priorità Media

### DL-004 - Mancanza di DataLinkLayerConfiguration

**Categoria:** Design  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-25  

#### Descrizione

Il `DataLinkLayer` non ha una classe di configurazione dedicata. `InitializeAsync()` ignora completamente il parametro `config`. 

**Problema principale:** Non è possibile configurare il comportamento su CRC invalido, che dovrebbe essere diverso in ambienti di **Produzione** (scarta frame) vs **Debug** (accetta con warning per analisi).

#### Motivazione

| Ambiente | Comportamento Richiesto | Motivo |
|----------|-------------------------|--------|
| **Produzione** | Scarta frame con CRC invalido | Sicurezza, integrità dati |
| **Debug** | Accetta frame, log warning | Diagnosi problemi linea, analisi |

In ambiente di debug, scartare silenziosamente frame con CRC invalido rende difficile diagnosticare problemi di comunicazione (rumore, interferenze, bug nel firmware remoto).

#### File Coinvolti

- `Protocol/Layers/DataLinkLayer/DataLinkLayer.cs`
- `Protocol/Layers/DataLinkLayer/Models/` (nuovo file)

#### Soluzione Proposta

**1. Creare `DataLinkLayerConfiguration`:**

```csharp
public class DataLinkLayerConfiguration : LayerConfiguration
{
    /// <summary>
    /// Comportamento quando viene rilevato un CRC invalido.
    /// Default: RejectPacket (produzione).
    /// </summary>
    public CrcFailurePolicy CrcFailurePolicy { get; set; } = CrcFailurePolicy.RejectPacket;
    
    public void Validate()
    {
        if (!Enum.IsDefined(CrcFailurePolicy))
            throw new ArgumentOutOfRangeException(nameof(CrcFailurePolicy));
    }
}
```

**2. Creare enum `CrcFailurePolicy`:**

```csharp
public enum CrcFailurePolicy
{
    /// <summary>Scarta il frame. Comportamento produzione.</summary>
    RejectPacket,
    
    /// <summary>Accetta il frame, log warning, imposta flag in metadata. Comportamento debug.</summary>
    AcceptWithWarning
}
```

**3. Modificare `ProcessUpstreamAsync`:**

```csharp
if (!crcValid)
{
    _statistics.RecordCrcError();
    
    if (_config.CrcFailurePolicy == CrcFailurePolicy.RejectPacket)
    {
        _logger?.LogWarning("CRC error - frame discarded");
        return LayerResult.Error("CRC validation failed");
    }
    
    // AcceptWithWarning
    _logger?.LogWarning("CRC error - frame accepted for debug (CrcFailurePolicy.AcceptWithWarning)");
    context.SetMetadata("CrcInvalid", true);
    // Continua elaborazione...
}
```

**4. Esempio utilizzo:**

```csharp
// Produzione (default)
await layer.InitializeAsync();

// Debug
await layer.InitializeAsync(new DataLinkLayerConfiguration
{
    CrcFailurePolicy = CrcFailurePolicy.AcceptWithWarning
});
```

#### Benefici Attesi

- Comportamento configurabile per ambiente
- Diagnosi problemi facilitata in debug
- Sicurezza mantenuta in produzione
- Coerenza con pattern T-011 (Constants → Configuration)

---

### DL-005 - Crc16Calculator Crea Nuova Istanza per Ogni Calcolo

**Categoria:** Performance  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-25  

#### Descrizione

Ogni chiamata a `CalculateCrc()` (in Builder e Validator) crea una nuova istanza di `Crc16Calculator`. Per frame frequenti, questo genera allocazioni inutili.

#### File Coinvolti

- `Protocol/Layers/DataLinkLayer/Helpers/DataLinkFrameBuilder.cs` (riga 49)
- `Protocol/Layers/DataLinkLayer/Helpers/DataLinkFrameValidator.cs` (riga 70)
- `Protocol/Layers/DataLinkLayer/Helpers/Crc16Calculator.cs`

#### Problema Specifico

- 1000 pacchetti/secondo = 2000 allocazioni/secondo di Crc16Calculator
- Overhead: ~64 KB/sec di allocazioni brevi
- Pressione sul GC

#### Soluzione Proposta

**Metodo statico puro con lookup table:**

```csharp
public static class Crc16Calculator
{
    private static readonly ushort[] CrcTable = GenerateCrcTable();
    
    private static ushort[] GenerateCrcTable()
    {
        var table = new ushort[256];
        for (int i = 0; i < 256; i++)
        {
            ushort crc = (ushort)i;
            for (int j = 0; j < 8; j++)
            {
                if ((crc & 0x0001) != 0)
                    crc = (ushort)((crc >> 1) ^ 0xA001);
                else
                    crc = (ushort)(crc >> 1);
            }
            table[i] = crc;
        }
        return table;
    }
    
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    public static ushort UpdateCrc(ushort crc, byte data)
    {
        return (ushort)((crc >> 8) ^ CrcTable[(crc ^ data) & 0xFF]);
    }
    
    public static ushort ComputeForFrame(DataLinkFrame frame)
    {
        ushort crc = 0xFFFF;
        crc = UpdateCrc(crc, (byte)frame.Crypt);
        // ... resto dei campi ...
        return crc;
    }
}
```

#### Benefici Attesi

- Zero allocazioni per calcolo CRC
- Minor pressione GC
- Performance migliorate con lookup table

---

### DL-006 - ProcessUpstreamAsync Non Gestisce Frame con Data Vuoto

**Categoria:** Design  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-25  

#### Descrizione

`ProcessUpstreamAsync()` non gestisce esplicitamente il caso di frame con `Length = 0` (nessun payload). Il frame verrebbe validato correttamente ma passato al layer superiore con array vuoto.

#### File Coinvolti

- `Protocol/Layers/DataLinkLayer/DataLinkLayer.cs` (righe 87-179)

#### Problema Specifico

- Comportamento indefinito per frame senza payload
- Non documentato se frame vuoti sono validi nel protocollo
- Potrebbero essere keepalive, ACK, o errori

#### Soluzione Proposta

Dipende dalla specifica del protocollo. Se frame vuoti sono validi:

```csharp
if (frame.Length == 0)
{
    context.SetMetadata("IsEmptyFrame", true);
    return Task.FromResult(LayerResult.Success([], new Dictionary<string, object>
    {
        ["SenderId"] = frame.SenderId,
        ["CryptType"] = frame.Crypt,
        ["IsKeepAlive"] = true
    }));
}
```

#### Benefici Attesi

- Comportamento esplicito per edge case
- Documentazione implicita delle regole del protocollo

---

## Priorità Bassa

### DL-010 - ParseResult.Failure() Alloca DataLinkFrame Inutilmente

**Categoria:** Performance  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-28  

#### Descrizione

Il metodo `ParseResult.Failure()` crea sempre una nuova istanza di `DataLinkFrame` anche se non verrà mai utilizzata. Questo genera allocazioni inutili per ogni errore di parsing.

#### File Coinvolti

- `Protocol/Layers/DataLinkLayer/Models/ParseResult.cs` (righe 50-55)

#### Codice Problematico

```csharp
private ParseResult(ParseError error)
{
    IsSuccess = false;
    Frame = new DataLinkFrame();  // Allocazione inutile
    Error = error;
}
```

#### Soluzione Proposta

Usare istanza statica condivisa:

```csharp
public readonly struct ParseResult
{
    private static readonly DataLinkFrame EmptyFrame = new();
    
    private ParseResult(ParseError error)
    {
        IsSuccess = false;
        Frame = EmptyFrame;  // Shared, nessuna nuova allocazione
        Error = error;
    }
}
```

#### Benefici Attesi

- Zero allocazioni per errori parsing
- Minore GC pressure
- Retrocompatibile

---

### DL-012 - DataLinkFrame.Data Setter Converte Null in Array Vuoto

**Categoria:** API  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-01  

#### Descrizione

La proprietà `Data` di `DataLinkFrame` ha un setter che converte silenziosamente `null` in un array vuoto. Questo comportamento è nascosto e potrebbe mascherare bug.

#### File Coinvolti

- `Protocol/Layers/DataLinkLayer/Models/DataLinkFrame.cs` (righe 35-39)

#### Codice Problematico

```csharp
public byte[] Data
{
    get => _data;
    set => _data = value ?? [];  // Conversione silente null ? []
}
```

#### Soluzione Proposta

Lanciare eccezione per null o documentare il comportamento:

```csharp
public byte[] Data
{
    get => _data;
    set
    {
        ArgumentNullException.ThrowIfNull(value, nameof(value));
        _data = value;
    }
}
```

#### Benefici Attesi

- Fail-fast su errori del chiamante
- Comportamento esplicito

---

## Issue Risolte

### DL-001 - Duplicazione Logica Calcolo CRC tra Builder e Validator

**Categoria:** Code Smell  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-01-20  
**Data Risoluzione:** 2026-02-06  
**Branch:** fix/dl-001  

#### Descrizione

Il metodo `CalculateCrc()` era duplicato identicamente in `DataLinkFrameBuilder` e `DataLinkFrameValidator`, violando il principio DRY.

#### Soluzione Implementata

1. **Aggiunto `Crc16Calculator.ComputeForFrame()`** - Metodo statico centralizzato
2. **`DataLinkFrameBuilder.Build()`** - Ora usa `Crc16Calculator.ComputeForFrame()`
3. **`DataLinkFrameValidator.ValidateCrc()`** - Ora usa `Crc16Calculator.ComputeForFrame()`
4. **Rimosso `DataLinkFrameValidator.CalculateCrc()`** - Metodo duplicato eliminato

#### Test Aggiunti

5 test in `Crc16CalculatorTests.cs`:
- `ComputeForFrame_ShouldMatchBuilderCrc`
- `ComputeForFrame_SameFrame_ShouldProduceSameResult`
- `ComputeForFrame_DifferentFrames_ShouldProduceDifferentCrc`
- `ComputeForFrame_EmptyData_ShouldProduceValidCrc`
- `ComputeForFrame_ShouldIncludeAllFields`

#### Benefici Ottenuti

- Single Point of Change per logica CRC
- Impossibile disallineare le implementazioni
- Manutenzione semplificata

---

### DL-003 - Bounds Checking in Frame Parsing

**Categoria:** Bug  
**Priorità:** Alta  
**Impatto:** Critico  
**Status:** Risolto  
**Data Apertura:** 2026-01-15  
**Data Risoluzione:** 2026-01-28  
**Branch:** fix/dl-003  

#### Descrizione

Il sistema aveva già un design corretto con separazione delle responsabilità. `DataLinkFrameParser` esegue validazione completa prima di chiamare `DataLinkFrameSerializer.Deserialize()`.

#### Soluzione Implementata

**Modifiche Effettuate:**

1. **File `DataLinkLayerConstants.cs`:**
   - Aggiunta costante `MIN_FRAME_SIZE = HEADER_SIZE + CRC_SIZE` (9 bytes)

2. **File `DataLinkFrameParser.cs`:**
   - Refactoring per usare costante centralizzata
   - Validazione completa: null, dimensione minima, Length, coerenza buffer

#### Test Aggiunti

**Unit Tests - `DataLinkFrameParserTests.cs` (15 test esistenti):**
- `Parse_NullBuffer_ShouldReturnFailure`
- `Parse_EmptyBuffer_ShouldReturnFailure`
- `Parse_BufferTooShort_ShouldReturnFailure`
- `Parse_LengthFieldExceedsMax_ShouldReturnFailure`
- `Parse_BufferSmallerThanDeclaredLength_ShouldReturnFailure`

#### Benefici Ottenuti

- Robustezza: nessun crash su dati corrotti
- Debugging: ParseError dettagliato indica problema esatto
- Performance: overhead minimo (validazioni integer-only)

---

### DL-007 - Mancanza di Statistiche per Monitoraggio

**Categoria:** Code Smell  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-20  
**Data Risoluzione:** 2026-01-29  
**Branch:** fix/t-004  

#### Descrizione

Il DataLinkLayer non tracciava alcuna statistica.

#### Soluzione Implementata

Aggiunto `DataLinkLayerStatistics` con:
- Frame ricevuti/inviati
- Errori CRC
- Errori parsing (per tipo)
- Bytes ricevuti/inviati
- Timestamp ultimo frame

Vedi issue trasversale T-004 per dettagli.

#### Benefici Ottenuti

- Monitoraggio real-time
- Identificazione problemi di linea

---

### DL-008 - DataLinkLayer Non Implementa IDisposable

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-01-15  
**Data Risoluzione:** 2026-01-28  
**Branch:** fix/t-001  

#### Descrizione

`DataLinkLayer` non implementava `IDisposable`.

#### Soluzione Implementata

`DataLinkLayer` ora eredita da `ProtocolLayerBase` che implementa `IDisposable`.

Vedi issue trasversale T-001 per dettagli.

#### Benefici Ottenuti

- Coerenza con altri layer
- Preparazione per future estensioni

---

### DL-009 - Mancanza di Logging

**Categoria:** Code Smell  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-20  
**Data Risoluzione:** 2026-01-30  
**Branch:** fix/t-002  

#### Descrizione

Il DataLinkLayer non aveva alcun logging.

#### Soluzione Implementata

Logging completo implementato con:
- `LogTrace`: Upstream/downstream bytes
- `LogDebug`: Frame validati, frame costruiti
- `LogWarning`: Parse falliti, CRC errors, CryptType invalidi
- `LogError`: Eccezioni durante processing
- `LogInformation`: Inizializzazione layer

#### Benefici Ottenuti

- Troubleshooting semplificato
- Visibilità su errori CRC
- Correlazione con log altri layer

---

### DL-011 - DataLinkLayerStatistics Timestamp Non Thread-Safe

**Categoria:** Bug  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-01-28  
**Data Risoluzione:** 2026-02-03  
**Branch:** fix/t-005  

#### Descrizione

Le proprietà `LastFrameReceivedAt` e `LastFrameSentAt` erano `DateTime?` non atomiche.

#### Soluzione Implementata

**Modifiche Effettuate:**

1. **File `DataLinkLayerStatistics.cs`:**
   - DateTime convertiti in `long` Ticks con `Interlocked`
   - Pattern T-005 applicato

```csharp
private long _lastFrameReceivedAtTicks;

public DateTime? LastFrameReceivedAt
{
    get
    {
        long ticks = Interlocked.Read(ref _lastFrameReceivedAtTicks);
        return ticks == 0 ? null : new DateTime(ticks);
    }
}
```

#### Benefici Ottenuti

- Thread-safety completa
- Consistenza con altri layer statistics
- Conforme a T-005

---

## Links

- [ISSUES Protocol](../../ISSUES.md)
- [README DataLinkLayer](README.md)

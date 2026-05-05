# Standard Logging - Policy di Logging Strutturato

> **Versione:** 2.0  
> **Data:** 2026-02-12  
> **Riferimento Issue:** T-003  
> **Stato:** Active

---

## Scopo

Questo standard definisce le regole per il logging strutturato nel protocollo STEM, garantendo:
- **Troubleshooting** efficace in produzione
- **Tracciamento** del lifecycle (sessioni, routing, errori critici)
- **Performance monitoring** e rilevamento problemi di sicurezza
- **Integrazione** con sistemi di monitoring (Seq, ELK, Application Insights, Loki)

Si applica a: tutti i layer del protocollo, driver e componenti che richiedono logging.

**Riferimento tecnico:** `Microsoft.Extensions.Logging.Abstractions >= 10.0.0`

---

## Principi Guida

1. **Logger opzionale:** Nessuna dipendenza hard da logging, zero overhead se non fornito
2. **Categoria = Layer:** Tutti i log di un layer devono essere filtrabili insieme
3. **Structured logging only:** Template + parametri, mai string interpolation
4. **Null-conditional sempre:** `_logger?.LogXxx()` per evitare allocazioni e NullReferenceException
5. **Niente logging in funzioni pure:** Componenti deterministici non richiedono logging

---

## Regole

### Costruttori e Iniezione

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| LOG-001 | ✅ DEVE | Costruttori accettano `ILogger<T>? logger = null` |
| LOG-002 | ✅ DEVE | Usare `ILogger<LayerName>` come categoria |
| LOG-003 | ❌ NON DEVE | Mai `ILogger<HelperInterno>` per classi helper |
| LOG-004 | ❌ NON DEVE | Mai dipendenza obbligatoria da logger |

### Formato Messaggi

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| LOG-010 | ✅ DEVE | Usare template + parametri (structured logging) |
| LOG-011 | ✅ DEVE | Usare `_logger?.LogXxx()` (null-conditional) |
| LOG-012 | ❌ NON DEVE | Mai string interpolation nel messaggio |
| LOG-013 | ❌ NON DEVE | Mai `Console.WriteLine`, `Debug.WriteLine`, `Trace.WriteLine` |

### Livelli di Log

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| LOG-020 | ✅ DEVE | Usare livelli appropriati secondo la tabella sotto |
| LOG-021 | ⚠️ DOVREBBE | Includere eccezione come primo parametro per Error/Critical |
| LOG-022 | ❌ NON DEVE | Mai dati sensibili a livello Information o superiore |

### Componenti Senza Logging

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| LOG-030 | ❌ NON DEVE | Mai logger in funzioni matematiche/deterministiche |
| LOG-031 | ❌ NON DEVE | Mai logger in DTO/modelli puri |
| LOG-032 | ❌ NON DEVE | Mai logger in validatori stateless ad alta frequenza |

---

## Livelli di Log

| Livello | Uso | Esempio |
|---------|-----|---------|
| **Trace** | Dettaglio byte-level, solo dev | Dump buffer, frame raw |
| **Debug** | Operazioni interne normali | Chunk creati, route selezionato |
| **Information** | Eventi di stato e business | Sessione stabilita, device connesso |
| **Warning** | Errori recuperabili | CRC invalido, retry automatico |
| **Error** | Operazioni fallite, layer vivo | Handler exception, timeout |
| **Critical** | Layer inutilizzabile | Driver crash, corruzione stato |

---

## Naming Conventions

| Tipo | Convenzione | Esempio |
|------|-------------|---------|
| Device ID | `{DeviceId:X8}` | `12AB34CD` |
| Dimensioni | `{DataLength}`, `{Size}` | `256` |
| Tempo | `{LatencyMs}`, `{DurationMs}` | `15.3` |
| Conteggi | `{ChunkCount}`, `{RetryCount}` | `5` |
| Stato | `{SessionState}`, `{RouteState}` | `Established` |
| CRC/Checksum | `{Crc:X4}`, `{ExpectedCrc:X4}` | `A1B2` |

---

## Esempi

### ✅ Uso Corretto - Layer Principale

```csharp
public class NetworkLayer
{
    private readonly ILogger<NetworkLayer>? _logger;
    
    public NetworkLayer(ILogger<NetworkLayer>? logger = null)
    {
        _logger = logger;
    }
    
    public async Task<LayerResult> ProcessUpstreamAsync(byte[] data, LayerContext context)
    {
        _logger?.LogTrace(
            "Upstream <- {DataLength} bytes from {SenderId:X8}",
            data.Length,
            context.SenderId);
        
        try
        {
            var result = await ProcessInternalAsync(data, context);
            
            _logger?.LogDebug(
                "Upstream completed: route={RouteId}, latency={LatencyMs}ms",
                result.RouteId,
                result.LatencyMs);
            
            return result;
        }
        catch (Exception ex)
        {
            _logger?.LogError(
                ex,
                "Upstream processing failed for {DataLength} bytes from {SenderId:X8}",
                data.Length,
                context.SenderId);
            throw;
        }
    }
}
```

### ✅ Uso Corretto - Helper con Logger del Layer

```csharp
// Helper usa il logger del layer proprietario, NON il proprio
internal class ChunkHelper
{
    private readonly ILogger? _logger;
    
    public ChunkHelper(ILogger? logger)
    {
        _logger = logger;
    }
    
    public List<byte[]> CreateChunks(byte[] data, int maxSize)
    {
        var chunks = SplitData(data, maxSize);
        
        _logger?.LogDebug(
            "Created {ChunkCount} chunks (max size = {MaxChunkSize})",
            chunks.Count,
            maxSize);
        
        return chunks;
    }
}
```

### ✅ Uso Corretto - Eccezioni con Contesto

```csharp
_logger?.LogWarning(
    ex,
    "Invalid frame from {SenderId:X8} - length={Length}, expected crc={ExpectedCrc:X4}",
    context.SenderId,
    data.Length,
    expectedCrc);
```

### ❌ Uso Scorretto - String Interpolation

```csharp
// MAI fare questo
_logger?.LogDebug($"Processing {data.Length} bytes from {context.SenderId:X8}");
```

### ❌ Uso Scorretto - Console/Debug WriteLine

```csharp
// MAI fare questo
Console.WriteLine($"Data received: {data.Length} bytes");
Debug.WriteLine($"Processing frame");
```

### ❌ Uso Scorretto - Logger in Funzione Pura

```csharp
// MAI fare questo - CRC e funzioni pure senza logger
public static class Crc16Calculator
{
    private readonly ILogger? _logger;  // ❌ NON necessario
    
    public static ushort Calculate(byte[] data)
    {
        _logger?.LogTrace("Calculating CRC...");  // ❌ Overhead inutile
        // ...
    }
}
```

### ❌ Uso Scorretto - ILogger<Helper>

```csharp
// MAI fare questo
public class ChunkHelper
{
    private readonly ILogger<ChunkHelper>? _logger;  // ❌ Usa ILogger del layer
}
```

---

## Eccezioni

| Componente | Eccezione | Motivazione |
|------------|-----------|-------------|
| `Crc16Calculator` | Nessun logger | Funzione pura deterministica |
| `DeviceIdCalculator` | Nessun logger | Funzione pura deterministica |
| `TransportChunk`, `LayerContext` | Nessun logger | DTO/modelli puri |
| `FrameValidator.Validate` | Nessun logger | Validatore stateless ad alta frequenza |
| Helper interni | Usa `ILogger` del layer | Evita categorie multiple per stesso layer |

---

## Enforcement

- [ ] **Analyzer:** IDE0079 - Rimuovere `Console.WriteLine` non necessari
- [ ] **Code Review:** Verificare assenza di string interpolation nei log
- [ ] **Code Review:** Verificare che helper usino `ILogger` del layer proprietario
- [ ] **Code Review:** Verificare `ILogger<T>? logger = null` nei costruttori
- [ ] **Build:** Warning se `Console.WriteLine` in codice production

### Checklist Code Review

- [ ] Logger accetta null? (`ILogger<T>? logger = null`)
- [ ] Categoria corretta? (`ILogger<LayerName>`)
- [ ] Null-conditional usato? (`_logger?.LogXxx`)
- [ ] Structured logging? (template + parametri)
- [ ] Niente string interpolation?
- [ ] Niente Console/Debug.WriteLine?
- [ ] Livello appropriato?
- [ ] Niente dati sensibili a Information+?

---

## Riferimenti

- [Microsoft.Extensions.Logging](https://docs.microsoft.com/en-us/dotnet/core/extensions/logging)
- [Structured Logging Best Practices](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/logging/)
- [Serilog Message Templates](https://messagetemplates.org/)
- `Protocol/Layers/Base/ProtocolLayerBase.cs` - Pattern di riferimento

---

## Changelog

| Data | Versione | Descrizione |
|------|----------|-------------|
| 2026-02-12 | 2.0 | Allineamento a STANDARD_TEMPLATE.md, aggiunta sezione Regole con codici |
| 2026-01-28 | 1.0 | Versione iniziale - logging policy T-003 |

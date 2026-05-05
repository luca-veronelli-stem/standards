# Standard CancellationToken - Gestione Cancellazione Operazioni Asincrone

> **Versione:** 1.1  
> **Data:** 2026-02-26  
> **Riferimento Issue:** T-024  
> **Stato:** Active

---

## Scopo

Questo standard definisce le regole per l'uso di `CancellationToken` nelle API asincrone, garantendo:

- **Cancellabilità:** Tutte le operazioni async possono essere interrotte
- **Timeout:** Supporto nativo per timeout configurabili
- **Graceful Shutdown:** Arresto controllato senza perdita di dati
- **Responsiveness:** UI reattiva durante operazioni lunghe
- **Consistenza:** Pattern uniforme in tutto il progetto

Si applica a: tutti i metodi async in Protocol/, Drivers.Can/, Drivers.Ble/, Client/.

---

## Principi Guida

1. **Cancellazione Cooperativa:** Il chiamante richiede, il chiamato rispetta
2. **Propagazione Completa:** CT deve fluire attraverso tutta la call chain
3. **Fail-Fast:** Verificare cancellazione all'inizio e nei loop
4. **No Blocking:** Mai bloccare in attesa su operazioni cancellabili
5. **Clean Shutdown:** Cancellazione non deve corrompere lo stato

---

## Regole

### Firma dei Metodi

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| CT-001 | ✅ DEVE | Ogni metodo `async` pubblico/protected DEVE avere `CancellationToken` come ultimo parametro |
| CT-002 | ✅ DEVE | Il parametro DEVE avere default value `= default` |
| CT-003 | ✅ DEVE | Il nome del parametro DEVE essere `cancellationToken` (non abbreviato) |
| CT-004 | ⚠️ DOVREBBE | Metodi `internal` dovrebbero seguire le stesse regole per consistenza |
| CT-005 | 💡 PUÒ | Metodi `private` possono omettere CT se non eseguono operazioni cancellabili |

### Propagazione

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| CT-010 | ✅ DEVE | CT DEVE essere propagato a tutti i metodi async chiamati internamente |
| CT-011 | ✅ DEVE | CT DEVE essere propagato a `Task.Delay()`, `Channel.ReadAsync()`, etc. |
| CT-012 | ✅ DEVE | CT DEVE essere propagato ai driver e alle operazioni I/O |
| CT-013 | ❌ NON DEVE | NON passare `CancellationToken.None` per "ignorare" la cancellazione del chiamante |

### Verifica Cancellazione

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| CT-020 | ✅ DEVE | Loop lunghi (>100 iterazioni potenziali) DEVONO chiamare `ct.ThrowIfCancellationRequested()` |
| CT-021 | ⚠️ DOVREBBE | Verificare cancellazione all'inizio di metodi con operazioni costose |
| CT-022 | 💡 PUÒ | Usare `ct.IsCancellationRequested` per cleanup non-throwing |
| CT-023 | ❌ NON DEVE | NON catturare `OperationCanceledException` per continuare l'operazione |

### Pattern Timeout

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| CT-030 | ⚠️ DOVREBBE | Usare `CancellationTokenSource.CreateLinkedTokenSource()` per combinare CT esterno + timeout |
| CT-031 | ✅ DEVE | Disporre sempre il `CancellationTokenSource` creato (pattern `using`) |
| CT-032 | ⚠️ DOVREBBE | Preferire timeout nel CT piuttosto che `Task.WhenAny()` con `Task.Delay()` |

### Gestione Eccezioni

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| CT-040 | ✅ DEVE | `OperationCanceledException` DEVE propagarsi al chiamante (non swallowed) |
| CT-041 | 💡 PUÒ | Loggare cancellazione a livello Debug/Trace |
| CT-042 | ⚠️ DOVREBBE | Distinguere tra cancellazione esterna (rethrow) e timeout interno (gestire) |
| CT-043 | ❌ NON DEVE | NON convertire `OperationCanceledException` in altro tipo di eccezione |

### ConfigureAwait

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| CT-050 | ⚠️ DOVREBBE | Usare `ConfigureAwait(false)` su tutte le chiamate `await` in library code |
| CT-051 | ❌ NON DEVE | NON usare `ConfigureAwait(false)` in code paths che accedono a UI |
| CT-052 | 💡 PUÒ | Omettere `ConfigureAwait(false)` se il metodo è molto breve (1-2 await) |

---

## Interfacce Coinvolte

### IProtocolLayer

```csharp
public interface IProtocolLayer : IDisposable, IAsyncDisposable
{
    // ✅ Aggiungere CT
    Task<bool> InitializeAsync(LayerConfiguration? config = null, CancellationToken cancellationToken = default);
    Task<bool> UninitializeAsync(CancellationToken cancellationToken = default);
    Task<LayerResult> ProcessUpstreamAsync(byte[] data, LayerContext context, CancellationToken cancellationToken = default);
    Task<LayerResult> ProcessDownstreamAsync(byte[] data, LayerContext context, CancellationToken cancellationToken = default);
}
```

### ICommandHandler / IAckHandler

```csharp
public interface ICommandHandler
{
    // ✅ Aggiungere CT
    Task<ApplicationMessage?> HandleAsync(ApplicationMessage message, LayerContext context, CancellationToken cancellationToken = default);
}

public interface IAckHandler
{
    // ✅ Aggiungere CT
    Task HandleAckAsync(ApplicationMessage message, LayerContext context, CancellationToken cancellationToken = default);
}
```

### IVariableMap

```csharp
public interface IVariableMap
{
    // ✅ Aggiungere CT
    Task<byte[]> ReadAsync(ushort address, CancellationToken cancellationToken = default);
    Task WriteAsync(ushort address, byte[] value, CancellationToken cancellationToken = default);
}
```

### ProtocolStack

```csharp
public sealed class ProtocolStack
{
    // ✅ Aggiungere CT
    public Task<bool> InitializeAsync(CancellationToken cancellationToken = default);
    public Task<bool> UninitializeAsync(CancellationToken cancellationToken = default);
    public Task<LayerResult> ProcessUpstreamAsync(byte[] data, LayerContext context, CancellationToken cancellationToken = default);
    public Task<LayerResult> ProcessDownstreamAsync(byte[] data, LayerContext context, CancellationToken cancellationToken = default);
}
```

### IChannelDriver (già conforme ✅)

L'interfaccia `IChannelDriver` è già conforme a questo standard. Tutti i metodi async hanno `CancellationToken`.

---

## Esempi

### ✅ Uso Corretto - Propagazione Completa

```csharp
public async Task<LayerResult> ProcessDownstreamAsync(
    byte[] data, 
    LayerContext context, 
    CancellationToken cancellationToken = default)  // CT-001, CT-002, CT-003
{
    // CT-021: Verifica all'inizio se operazione costosa
    cancellationToken.ThrowIfCancellationRequested();
    
    // CT-010: Propagazione a metodi interni
    var encrypted = await _cryptoProvider.EncryptAsync(data, cancellationToken);
    
    // CT-012: Propagazione a layer inferiore
    return await _lowerLayer.ProcessDownstreamAsync(encrypted, context, cancellationToken);
}
```

### ✅ Uso Corretto - Loop con Verifica

```csharp
public async Task ProcessChunksAsync(
    IEnumerable<byte[]> chunks, 
    CancellationToken cancellationToken = default)
{
    foreach (var chunk in chunks)
    {
        // CT-020: Verifica in loop
        cancellationToken.ThrowIfCancellationRequested();
        
        await ProcessChunkAsync(chunk, cancellationToken);  // CT-010
    }
}
```

### ✅ Uso Corretto - Pattern Timeout

```csharp
public async Task<byte[]?> ReadWithTimeoutAsync(
    TimeSpan timeout,
    CancellationToken cancellationToken = default)
{
    // CT-030, CT-031: Linked token source con using
    using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
    timeoutCts.CancelAfter(timeout);
    
    try
    {
        return await _driver.ReadAsync(timeoutCts.Token);  // CT-010
    }
    catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
    {
        // CT-042: Timeout interno - gestire
        _logger?.LogDebug("Read timeout after {Timeout}", timeout);
        return null;
    }
    // CT-040: Cancellazione esterna - propaga automaticamente
}
```

### ✅ Uso Corretto - ConfigureAwait

```csharp
public async Task<LayerResult> ProcessAsync(
    byte[] data, 
    CancellationToken cancellationToken = default)
{
    // CT-050: ConfigureAwait(false) in library code
    var step1 = await Step1Async(data, cancellationToken).ConfigureAwait(false);
    var step2 = await Step2Async(step1, cancellationToken).ConfigureAwait(false);
    return await Step3Async(step2, cancellationToken).ConfigureAwait(false);
}
```

### ✅ Uso Corretto - SemaphoreSlim con CT

```csharp
// Vedi anche THREAD_SAFETY_STANDARD.md regola TS-063
private readonly SemaphoreSlim _semaphore = new(1, 1);

public async Task<bool> ProcessAsync(CancellationToken cancellationToken = default)
{
    // CT-011: SemaphoreSlim.WaitAsync() DEVE ricevere CT
    await _semaphore.WaitAsync(cancellationToken).ConfigureAwait(false);
    try
    {
        await DoWorkAsync(cancellationToken).ConfigureAwait(false);  // CT-010
        return true;
    }
    finally
    {
        _semaphore.Release();
    }
}
```

### ❌ Uso Scorretto - CT Ignorato

```csharp
// ❌ NON fare: CT non propagato
public async Task<LayerResult> ProcessAsync(byte[] data, CancellationToken cancellationToken = default)
{
    var encrypted = await _cryptoProvider.EncryptAsync(data);  // ❌ CT-010 violato!
    return await _lowerLayer.ProcessDownstreamAsync(encrypted, context);  // ❌ CT-010 violato!
}

// ❌ NON fare: CT.None passato esplicitamente
public async Task ProcessAsync(byte[] data, CancellationToken cancellationToken = default)
{
    await _driver.WriteAsync(data, CancellationToken.None);  // ❌ CT-013 violato!
}
```

### ❌ Uso Scorretto - Eccezione Swallowed

```csharp
// ❌ NON fare: OperationCanceledException catturata
public async Task ProcessAsync(byte[] data, CancellationToken cancellationToken = default)
{
    try
    {
        await _driver.WriteAsync(data, cancellationToken);
    }
    catch (OperationCanceledException)
    {
        // ❌ CT-023 violato: continua come se nulla fosse
        _logger?.LogWarning("Operation cancelled, but continuing anyway");
    }
}
```

### ❌ Uso Scorretto - Abbreviazione Nome

```csharp
// ❌ NON fare: nome abbreviato
public async Task ProcessAsync(byte[] data, CancellationToken ct = default)  // ❌ CT-003 violato!

// ✅ Corretto
public async Task ProcessAsync(byte[] data, CancellationToken cancellationToken = default)
```

---

## Event Handlers

### Regola Speciale per Eventi

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| CT-060 | ❌ NON DEVE | Event handlers (`EventHandler<T>`) NON ricevono `CancellationToken` |
| CT-061 | 💡 PUÒ | Se un handler ha bisogno di cancellazione, DEVE gestire il proprio CT internamente |

### Motivazione

Gli eventi in .NET sono **fire-and-forget**:
- Il publisher non aspetta i subscriber
- Ogni subscriber può avere diverse esigenze di lifetime
- Il pattern standard `EventHandler<TEventArgs>` non include CT

### Esempio - Handler con CT Interno

```csharp
// Publisher: solleva evento senza CT
protected virtual void OnMessageReceived(MessageReceivedEventArgs e)
    => MessageReceived?.Invoke(this, e);

// Subscriber: gestisce il proprio CT se necessario
private CancellationTokenSource? _handlerCts;

private async void OnMessageReceived(object? sender, MessageReceivedEventArgs e)
{
    // Il subscriber può usare il proprio CT
    if (_handlerCts?.IsCancellationRequested == true)
        return;
    
    try
    {
        await ProcessMessageAsync(e.Message, _handlerCts?.Token ?? CancellationToken.None);
    }
    catch (OperationCanceledException)
    {
        // Handler specifico per questo subscriber
    }
}
```

---

## Ordine di Implementazione

L'applicazione dello standard deve seguire questo ordine (bottom-up):

| Fase | Componente | Dipendenze |
|------|------------|------------|
| 1 | `IVariableMap` | Nessuna |
| 2 | `ICommandHandler`, `IAckHandler` | IVariableMap |
| 3 | `IProtocolLayer` + implementazioni | ICommandHandler, IAckHandler |
| 4 | `ProtocolStack` | IProtocolLayer |
| 5 | Applicare `ConfigureAwait(false)` | Tutti |

---

## Eccezioni

| Componente | Eccezione | Motivazione |
|------------|-----------|-------------|
| `IChannelDriver` | Già conforme | Nessuna modifica necessaria |
| Event handlers | CT non applicabile | Pattern .NET standard fire-and-forget |
| Metodi sync | CT non applicabile | Solo metodi async |
| `Dispose()` / `DisposeAsync()` | CT non necessario | Dispose non è cancellabile by design |

---

## Enforcement

- [ ] **Code Review:** Verificare CT su tutti i nuovi metodi async
- [ ] **Analyzer:** Considerare analyzer custom per verificare propagazione CT
- [ ] **Test:** Aggiungere test che verificano comportamento con CT.Cancel

### Checklist Code Review

1. [ ] Ogni metodo async pubblico ha `CancellationToken cancellationToken = default`?
2. [ ] CT viene propagato a tutti i metodi async chiamati?
3. [ ] Loop lunghi chiamano `ThrowIfCancellationRequested()`?
4. [ ] `CancellationTokenSource` viene disposto con `using`?
5. [ ] `OperationCanceledException` non viene swallowed?
6. [ ] `ConfigureAwait(false)` presente su await (library code)?
7. [ ] `SemaphoreSlim.WaitAsync()` riceve CT? (vedi TS-063)

---

## Riferimenti

- [Microsoft CancellationToken Best Practices](https://docs.microsoft.com/en-us/dotnet/standard/threading/cancellation-in-managed-threads)
- [Stephen Cleary - Cancellation](https://blog.stephencleary.com/2022/02/cancellation-1-overview.html)
- [ConfigureAwait FAQ](https://devblogs.microsoft.com/dotnet/configureawait-faq/)

### Issue Correlate

| Issue | Descrizione |
|-------|-------------|
| T-024 | CancellationToken Propagation (issue principale) |
| T-019 | ConfigureAwait(false) per Library Code - **integrata in questo standard** |

### Standard Correlati

| Standard | Relazione |
|----------|-----------|
| [THREAD_SAFETY_STANDARD](THREAD_SAFETY_STANDARD.md) | TS-063 richiede CT su SemaphoreSlim.WaitAsync() - allineato con CT-011 |

---

## Changelog

| Data | Versione | Descrizione |
|------|----------|-------------|
| 2026-02-26 | 1.1 | Aggiunta sezione CTS Interni (CT-070..CT-095) per componenti con operazioni background |
| 2026-02-26 | 1.0 | Versione iniziale - Standard CancellationToken completo con regole CT-001..CT-061, esempi, ordine implementazione, integrazione ConfigureAwait (T-019), cross-ref THREAD_SAFETY_STANDARD |

---

## CancellationTokenSource Interni (CT-070..CT-095)

Questa sezione definisce le regole per componenti che necessitano di un proprio `CancellationTokenSource` interno per gestire operazioni background o timeout.

### Quando Usare un CTS Interno

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| CT-070 | ✅ DEVE | Componenti con operazioni background long-running (receive loop, heartbeat) DEVONO avere un CTS interno |
| CT-071 | ✅ DEVE | Componenti con timeout interni per protection (handler timeout) DEVONO usare CTS per rispettare anche CT esterno |
| CT-072 | ⚠️ DOVREBBE | Componenti che gestiscono risorse con lifecycle autonomo DOVREBBERO avere CTS interno |
| CT-073 | 💡 PUÒ | Componenti stateless senza operazioni background POSSONO non avere CTS interno |

### Nomenclatura CTS

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| CT-080 | ✅ DEVE | CTS interno per operazioni generali DEVE chiamarsi `_operationsCts` |
| CT-081 | ✅ DEVE | CTS per auto-reconnect DEVE chiamarsi `_reconnectCts` |
| CT-082 | ⚠️ DOVREBBE | CTS per operazione specifica DOVREBBE chiamarsi `_{operazione}Cts` (es. `_readCts`, `_connectCts`) |
| CT-083 | ⚠️ DOVREBBE | CTS temporanei in metodi locali DOVREBBERO chiamarsi `timeoutCts` o `linkedCts` |
| CT-084 | 💡 PUÒ | Se c'è un solo CTS e non c'è ambiguità, PUÒ chiamarsi `_cts` |

### Field vs Property

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| CT-085 | ✅ DEVE | CTS interni DEVONO essere `private` fields, MAI properties pubbliche |
| CT-086 | ✅ DEVE | CTS che può non esistere prima di Initialize DEVE essere nullable (`CancellationTokenSource?`) |
| CT-087 | ⚠️ DOVREBBE | CTS sempre esistente dal costruttore DOVREBBE essere non-nullable |

### Lifecycle CTS (Opzione B)

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| CT-088 | ✅ DEVE | In `UninitializeAsync()`: Cancel + Dispose il CTS esistente |
| CT-089 | ✅ DEVE | In `InitializeAsync()`: Creare nuovo CTS |
| CT-090 | ✅ DEVE | In `Dispose()/DisposeAsync()`: Cancel + Dispose il CTS esistente |
| CT-091 | ⚠️ DOVREBBE | Verificare null prima di Cancel/Dispose (`_operationsCts?.Cancel()`) |

### Combinazione CT Esterno + Interno

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| CT-092 | ✅ DEVE | Usare `CreateLinkedTokenSource(externalCt, internalCts.Token)` per combinare |
| CT-093 | ✅ DEVE | Il LinkedTokenSource DEVE essere disposto con `using` |
| CT-094 | ⚠️ DOVREBBE | Distinguere timeout interno da cancellazione esterna con `when (!cancellationToken.IsCancellationRequested)` |

### Comportamento Timeout Interno

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| CT-095 | ⚠️ DOVREBBE | Timeout attesa dati I/O → `LogTrace` + return null/default (normale) |
| CT-096 | ⚠️ DOVREBBE | Timeout handler/operazione → `LogWarning` + return null/error (anomalo) |
| CT-097 | 💡 PUÒ | Timeout operazione critica → `LogError` + throw `TimeoutException` |

> **⚠️ NOTA:** Il comportamento di CT-096 (Warning + return null) è un default fail-safe.
> Alcuni handler critici potrebbero richiedere comportamenti più severi in futuro
> (es. errori espliciti, retry automatici). Valutare caso per caso se necessario.

### Esempio - Componente con CTS Interno

```csharp
internal sealed class PhysicalLayer : ProtocolLayerBase
{
    private CancellationTokenSource? _operationsCts;  // CT-080, CT-085, CT-086

    public override async Task<bool> InitializeAsync(
        LayerConfiguration? config = null, 
        CancellationToken cancellationToken = default)
    {
        // CT-089: Crea nuovo CTS in Initialize
        _operationsCts = new CancellationTokenSource();

        // CT-092, CT-093: Combina CT esterno con interno
        using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(
            cancellationToken, _operationsCts.Token);

        return await _driver.ConnectAsync(config, linkedCts.Token)
            .ConfigureAwait(false);
    }

    public override async Task<bool> UninitializeAsync(CancellationToken cancellationToken = default)
    {
        // CT-088: Cancel + Dispose in Uninitialize
        _operationsCts?.Cancel();
        _operationsCts?.Dispose();
        _operationsCts = null;  // Pronto per re-init

        return await base.UninitializeAsync(cancellationToken)
            .ConfigureAwait(false);
    }

    protected override void DisposeResources()
    {
        // CT-090: Cancel + Dispose in Dispose
        _operationsCts?.Cancel();
        _operationsCts?.Dispose();
    }
}
```

### Esempio - Timeout Handler con Warning

```csharp
public async Task<ApplicationMessage?> ExecuteAsync(
    ApplicationMessage message, 
    LayerContext context, 
    CancellationToken cancellationToken = default)
{
    // CT-092, CT-093: Linked token source
    using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
    timeoutCts.CancelAfter(_handlerTimeout);

    try
    {
        return await handler.HandleAsync(message, context, timeoutCts.Token)
            .ConfigureAwait(false);
    }
    catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
    {
        // CT-094, CT-096: Timeout interno - warning + fail-safe
        _logger?.LogWarning(
            "Handler timeout: command={Command}, timeout={Timeout}ms",
            message.Command,
            _handlerTimeout.TotalMilliseconds);
        return null;
    }
    // CT-040: Cancellazione esterna - propaga automaticamente
}
```

### Checklist Code Review - CTS Interni

1. [ ] Il componente ha operazioni background che richiedono cancellazione?
2. [ ] Il CTS è nominato secondo CT-080..CT-084?
3. [ ] Il CTS è `private` field (CT-085)?
4. [ ] Il CTS è nullable se creato in Initialize (CT-086)?
5. [ ] `UninitializeAsync()` fa Cancel + Dispose (CT-088)?
6. [ ] `InitializeAsync()` crea nuovo CTS (CT-089)?
7. [ ] `Dispose()` fa Cancel + Dispose (CT-090)?
8. [ ] LinkedTokenSource usato per combinare CT (CT-092)?
9. [ ] LinkedTokenSource disposto con `using` (CT-093)?
10. [ ] Timeout interno distinto da cancellazione esterna (CT-094)?

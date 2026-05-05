# Standard Thread Safety - Pattern di Concorrenza nel Protocollo STEM

> **Versione:** 2.0  
> **Data:** 2026-02-12  
> **Riferimento Issue:** T-005  
> **Stato:** Active

---

## Scopo

Questo standard definisce le regole per implementare thread safety consistente in tutto lo stack protocollare STEM, garantendo:
- **Correttezza** delle operazioni su dati condivisi tra thread
- **Consistenza** dei pattern utilizzati in tutti i componenti
- **Performance** tramite lock-free quando possibile

Si applica a: tutti i layer del protocollo, driver, statistiche e componenti che gestiscono stato condiviso.

**Contesto:** Il protocollo STEM opera in ambienti multi-threaded dove diversi canali (UART, CAN, BLE, Cloud) ricevono dati simultaneamente, handler applicativi vengono eseguiti in thread separati, e timer/callback operano in modo asincrono.

---

## Principi Guida

1. **Ogni dato condiviso deve essere protetto:** Non esistono eccezioni a questa regola
2. **Lock-free quando possibile:** Preferire `Interlocked`/`Volatile` a `Lock` per operazioni semplici
3. **Immutabilita preferita:** Usare `readonly record struct` quando i dati non cambiano dopo la creazione
4. **Atomicita esplicita:** Operazioni multi-campo che devono essere atomiche richiedono `Lock`
5. **Snapshot per letture complesse:** Esporre snapshot immutabili invece di riferimenti a dati mutabili

---

## Regole

### Strategie di Protezione per Tipo di Dato

| Tipo di Dato | Strategia | Regola |
|--------------|-----------|--------|
| Contatori semplici | `Interlocked` (lock-free) | TS-001 |
| DateTime/TimeSpan | `Interlocked` su Ticks (long) | TS-002 |
| Booleani | `Volatile.Read/Write` | TS-003 |
| Collections | `ConcurrentDictionary/Queue` | TS-004 |
| Operazioni atomiche | `Interlocked.CompareExchange` | TS-005 |
| Operazioni complesse | `Lock` (.NET 10) | TS-006 |
| Read-heavy data | `ReaderWriterLockSlim` | TS-007 |
| Immutable data | `readonly record struct` | TS-008 |

### Regole per Contatori e Statistiche

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| TS-001 | ✅ DEVE | Usare `Interlocked.Increment/Add` per tutte le modifiche ai contatori |
| TS-010 | ✅ DEVE | Usare `Volatile.Read` per tutte le letture di contatori |
| TS-011 | ✅ DEVE | Usare `long` come backing field per compatibilita `Interlocked` |
| TS-012 | ❌ NON DEVE | Mai usare operatori `++`, `--`, `+=` su campi condivisi |

### Regole per DateTime e TimeSpan

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| TS-002 | ✅ DEVE | Memorizzare DateTime come `long` (Ticks) |
| TS-020 | ✅ DEVE | Usare `Interlocked.Exchange` per scritture DateTime |
| TS-021 | ✅ DEVE | Usare `Interlocked.Read` per letture DateTime |
| TS-022 | ❌ NON DEVE | Mai usare DateTime direttamente come campo (non atomico su 32-bit) |

### Regole per Booleani e Flag

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| TS-003 | ✅ DEVE | Usare `Volatile.Write` per scritture booleane |
| TS-030 | ✅ DEVE | Usare `Volatile.Read` per letture booleane |
| TS-031 | ⚠️ DOVREBBE | Usare `Interlocked.CompareExchange` per compare-and-swap |
| TS-032 | ❌ NON DEVE | Mai assegnare direttamente booleani condivisi (`_flag = true`) |

### Regole per Collections

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| TS-004 | ✅ DEVE | Usare `ConcurrentDictionary` per dictionary condivisi |
| TS-040 | ✅ DEVE | Usare `ConcurrentQueue` per code condivise |
| TS-041 | ⚠️ DOVREBBE | Usare `Lock` solo per atomicita tra operazioni multiple |
| TS-042 | ❌ NON DEVE | Mai usare `Dictionary<>` con lock esterno (usare `ConcurrentDictionary`) |

### Regole per Lock

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| TS-006 | ✅ DEVE | Usare la classe `Lock` di .NET 10 (non `object`) |
| TS-060 | ✅ DEVE | Lock deve essere su oggetto privato dedicato |
| TS-061 | ❌ NON DEVE | Mai `lock(this)` o `lock("string")` |
| TS-062 | ❌ NON DEVE | Mai `lock` in metodi async (usare `SemaphoreSlim`) |
| TS-063 | ✅ DEVE | `SemaphoreSlim.WaitAsync()` DEVE ricevere `CancellationToken` (vedi [CANCELLATION_STANDARD](CANCELLATION_STANDARD.md)) |

### Regole per Proprieta

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| TS-070 | ❌ NON DEVE | Mai usare auto-property `{ get; set; }` per campi condivisi |
| TS-071 | ✅ DEVE | Esporre solo getter che usano `Volatile.Read` o `Interlocked.Read` |
| TS-072 | ⚠️ DOVREBBE | Usare metodi espliciti per modifiche (`RecordPacket()` invece di setter) |

---

## Esempi

### ✅ Uso Corretto - Contatori e Statistiche

```csharp
public sealed class ExampleStatistics : ILayerStatistics
{
    // Backing fields - sempre 'long' per compatibilita Interlocked
    private long _totalPackets;
    private long _errorCount;
    private long _bytesProcessed;
    
    // Proprieta pubbliche - sempre Volatile.Read
    public long TotalPackets => Volatile.Read(ref _totalPackets);
    public long ErrorCount => Volatile.Read(ref _errorCount);
    public long BytesProcessed => Volatile.Read(ref _bytesProcessed);
    
    // Metodi di aggiornamento - sempre Interlocked
    public void RecordPacket(int bytes)
    {
        Interlocked.Increment(ref _totalPackets);
        Interlocked.Add(ref _bytesProcessed, bytes);
    }
    
    public void RecordError() => Interlocked.Increment(ref _errorCount);
    
    public void Reset()
    {
        Interlocked.Exchange(ref _totalPackets, 0);
        Interlocked.Exchange(ref _errorCount, 0);
        Interlocked.Exchange(ref _bytesProcessed, 0);
    }
}
```

### ✅ Uso Corretto - DateTime come Ticks

```csharp
public class SessionMetrics
{
    private long _lastActivityTicks;
    private long _sessionStartTicks;
    
    public DateTime LastActivity 
    {
        get => new DateTime(Interlocked.Read(ref _lastActivityTicks));
        private set => Interlocked.Exchange(ref _lastActivityTicks, value.Ticks);
    }
    
    public DateTime SessionStart => new DateTime(Interlocked.Read(ref _sessionStartTicks));
    
    public TimeSpan SessionDuration
    {
        get
        {
            long nowTicks = DateTime.UtcNow.Ticks;
            long startTicks = Interlocked.Read(ref _sessionStartTicks);
            return TimeSpan.FromTicks(nowTicks - startTicks);
        }
    }
    
    public void UpdateActivity() => 
        Interlocked.Exchange(ref _lastActivityTicks, DateTime.UtcNow.Ticks);
    
    public void StartSession()
    {
        long now = DateTime.UtcNow.Ticks;
        Interlocked.Exchange(ref _sessionStartTicks, now);
        Interlocked.Exchange(ref _lastActivityTicks, now);
    }
}
```

### ✅ Uso Corretto - Booleani con Volatile

```csharp
public class ConnectionManager
{
    private bool _isConnected;
    private bool _isShuttingDown;
    
    public bool IsConnected => Volatile.Read(ref _isConnected);
    public bool IsShuttingDown => Volatile.Read(ref _isShuttingDown);
    
    public void MarkConnected() => Volatile.Write(ref _isConnected, true);
    
    public void Shutdown()
    {
        Volatile.Write(ref _isShuttingDown, true);
        Volatile.Write(ref _isConnected, false);
    }
}
```

### ✅ Uso Corretto - ConcurrentDictionary

```csharp
public class RoutingTableManager
{
    private readonly ConcurrentDictionary<int, RouteEntry> _routes = new();
    
    public bool AddRoute(int deviceId, RouteEntry entry) => 
        _routes.TryAdd(deviceId, entry);
    
    public bool TryGetRoute(int deviceId, out RouteEntry? entry) => 
        _routes.TryGetValue(deviceId, out entry);
    
    public RouteEntry AddOrUpdate(int deviceId, RouteEntry entry) =>
        _routes.AddOrUpdate(deviceId, entry, (key, existing) => entry);
}
```

### ✅ Uso Corretto - Lock per Operazioni Complesse

```csharp
public sealed class RouteMetrics
{
    private readonly Lock _lock = new();
    private int _hopCount;
    private double _reliability;
    private long _lastUpdateTicks;
    
    public void UpdateMetrics(int hopCount, double reliability)
    {
        lock (_lock)
        {
            _hopCount = hopCount;
            _reliability = reliability;
            _lastUpdateTicks = DateTime.UtcNow.Ticks;
        }
    }
    
    public RouteSnapshot GetSnapshot()
    {
        lock (_lock)
        {
            return new RouteSnapshot(_hopCount, _reliability, new DateTime(_lastUpdateTicks));
        }
    }
}

public readonly record struct RouteSnapshot(int HopCount, double Reliability, DateTime LastUpdate);
```

### ✅ Uso Corretto - SemaphoreSlim in Metodi Async

```csharp
private readonly SemaphoreSlim _semaphore = new(1, 1);

// ✅ DEVE passare CancellationToken (vedi CANCELLATION_STANDARD.md CT-011)
public async Task<bool> ProcessAsync(CancellationToken cancellationToken = default)
{
    await _semaphore.WaitAsync(cancellationToken);  // TS-063: CT obbligatorio
    try
    {
        await DoWorkAsync(cancellationToken);  // Propagare CT
        return true;
    }
    finally
    {
        _semaphore.Release();
    }
}
```

### ❌ Uso Scorretto - Operatori di Incremento

```csharp
// MAI fare questo
private int _counter;
public void Increment() => _counter++;  // NON ATOMICO - Race condition!
```

### ❌ Uso Scorretto - Auto-Property

```csharp
// MAI fare questo
public int PacketCount { get; set; }
PacketCount++;  // Race condition!
```

### ❌ Uso Scorretto - DateTime come Campo

```csharp
// MAI fare questo - DateTime non e atomico su 32-bit
private DateTime _lastSeen;
public DateTime LastSeen 
{ 
    get => _lastSeen;   // Lettura non atomica!
    set => _lastSeen = value;  // Scrittura non atomica!
}
```

### ❌ Uso Scorretto - Lock su Oggetto Pubblico

```csharp
// MAI fare questo
lock ("myLock") { ... }  // Stringa internata!
lock (this) { ... }      // Oggetto pubblico!
```

### ❌ Uso Scorretto - Lock in Metodi Async

```csharp
// MAI fare questo - lock non supporta await
public async Task<bool> ProcessAsync()
{
    lock (_lock)
    {
        await DoWorkAsync();  // Compile error!
    }
}
```

---

## Eccezioni

| Componente | Eccezione | Motivazione |
|------------|-----------|-------------|
| `readonly record struct` | Non richiede protezione | Immutabile per design |
| Campi `readonly` inizializzati nel costruttore | Non richiede protezione | Mai modificati dopo costruzione |
| Variabili locali | Non richiede protezione | Non condivise tra thread |
| Parametri di metodo | Non richiede protezione | Stack-local |

---

## Enforcement

- [ ] **Code Review:** Verificare assenza di `++`/`--`/`+=` su campi condivisi
- [ ] **Code Review:** Verificare che DateTime siano stored come `long` ticks
- [ ] **Code Review:** Verificare che `lock` usi oggetto `Lock` privato
- [ ] **Code Review:** Verificare assenza di `lock` in metodi async
- [ ] **Analyzer:** CA1501 - Avoid excessive inheritance (per Lock scope)
- [ ] **Test:** Test di concorrenza per ogni classe di statistiche

### Checklist Pre-Commit

- [ ] Contatori usano `Interlocked.Increment/Add`?
- [ ] Letture usano `Volatile.Read` o `Interlocked.Read`?
- [ ] DateTime stored come `long` ticks?
- [ ] Booleani usano `Volatile.Read/Write`?
- [ ] Collections usano `Concurrent*` o protezione `Lock`?
- [ ] Struct sono `readonly record struct` o immutabili?
- [ ] Lock usano oggetto `Lock` privato (.NET 10)?
- [ ] No operatori `++`, `--`, `+=` su campi condivisi?
- [ ] No auto-property `{ get; set; }` su campi condivisi?
- [ ] Esiste test di concorrenza per il componente?

---

## Testing Thread Safety

### Pattern di Test Standard

```csharp
[Fact]
public async Task DeviceMetrics_ConcurrentUpdates_ShouldBeCorrect()
{
    // Arrange
    var metrics = new DeviceMetrics();
    const int threadCount = 100;
    const int operationsPerThread = 1000;
    const int expectedTotal = threadCount * operationsPerThread;
    
    // Act - Esegui operazioni concorrenti
    var tasks = Enumerable.Range(0, threadCount)
        .Select(_ => Task.Run(() =>
        {
            for (int i = 0; i < operationsPerThread; i++)
            {
                metrics.RecordReceived();
                metrics.RecordSent();
            }
        }))
        .ToArray();
    
    await Task.WhenAll(tasks);
    
    // Assert - Verifica correttezza
    Assert.Equal(expectedTotal, metrics.PacketsReceived);
    Assert.Equal(expectedTotal, metrics.PacketsSent);
}
```

### Tool Consigliati

- **Deterministic Testing:** `Microsoft.Coyote` per test deterministici di race condition
- **Stress Testing:** Loop lunghi (5-10 secondi) con molti thread
- **Thread Sanitizer:** Esegui test con TSAN abilitato (Linux)

---

## Operazioni Interlocked Disponibili

| Operazione | Metodo | Uso |
|------------|--------|-----|
| Incremento atomico | `Interlocked.Increment(ref _counter)` | Contatori |
| Decremento atomico | `Interlocked.Decrement(ref _counter)` | Contatori |
| Somma atomica | `Interlocked.Add(ref _total, value)` | Aggregazioni |
| Assegnazione atomica | `Interlocked.Exchange(ref _value, newValue)` | DateTime, Reset |
| Compare-and-swap | `Interlocked.CompareExchange(ref _value, new, expected)` | State machine |
| Lettura atomica long | `Interlocked.Read(ref _longValue)` | DateTime a 64-bit |

---

## Riferimenti

- [Interlocked Class - Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/api/system.threading.interlocked)
- [Volatile Class - Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/api/system.threading.volatile)
- [ConcurrentDictionary - Microsoft Docs](https://learn.microsoft.com/en-us/dotnet/api/system.collections.concurrent.concurrentdictionary-2)
- [Lock Statement (.NET 10)](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/statements/lock)
- *C# 12 in a Nutshell* - Chapter 21: Concurrency & Asynchrony
- *Concurrent Programming on Windows* - Joe Duffy

### Issue Correlate

| Issue | Descrizione |
|-------|-------------|
| T-005 | Thread Safety Inconsistente (issue principale) |
| NL-004 | DeviceMetrics campi pubblici non thread-safe |
| NL-006 | UpdateRouteMetrics non atomico |
| SL-013 | SessionLayerStatistics proprieta non thread-safe |
| PR-014 | PresentationLayer timestamp non thread-safe |
| AL-016 | ApplicationLayer timestamp non thread-safe |
| PL-006 | PhysicalLayer buffer properties non thread-safe |

### Standard Correlati

| Standard | Relazione |
|----------|-----------|
| [CANCELLATION_STANDARD](CANCELLATION_STANDARD.md) | TS-063 richiede CT su SemaphoreSlim.WaitAsync() - vedi CT-011 |

---

## Changelog

| Data | Versione | Descrizione |
|------|----------|-------------|
| 2026-02-26 | 2.1 | Aggiunta regola TS-063 (SemaphoreSlim + CT), aggiornato esempio, cross-ref a CANCELLATION_STANDARD |
| 2026-02-12 | 2.0 | Allineamento a STANDARD_TEMPLATE.md, aggiunta sezione Regole con codici |
| 2026-02-03 | 1.0 | Versione iniziale come linee guida T-005 |

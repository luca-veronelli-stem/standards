# Standard Statistics - Sistema di Statistiche Unificato

> **Versione:** 2.0  
> **Data:** 2026-02-12  
> **Riferimento Issue:** T-004  
> **Stato:** Active

---

## Scopo

Questo standard definisce l'architettura e le regole per il sistema di statistiche unificato del protocollo STEM, garantendo:
- **Observability** completa su performance, throughput ed errori di tutti i layer
- **Diagnostica** rapida per identificazione di bottleneck e problemi
- **Production-Ready** con thread-safety e zero-allocation dove possibile
- **Consistency** tramite API uniforme tra tutti i layer

Si applica a: tutti i 7 layer dello stack protocollare e componenti che implementano `ILayerStatistics`.

---

## Principi Guida

1. **Interfaccia comune:** Tutti i layer DEVONO implementare `ILayerStatistics` per uniformita
2. **Thread-safety obbligatoria:** Tutte le operazioni su contatori e timestamp devono essere thread-safe
3. **Snapshot per export:** Usare `GetSnapshot()` per ottenere dati consistenti
4. **Registrazione automatica:** I layer registrano metriche durante le operazioni normali
5. **Null-safety:** `Statistics` puo essere null per retrocompatibilita

---

## Regole

### Implementazione ILayerStatistics

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| STAT-001 | ✅ DEVE | Ogni layer DEVE implementare `ILayerStatistics` |
| STAT-002 | ✅ DEVE | Implementare `LayerName`, `StartTime`, `Reset()`, `GetSnapshot()` |
| STAT-003 | ✅ DEVE | `GetSnapshot()` deve restituire uno snapshot atomico e consistente |
| STAT-004 | ⚠️ DOVREBBE | Esporre metriche specifiche per le responsabilita del layer |

### Thread Safety (Riferimento: THREAD_SAFETY_STANDARD.md)

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| STAT-010 | ✅ DEVE | Contatori: usare `Interlocked.Increment/Add/Exchange` |
| STAT-011 | ✅ DEVE | Letture: usare `Volatile.Read(ref field)` |
| STAT-012 | ✅ DEVE | Timestamp: memorizzare come `long` ticks con `Interlocked` |
| STAT-013 | ❌ NON DEVE | Mai usare `++`, `--`, `+=` su campi condivisi |

### Registrazione Metriche

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| STAT-020 | ✅ DEVE | Registrare sempre operazioni critiche (messaggi, errori) |
| STAT-021 | ⚠️ DOVREBBE | Registrare latenza per operazioni time-sensitive |
| STAT-022 | 💡 PUO | Calcolare rate e percentuali on-demand in `GetSnapshot()` |
| STAT-023 | ❌ NON DEVE | Mai disabilitare statistiche per "performance" (overhead minimo) |

### Accesso Statistiche

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| STAT-030 | ✅ DEVE | Usare null-conditional `_statistics?.RecordX()` |
| STAT-031 | ⚠️ DOVREBBE | Usare `GetSnapshot()` per export/logging |
| STAT-032 | ❌ NON DEVE | Mai leggere proprieta individuali in loop (inconsistente) |

---

## Architettura

### ILayerStatistics Interface

```csharp
public interface ILayerStatistics
{
    /// <summary>Nome del layer a cui appartengono queste statistiche.</summary>
    string LayerName { get; }

    /// <summary>Timestamp di quando le statistiche sono state resettate l'ultima volta.</summary>
    DateTime StartTime { get; }

    /// <summary>Calcola il tempo trascorso dall'ultimo reset.</summary>
    TimeSpan Uptime => DateTime.UtcNow - StartTime;

    /// <summary>Resetta tutte le statistiche ai valori iniziali.</summary>
    void Reset();

    /// <summary>
    /// Restituisce un snapshot delle statistiche correnti in formato dizionario.
    /// Utile per logging, export, o visualizzazione generica.
    /// </summary>
    Dictionary<string, object> GetSnapshot();
}
```

### Gerarchia Classi

```
ILayerStatistics (Interface)
    |
    +-- ApplicationLayerStatistics (L7)
    +-- PresentationLayerStatistics (L6)
    +-- SessionLayerStatistics (L5)
    +-- TransportLayerStatistics (L4)
    +-- NetworkLayerStatistics (L3) - Adapter per NetworkMetricsCollector
    +-- DataLinkLayerStatistics (L2)
    +-- PhysicalLayerStatistics (L1)
```

### Integrazione con IProtocolLayer

```csharp
public interface IProtocolLayer
{
    // ... altre proprieta ...
    
    /// <summary>
    /// Statistiche del layer per monitoring e diagnostica.
    /// Puo essere null se il layer non supporta statistiche.
    /// </summary>
    ILayerStatistics? Statistics { get; }
}
```

---

## Statistiche per Layer

### Layer 7 - Application

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `MessagesReceived` | Counter | Messaggi ricevuti |
| `MessagesSent` | Counter | Messaggi inviati |
| `CommandsProcessed` | Counter | Comandi processati per tipo |
| `HandlerErrors` | Counter | Errori handler |
| `AverageHandlerExecutionMs` | Gauge | Latenza media handler |

### Layer 6 - Presentation

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `DataEncrypted` | Counter | Operazioni crittografia |
| `DataDecrypted` | Counter | Operazioni decrittografia |
| `BytesEncrypted` | Counter | Byte crittografati |
| `EncryptionErrors` | Counter | Errori crittografia/padding |
| `AverageEncryptionTimeMs` | Gauge | Latenza media crypto |

### Layer 5 - Session

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `SessionsEstablished` | Counter | Sessioni stabilite |
| `SessionsClosed` | Counter | Sessioni chiuse |
| `HeartbeatsSent` | Counter | Heartbeat inviati |
| `SridMismatch` | Counter | SRID mismatch |
| `CurrentState` | State | Stato corrente sessione |

### Layer 4 - Transport

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `PacketsFragmented` | Counter | Pacchetti frammentati |
| `PacketsReassembled` | Counter | Pacchetti riassemblati |
| `ChunksCreated` | Counter | Chunk creati |
| `ReassemblyErrors` | Counter | Errori riassemblaggio |
| `ReassemblySuccessRate` | Gauge | Success rate % |

### Layer 3 - Network

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `TotalPacketsSent` | Counter | Pacchetti inviati (aggregate) |
| `TotalPacketsReceived` | Counter | Pacchetti ricevuti (aggregate) |
| `ActiveDevices` | Gauge | Dispositivi attivi |
| `AveragePacketLossRate` | Gauge | Tasso perdita medio |

**Nota:** NetworkLayer usa Adapter pattern per `NetworkMetricsCollector` esistente.

### Layer 2 - Data Link

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `FramesReceivedOk` | Counter | Frame ricevuti OK |
| `FramesSentOk` | Counter | Frame inviati OK |
| `CrcErrors` | Counter | Errori CRC |
| `ParseErrors` | Counter | Errori parsing |
| `CrcErrorRate` | Gauge | Error rate CRC % |

### Layer 1 - Physical

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `BytesWritten` | Counter | Byte scritti buffer TX |
| `BytesRead` | Counter | Byte letti buffer RX |
| `BufferOverflows` | Counter | Buffer overflow |
| `ChannelErrors` | Counter | Errori canale |
| `OverflowRate` | Gauge | Overflow rate % |

---

## Esempi

### ✅ Uso Corretto - Implementazione Statistics Thread-Safe

```csharp
public sealed class ExampleLayerStatistics : ILayerStatistics
{
    private long _messagesReceived;
    private long _startTimeTicks;
    
    public string LayerName => "Example";
    
    public DateTime StartTime => new(Interlocked.Read(ref _startTimeTicks));
    
    public long MessagesReceived => Volatile.Read(ref _messagesReceived);
    
    public void RecordMessageReceived()
    {
        Interlocked.Increment(ref _messagesReceived);
    }
    
    public void Reset()
    {
        Interlocked.Exchange(ref _messagesReceived, 0);
        Interlocked.Exchange(ref _startTimeTicks, DateTime.UtcNow.Ticks);
    }
    
    public Dictionary<string, object> GetSnapshot()
    {
        return new Dictionary<string, object>
        {
            ["LayerName"] = LayerName,
            ["StartTime"] = StartTime,
            ["Uptime"] = Uptime,
            ["MessagesReceived"] = Volatile.Read(ref _messagesReceived)
        };
    }
}
```

### ✅ Uso Corretto - Registrazione Automatica nel Layer

```csharp
public override async Task<LayerResult> ProcessUpstreamAsync(byte[] data, LayerContext context)
{
    var stopwatch = Stopwatch.StartNew();
    
    try
    {
        var message = Deserialize(data);
        _statistics?.RecordMessageReceived();
        
        var result = await ProcessCommand(message, context);
        
        _statistics?.RecordCommandProcessed(
            message.CommandId, 
            stopwatch.ElapsedMilliseconds);
        
        return result;
    }
    catch (Exception ex)
    {
        _statistics?.RecordDeserializationError();
        throw;
    }
}
```

### ✅ Uso Corretto - Export con GetSnapshot

```csharp
var snapshot = layer.Statistics?.GetSnapshot();
string json = JsonSerializer.Serialize(snapshot, new JsonSerializerOptions 
{ 
    WriteIndented = true 
});
_logger.LogInformation("Layer {Layer} metrics: {Snapshot}", layer.LayerName, json);
```

### ❌ Uso Scorretto - Contatori Non Thread-Safe

```csharp
// MAI fare questo
public void RecordMessageReceived()
{
    _messagesReceived++;  // Race condition!
}
```

### ❌ Uso Scorretto - Lettura Diretta

```csharp
// MAI fare questo
public long MessagesReceived => _messagesReceived;  // Puo leggere valore stale!
```

### ❌ Uso Scorretto - Letture Multiple in Loop

```csharp
// MAI fare questo - inconsistente
for (int i = 0; i < 100; i++)
{
    _logger.LogInformation("{Count}", stats.MessagesReceived);
}

// Usa invece GetSnapshot() per consistenza
var snapshot = stats.GetSnapshot();
```

---

## Pattern di Utilizzo

### Monitoring Loop

```csharp
public async Task MonitorLoopAsync(CancellationToken ct)
{
    while (!ct.IsCancellationRequested)
    {
        foreach (var layer in _layers)
        {
            if (layer.Statistics != null)
            {
                var snapshot = layer.Statistics.GetSnapshot();
                _logger.LogInformation("Layer {Layer} metrics: {@Metrics}", 
                    layer.LayerName, snapshot);
            }
        }
        await Task.Delay(TimeSpan.FromSeconds(30), ct);
    }
}
```

### Health Check

```csharp
public Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken ct)
{
    var stats = _appLayer.Statistics as ApplicationLayerStatistics;
    if (stats == null)
        return Task.FromResult(HealthCheckResult.Healthy());
    
    double errorRate = stats.HandlerErrors / (double)stats.CommandsProcessed;
    if (errorRate > 0.05)
        return Task.FromResult(HealthCheckResult.Unhealthy($"High error rate: {errorRate:P2}"));
    
    if (stats.AverageHandlerExecutionMs > 100)
        return Task.FromResult(HealthCheckResult.Degraded($"High latency: {stats.AverageHandlerExecutionMs}ms"));
    
    return Task.FromResult(HealthCheckResult.Healthy($"Processed {stats.CommandsProcessed} commands"));
}
```

### Bottleneck Analyzer

```csharp
public string? IdentifyBottleneck(IProtocolLayer[] layers)
{
    if (layers.FirstOrDefault(l => l.LayerLevel == 7)?.Statistics 
        is ApplicationLayerStatistics appStats && appStats.AverageHandlerExecutionMs > 50)
        return "Application: Slow command handlers";
    
    if (layers.FirstOrDefault(l => l.LayerLevel == 6)?.Statistics 
        is PresentationLayerStatistics presStats && presStats.AverageEncryptionTimeMs > 10)
        return "Presentation: Slow encryption";
    
    if (layers.FirstOrDefault(l => l.LayerLevel == 4)?.Statistics 
        is TransportLayerStatistics transStats && transStats.ReassemblySuccessRate < 0.90)
        return "Transport: High reassembly failure rate";
    
    if (layers.FirstOrDefault(l => l.LayerLevel == 2)?.Statistics 
        is DataLinkLayerStatistics dlStats && dlStats.CrcErrorRate > 0.01)
        return "DataLink: High CRC error rate";
    
    if (layers.FirstOrDefault(l => l.LayerLevel == 1)?.Statistics 
        is PhysicalLayerStatistics physStats && physStats.OverflowRate > 0.05)
        return "Physical: Buffer overflows";
    
    return null;
}
```

---

## Eccezioni

| Componente | Eccezione | Motivazione |
|------------|-----------|-------------|
| `NetworkLayerStatistics` | Adapter pattern | Retrocompatibilita con `NetworkMetricsCollector` esistente |
| Layer senza stato | `Statistics` puo essere null | Retrocompatibilita |

---

## Enforcement

- [ ] **Code Review:** Verificare che nuove statistiche seguano pattern thread-safe
- [ ] **Code Review:** Verificare implementazione `ILayerStatistics`
- [ ] **Test:** Test di concorrenza per ogni classe statistics
- [ ] **Test:** Verificare `GetSnapshot()` restituisce dati consistenti

---

## Riferimenti

- `Protocol/Layers/Base/IProtocolLayer.cs` - Interface layer
- `Protocol/Layers/Base/ILayerStatistics.cs` - Interface statistics
- `THREAD_SAFETY_STANDARD.md` - Pattern thread-safety
- [Microsoft Health Checks](https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks)

### File Implementazione

| Layer | File |
|-------|------|
| Application | `Protocol/Layers/ApplicationLayer/Models/ApplicationLayerStatistics.cs` |
| Presentation | `Protocol/Layers/PresentationLayer/Models/PresentationLayerStatistics.cs` |
| Session | `Protocol/Layers/SessionLayer/Models/SessionLayerStatistics.cs` |
| Transport | `Protocol/Layers/TransportLayer/Models/TransportLayerStatistics.cs` |
| Network | `Protocol/Layers/NetworkLayer/Models/NetworkLayerStatistics.cs` |
| Data Link | `Protocol/Layers/DataLinkLayer/Models/DataLinkLayerStatistics.cs` |
| Physical | `Protocol/Layers/PhysicalLayer/Models/PhysicalLayerStatistics.cs` |

---

## Changelog

| Data | Versione | Descrizione |
|------|----------|-------------|
| 2026-02-12 | 2.0 | Allineamento a STANDARD_TEMPLATE.md, aggiunta sezione Regole con codici |
| 2026-01-29 | 1.0 | Versione iniziale - documentazione sistema statistiche T-004 |

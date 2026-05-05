# NetworkLayer - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunità di refactoring e violazioni di best practice per il componente **NetworkLayer**.

> **Ultimo aggiornamento:** 2026-02-12

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 0 | 4 |
| **Media** | 2 | 3 |
| **Bassa** | 10 | 1 |

**Totale aperte:** 12  
**Totale risolte:** 8

---

## Issue Trasversali Correlate

| ID | Titolo | Status | Impatto su NetworkLayer |
|----|--------|--------|-------------------------|
| **T-013** | Lifecycle Helper: Costruttore vs InitializeAsync | Aperto | Tutti gli helper creati nel costruttore con default, config ignorata |

→ [Protocol/ISSUES.md](../../ISSUES.md) per dettagli completi.

---

## Indice Issue Aperte

- [NL-007 - Export CSV Non Implementato in NetworkMetricsCollector](#nl-007--export-csv-non-implementato-in-networkmetricscollector)
- [NL-018 - BroadcastManager Clear() Non Atomico](#nl-018--broadcastmanager-clear-non-atomico)
- [NL-008 - PacketForwarder Doppio Rate Limiting Ridondante](#nl-008--packetforwarder-doppio-rate-limiting-ridondante)
- [NL-009 - DeviceInfo e RouteInfo Non Sono Immutabili](#nl-009--deviceinfo-e-routeinfo-non-sono-immutabili)
- [NL-010 - Costante DEVICE_DISCOVERY_INTERVAL_SECONDS Usata Come Timeout](#nl-010--costante-device_discovery_interval_seconds-usata-come-timeout)
- [NL-012 - DeviceDiscoveryService Non Valida Input](#nl-012--devicediscoveryservice-non-valida-input)
- [NL-013 - PacketForwarder Lista Latenze O(n)](#nl-013--packetforwarder-lista-latenze-on)
- [NL-014 - RoutingTableManager CleanupExpiredRoutes LINQ Inefficiente](#nl-014--routingtablemanager-cleanupexpiredroutes-linq-inefficiente)
- [NL-015 - NetworkMetricsCollector RecordLatency RemoveAt O(n)](#nl-015--networkmetricscollector-recordlatency-removeat-on)
- [NL-016 - NetworkLayerStatistics Computed Properties Overhead](#nl-016--networklayerstatistics-computed-properties-overhead)
- [NL-019 - RouteMetrics Campi Non Thread-Safe](#nl-019--routemetrics-campi-non-thread-safe)
- [NL-020 - NetworkLayer AddRoute Non Propaga linkQuality](#nl-020--networklayer-addroute-non-propaga-linkquality)

## Indice Issue Risolte

- [NL-021 - RoutingTableManager Commenti in Inglese](#nl-021--routingtablemanager-commenti-in-inglese)
- [NL-017 - Extended ID CAN Non Propagato come DestinationId](#nl-017--extended-id-can-non-propagato-come-destinationid)
- [NL-006 - RoutingTableManager UpdateRouteMetrics Non Thread-Safe](#nl-006--routingtablemanager-updateroutemetrics-non-thread-safe)
- [NL-005 - BroadcastManager GenerateBroadcastId Hash Non Robusto](#nl-005--broadcastmanager-generatebroadcastid-hash-non-robusto)
- [NL-004 - DeviceMetrics Campi Public Non Thread-Safe](#nl-004--devicemetrics-campi-public-non-thread-safe)
- [NL-003 - RouteCalculator Crea Random Per Ogni Chiamata](#nl-003--routecalculator-crea-random-per-ogni-chiamata)
- [NL-001 - PacketForwarder Loop Infinito Senza Cancellation](#nl-001--packetforwarder-loop-infinito-senza-cancellation)
- [NL-002 - NetworkLayer Non Implementa IDisposable](#nl-002--networklayer-non-implementa-idisposable)

---

## Priorità Critica

(Nessuna issue critica aperta)

---

## Priorità Alta

(Nessuna issue alta aperta - tutte risolte)

---

## Priorità Media

### NL-007 - Export CSV Non Implementato in NetworkMetricsCollector

**Categoria:** Design  
**Priorità:** Media  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-06  

#### Descrizione

L'enum `MetricsFormat` dichiara `Json` e `Csv`, ma il metodo `ExportMetrics()` tratta entrambi come JSON. L'export CSV non è implementato.

#### File Coinvolti

- `Protocol/Layers/NetworkLayer/Helpers/NetworkMetricsCollector.cs` (righe 220-229)
- `Protocol/Layers/NetworkLayer/Enums/MetricsFormat.cs`

#### Codice Problematico

```csharp
public string ExportMetrics(MetricsFormat format)
{
    var allMetrics = GetAllMetrics();

    return format switch
    {
        MetricsFormat.Json => JsonSerializer.Serialize(allMetrics, CachedIndentedJsonOptions),
        _ => JsonSerializer.Serialize(allMetrics)  // CSV trattato come JSON
    };
}
```

#### Problema Specifico

- L'API dichiara supporto CSV ma non lo implementa
- Chiamate con `MetricsFormat.Csv` restituiscono JSON silenziosamente
- Violazione del principio di least surprise

#### Soluzione Proposta

```csharp
public string ExportMetrics(MetricsFormat format)
{
    var allMetrics = GetAllMetrics();

    return format switch
    {
        MetricsFormat.Json => JsonSerializer.Serialize(allMetrics, CachedIndentedJsonOptions),
        MetricsFormat.Csv => ExportAsCsv(allMetrics),
        _ => throw new ArgumentOutOfRangeException(nameof(format), $"Formato non supportato: {format}")
    };
}

private static string ExportAsCsv(IReadOnlyDictionary<uint, RouteMetrics> metrics)
{
    var sb = new StringBuilder();
    sb.AppendLine("DeviceId,LinkQuality,Latency,PacketsSent,PacketsReceived,PacketsLost,AverageLatencyMs");
    
    foreach (var kvp in metrics)
    {
        var m = kvp.Value;
        sb.AppendLine($"0x{kvp.Key:X8},{m.LinkQuality:F3},{m.Latency},{m.PacketsSent},{m.PacketsReceived},{m.PacketsLost},{m.AverageLatencyMs}");
    }
    
    return sb.ToString();
}
```

#### Benefici Attesi

- API completa e coerente
- Export CSV funzionante
- Eccezione chiara per formati non supportati

---

### NL-018 - BroadcastManager Clear() Non Atomico

**Categoria:** Bug  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-02-06  

#### Descrizione

I contatori `_totalProcessed` e `_duplicatesRejected` in `BroadcastManager` sono incrementati con `Interlocked.Increment()`, ma nel metodo `Clear()` vengono resettati con assegnazione diretta, non atomica rispetto agli incrementi concorrenti.

#### File Coinvolti

- `Protocol/Layers/NetworkLayer/Helpers/BroadcastManager.cs` (righe 27-28, 136-141)

#### Codice Problematico

```csharp
private int _totalProcessed;
private int _duplicatesRejected;

public void Clear()
{
    _processedBroadcasts.Clear();
    _totalProcessed = 0;         // Non atomico rispetto a Interlocked.Increment
    _duplicatesRejected = 0;     // Non atomico rispetto a Interlocked.Increment
}
```

#### Problema Specifico

- Race condition durante Clear() mentre altri thread incrementano i contatori
- Statistiche potenzialmente incorrette

#### Soluzione Proposta

```csharp
public void Clear()
{
    _processedBroadcasts.Clear();
    Interlocked.Exchange(ref _totalProcessed, 0);
    Interlocked.Exchange(ref _duplicatesRejected, 0);
}
```

#### Benefici Attesi

- Thread-safety garantita
- Consistenza con pattern Interlocked usato altrove

---

## Priorità Bassa

### NL-008 - PacketForwarder Doppio Rate Limiting Ridondante

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-02-06  

#### Descrizione

`ForwardPacketAsync()` implementa due meccanismi di rate limiting che si sovrappongono: sliding window manuale con `_recentForwards` e `SemaphoreSlim` con refresh ogni secondo.

#### File Coinvolti

- `Protocol/Layers/NetworkLayer/Helpers/PacketForwarder.cs` (righe 77-107)

#### Problema Specifico

- Doppio controllo ridondante
- Logica duplicata
- Overhead non necessario

#### Soluzione Proposta

Mantenere solo `SemaphoreSlim` (più semplice) o solo sliding window (più preciso).

#### Benefici Attesi

- Codice più semplice
- Meno overhead
- Comportamento più prevedibile

---

### NL-009 - DeviceInfo e RouteInfo Non Sono Immutabili

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-06  

#### Descrizione

Le classi `DeviceInfo` e `RouteInfo` sono mutabili con setter pubblici. Modifiche esterne possono corrompere lo stato interno dei manager.

#### File Coinvolti

- `Protocol/Layers/NetworkLayer/Models/DeviceInfo.cs`
- `Protocol/Layers/NetworkLayer/Models/RouteInfo.cs`

#### Soluzione Proposta

Convertire in record con `init` setters.

#### Benefici Attesi

- Immutabilità garantita
- Thread-safety migliorata

---

### NL-010 - Costante DEVICE_DISCOVERY_INTERVAL_SECONDS Usata Come Timeout

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-06  

#### Descrizione

La costante `DEVICE_DISCOVERY_INTERVAL_SECONDS` viene usata come timeout per considerare un device offline, non come intervallo di discovery.

#### File Coinvolti

- `Protocol/Layers/NetworkLayer/Models/NetworkLayerConstants.cs` (riga 18)
- `Protocol/Layers/NetworkLayer/Helpers/DeviceDiscoveryService.cs` (riga 24)

#### Soluzione Proposta

Rinominare in `DEVICE_TIMEOUT_SECONDS` e creare costante separata per intervallo discovery.

#### Benefici Attesi

- Naming semanticamente corretto

---

### NL-012 - DeviceDiscoveryService Non Valida Input

**Categoria:** Bug  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-06  

#### Descrizione

`RegisterDevice()` non valida che `deviceId != 0`. Un device con ID 0 potrebbe essere registrato.

#### File Coinvolti

- `Protocol/Layers/NetworkLayer/Helpers/DeviceDiscoveryService.cs` (righe 42-70)

#### Soluzione Proposta

Aggiungere validazione `if (deviceId == 0) return false;` all'inizio del metodo.

#### Benefici Attesi

- Prevenzione bug sottili
- Stato discovery sempre valido

---

### NL-013 - PacketForwarder Lista Latenze O(n)

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-06  

#### Descrizione

La lista `_latencies` usa `RemoveAt(0)` che è O(n) per ogni rimozione.

#### File Coinvolti

- `Protocol/Layers/NetworkLayer/Helpers/PacketForwarder.cs` (righe 128-133)

#### Soluzione Proposta

Usare `LinkedList<double>` per O(1) su rimozione.

#### Benefici Attesi

- Performance O(1) per inserimento/rimozione

---

### NL-014 - RoutingTableManager CleanupExpiredRoutes LINQ Inefficiente

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-06  

#### Descrizione

Il metodo `CleanupExpiredRoutes()` usa LINQ chain che crea lista intermedia.

#### File Coinvolti

- `Protocol/Layers/NetworkLayer/Helpers/RoutingTableManager.cs` (righe 146-168)

#### Soluzione Proposta

Iterare direttamente senza allocazione lista.

#### Benefici Attesi

- Zero allocazioni intermedie

---

### NL-015 - NetworkMetricsCollector RecordLatency RemoveAt O(n)

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-06  

#### Descrizione

`RecordLatency()` usa `List<int>.RemoveAt(0)` che è O(n).

#### File Coinvolti

- `Protocol/Layers/NetworkLayer/Helpers/NetworkMetricsCollector.cs` (righe 60-75)

#### Soluzione Proposta

Usare `Queue<int>` per FIFO naturale O(1).

#### Benefici Attesi

- Performance costante

---

### NL-016 - NetworkLayerStatistics Computed Properties Overhead

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-06  

#### Descrizione

Le proprietà computed chiamano `GetAggregateStatistics()` multiple volte se accedute in sequenza.

#### File Coinvolti

- `Protocol/Layers/NetworkLayer/Models/NetworkLayerStatistics.cs` (righe 49-87)

#### Soluzione Proposta

Implementare caching con invalidazione temporale (100ms).

#### Benefici Attesi

- Una sola aggregazione per accesso multiplo

---

### NL-019 - RouteMetrics Campi Non Thread-Safe

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-06  

#### Descrizione

La classe `RouteMetrics` ha proprietà pubbliche con setter che non seguono il pattern T-005.

#### File Coinvolti

- `Protocol/Layers/NetworkLayer/Models/RouteMetrics.cs`

#### Soluzione Proposta

Convertire i contatori in campi `long` con `Interlocked`.

#### Benefici Attesi

- Conformità a T-005

---

### NL-020 - NetworkLayer AddRoute Non Propaga linkQuality

**Categoria:** API  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-06  

#### Descrizione

Il metodo pubblico `AddRoute()` non espone il parametro `linkQuality` disponibile in `RoutingTableManager`.

#### File Coinvolti

- `Protocol/Layers/NetworkLayer/NetworkLayer.cs` (righe 318-327)

#### Soluzione Proposta

Aggiungere parametro opzionale `double linkQuality = 1.0`.

#### Benefici Attesi

- API completa

---

## Issue Risolte

### NL-021 - RoutingTableManager Commenti in Inglese

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** ✅ Risolto  
**Data Apertura:** 2026-02-06  
**Data Risoluzione:** 2026-02-12  
**Branch:** fix/t-018

#### Descrizione

Diversi commenti erano in inglese invece che in italiano come richiesto dallo standard.

#### Soluzione Implementata

Tutti i commenti nel NetworkLayer sono stati allineati allo standard `STANDARD_COMMENTS.md` v1.1:
- Commenti tradotti in italiano
- XML docs allineati alle regole R-005/R-006
- Parte dell'operazione globale T-018

#### File Modificati

- `Protocol/Layers/NetworkLayer/Helpers/RoutingTableManager.cs`
- Tutti gli altri file del NetworkLayer

---

### NL-017 - Extended ID CAN Non Propagato come DestinationId

**Categoria:** Bug  
**Priorità:** Alta  
**Impatto:** Critico  
**Status:** Risolto  
**Data Apertura:** 2026-02-01  
**Data Risoluzione:** 2026-02-04  
**Branch:** fix/nl-017  

#### Descrizione

L'Extended ID CAN (`0x1FFFFFFF` = `SRID_BROADCAST`) non veniva propagato attraverso i layer, impedendo il riconoscimento dei broadcast.

#### Soluzione Implementata

**Modifiche Effettuate:**

1. **File `IChannelDriver.cs`:**
   - Aggiunto metodo `ReadWithMetadataAsync()`

2. **File `CanChannelDriver.cs`:**
   - Implementato `ReadWithMetadataAsync()` con Extended ID in metadata

3. **File `PhysicalLayer.cs`:**
   - Usa `ReadWithMetadataAsync()` e propaga `DestinationId`

#### Test Aggiunti

**Unit Tests:**
- `CanChannelDriverTests`: 4 nuovi test per `ReadWithMetadataAsync`
- `PhysicalLayerTests`: 2 nuovi test per propagazione `DestinationId`

#### Benefici Ottenuti

- Extended ID CAN propagato correttamente
- Broadcast riconosciuto
- Backward compatibility mantenuta

---

### NL-006 - RoutingTableManager UpdateRouteMetrics Non Thread-Safe

**Categoria:** Bug  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-25  
**Data Risoluzione:** 2026-02-03  
**Branch:** fix/t-005  

#### Descrizione

`RouteInfo.LastUpdated` era un DateTime non atomico.

#### Soluzione Implementata

**Modifiche Effettuate:**

1. **File `RouteInfo.cs`:**
   - `LastUpdated` convertito in `long` Ticks con `Interlocked`

#### Benefici Ottenuti

- DateTime LastUpdated thread-safe
- Conforme a T-005

---

### NL-005 - BroadcastManager GenerateBroadcastId Hash Non Robusto

**Categoria:** Bug  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-25  
**Data Risoluzione:** 2026-02-03  
**Branch:** fix/t-005  

#### Descrizione

Il metodo `GenerateBroadcastId()` generava hash con collisioni probabili.

#### Soluzione Implementata

Eliminato `GenerateBroadcastId()`. Ora usa chiave diretta `senderId` con timestamp stored come `long` Ticks.

#### Benefici Ottenuti

- Zero collisioni hash
- Thread-safe
- Più semplice
- Conforme a T-005

---

### NL-004 - DeviceMetrics Campi Public Non Thread-Safe

**Categoria:** Bug  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-25  
**Data Risoluzione:** 2026-02-03  
**Branch:** fix/t-005  

#### Descrizione

La classe `DeviceMetrics` aveva proprietà DateTime non atomiche e campi pubblici modificati senza garanzia di thread-safety.

#### Soluzione Implementata

**Modifiche Effettuate:**

1. **File `DeviceMetrics.cs`:**
   - DateTime convertiti in `long` Ticks con `Interlocked`
   - Pattern T-005 applicato

#### Benefici Ottenuti

- DateTime thread-safe (nessun torn read)
- Pattern `Interlocked` consolidato
- Conforme a T-005

---

### NL-003 - RouteCalculator Crea Random Per Ogni Chiamata

**Categoria:** Bug  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-01-20  
**Data Risoluzione:** 2026-01-30  
**Branch:** fix/nl-003  

#### Descrizione

`CalculateLoadBalancedPath()` creava una nuova istanza di `Random` ad ogni chiamata, causando distribuzione non uniforme del load balancing.

#### Soluzione Implementata

Sostituito con `Random.Shared` (thread-safe in .NET 6+).

#### Benefici Ottenuti

- Zero allocazioni per chiamata
- Distribuzione veramente casuale
- Thread-safe

---

### NL-001 - PacketForwarder Loop Infinito Senza Cancellation

**Categoria:** Bug  
**Priorità:** Alta  
**Impatto:** Critico  
**Status:** Risolto  
**Data Apertura:** 2026-01-15  
**Data Risoluzione:** 2026-01-28  
**Branch:** fix/nl-001  

#### Descrizione

Il metodo `StartRateLimiterRefresh()` avviava un `Task.Run` con un loop `while (true)` che non poteva mai terminare. Non esisteva alcun meccanismo per cancellare questo task durante lo shutdown.

#### File Coinvolti

- `Protocol/Layers/NetworkLayer/Helpers/PacketForwarder.cs`

#### Soluzione Implementata

**Modifiche Effettuate:**

1. **File `PacketForwarder.cs`:**
   - Implementato `IDisposable`
   - Aggiunto `CancellationTokenSource` per cancellazione graceful
   - Modificato loop: `while (!cancellationToken.IsCancellationRequested)`
   - Implementato `Dispose()` con timeout 2 secondi

#### Test Aggiunti

**Unit Tests - `PacketForwarderTests.cs` (4 test):**
- `Dispose_ShouldStopRefreshTask`
- `Dispose_MultipleCalls_ShouldNotThrow`
- `Dispose_ShouldTerminateRefreshTaskWithinTimeout`
- `Dispose_AfterForwarding_ShouldNotAffectPreviousOperations`

#### Benefici Ottenuti

- Shutdown graceful del thread di refresh
- Nessun memory leak
- Cooperative cancellation pattern

---

### NL-002 - NetworkLayer Non Implementa IDisposable

**Categoria:** Bug  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-01-15  
**Data Risoluzione:** 2026-01-28  
**Branch:** fix/t-001  

#### Descrizione

`NetworkLayer` non implementava `IDisposable`, causando resource leak e eventi non disconnessi.

#### Soluzione Implementata

`NetworkLayer` ora eredita da `ProtocolLayerBase` che implementa `IDisposable`. Gli event handlers vengono disconnessi in `DisposeResources()`.

Vedi issue trasversale T-001 in Protocol/ISSUES.md.

#### Benefici Ottenuti

- Nessun memory leak eventi
- Cleanup corretto delle tabelle

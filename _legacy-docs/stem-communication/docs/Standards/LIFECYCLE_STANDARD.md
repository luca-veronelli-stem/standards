# Standard Helper Lifecycle - Costruttore vs InitializeAsync

> **Versione:** 2.0  
> **Data:** 2026-02-18  
> **Riferimento Issue:** T-013, T-006  
> **Stato:** Active

---

## Scopo

Questo standard definisce le regole per decidere **cosa** deve essere creato/inizializzato nel costruttore di un layer vs cosa in `InitializeAsync()`, e come gestire il ciclo di vita completo degli helper, garantendo:

- **Consistenza** nella gestione del ciclo di vita degli helper
- **Correttezza** nell'applicazione della configurazione utente
- **Testabilità** tramite dependency injection
- **Riutilizzabilità** tramite `UninitializeAsync()` e re-inizializzazione

Si applica a: tutti i layer del protocollo con helper configurabili.

---

## Principi Guida

1. **Configurazione applicata:** Gli helper che dipendono dalla configurazione DEVONO riceverla effettivamente
2. **DI-friendly:** Gli helper iniettati dall'esterno DEVONO essere rispettati, non sovrascritti
3. **Fail-fast:** L'uso di metodi che richiedono inizializzazione DEVE fallire esplicitamente se non inizializzati
4. **Ownership chiara:** Ogni helper deve avere un owner chiaro (layer o DI container)
5. **Semplicità:** Preferire la soluzione più semplice che soddisfa i requisiti

---

## Regole

### Creazione Helper

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| HL-001 | ✅ DEVE | Helper che richiedono config → creare in `InitializeAsync()` |
| HL-002 | ✅ DEVE | Helper passati via DI → rispettare quelli esterni, non sovrascrivere |
| HL-003 | ✅ DEVE | Helper stateless/immutabili → creare nel costruttore |
| HL-004 | ⚠️ DOVREBBE | Helper che richiedono cleanup → creare nel costruttore (tracciabilità dispose) |
| HL-005 | ❌ NON DEVE | Mai creare helper con config default nel costruttore se la config è usata |

### Inizializzazione Guard

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| HL-010 | ✅ DEVE | Metodi pubblici che usano helper configurabili → chiamare `EnsureInitialized()` |
| HL-011 | ⚠️ DOVREBBE | `EnsureInitialized()` → lanciare `InvalidOperationException` se non inizializzato |
| HL-012 | 💡 PUÒ | Helper nullable con `!` assertion se guard presente all'inizio del metodo |

### Storage Configurazione

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| HL-020 | ⚠️ DOVREBBE | Config usata solo in init → non salvare, usare campi separati |
| HL-021 | ⚠️ DOVREBBE | Config usata a runtime → salvare `_config` completa |
| HL-022 | 💡 PUÒ | Pochi parametri (2-3) → preferire campi separati per chiarezza |

### Criteri di Decisione

| Criterio | Costruttore | InitializeAsync |
|----------|:-----------:|:---------------:|
| Non richiede config | ✅ | |
| Richiede config | | ✅ |
| Passato via DI (testing) | ✅ | |
| Stateless/immutabile | ✅ | |
| Richiede cleanup in Dispose | ✅ | |
| Può essere ricreato | | ✅ |

### Helper Ownership (T-006)

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| HL-030 | ✅ DEVE | Helper creati internamente (owned) → resettare in `ResetStateAsync()` |
| HL-031 | ✅ DEVE | Helper iniettati via DI (borrowed) → NON toccare in `ResetStateAsync()` |
| HL-032 | ✅ DEVE | Helper owned → disporre in `DisposeResources()` |
| HL-033 | ❌ NON DEVE | Helper borrowed → NON disporre (responsabilità del DI container) |

### UninitializeAsync e Reset

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| HL-040 | ✅ DEVE | `ResetStateAsync()` → pulire stato interno per permettere re-init |
| HL-041 | ✅ DEVE | `ResetStateAsync()` → chiamare `Clear()` o `Reset()` su helper owned |
| HL-042 | ❌ NON DEVE | `ResetStateAsync()` → NON disporre risorse (usare `DisposeResources()`) |
| HL-043 | ⚠️ DOVREBBE | Helper con stato → implementare metodo `Clear()` o `Reset()` |

---

## Esempi

### ✅ Uso Corretto - Helper creato in InitializeAsync

```csharp
public class NetworkLayer : ProtocolLayerBase
{
    private RoutingTableManager? _routingTableManager;
    private readonly bool _internalHelpers;

    // Costruttore default - helper creati internamente
    public NetworkLayer(ILogger<NetworkLayer>? logger = null) : base(logger)
    {
        _internalHelpers = true;
    }

    // Costruttore DI - helper esterni rispettati
    public NetworkLayer(RoutingTableManager rtm, ILogger<NetworkLayer>? logger = null) 
        : base(logger)
    {
        _routingTableManager = rtm;
        _internalHelpers = false;
    }

    public override Task<bool> InitializeAsync(LayerConfiguration? config)
    {
        var cfg = config as NetworkLayerConfiguration ?? new();
        cfg.Validate();
        
        // Helper creato con config SOLO se interno
        if (_internalHelpers)
        {
            _routingTableManager = new RoutingTableManager(_logger, cfg.RoutingTableTimeout);
        }
        
        return base.InitializeAsync(config);
    }
}
```

### ✅ Uso Corretto - Guard EnsureInitialized

```csharp
public LayerResult ProcessPacket(byte[] data)
{
    EnsureInitialized();  // Lancia se non inizializzato
    
    // Ora _routingTableManager è garantito non-null
    return _routingTableManager!.FindRoute(data);
}

private void EnsureInitialized()
{
    if (!IsInitialized)
        throw new InvalidOperationException(
            "Layer not initialized. Call InitializeAsync() first.");
}
```

### ✅ Uso Corretto - Helper stateless nel costruttore

```csharp
public class ApplicationLayer : ProtocolLayerBase
{
    private readonly ApplicationLayerStatistics _statistics;  // Stateless, no config
    private readonly CommandHandlerRegistry? _registry;       // Passato via DI
    
    public ApplicationLayer(
        CommandHandlerRegistry? registry = null,
        ILogger<ApplicationLayer>? logger = null) : base(logger)
    {
        _statistics = new ApplicationLayerStatistics();  // ✅ OK - stateless
        _registry = registry;                             // ✅ OK - rispetta DI
    }
}
```

### ❌ Uso Scorretto - Config ignorata

```csharp
public class NetworkLayer : ProtocolLayerBase
{
    private readonly RoutingTableManager _routingTableManager;

    public NetworkLayer(ILogger<NetworkLayer>? logger = null) : base(logger)
    {
        // ❌ BUG: Helper creato con DEFAULT, config utente ignorata!
        _routingTableManager = new RoutingTableManager(_logger);
    }

    public override Task<bool> InitializeAsync(LayerConfiguration? config)
    {
        var cfg = config as NetworkLayerConfiguration ?? new();
        // cfg.RoutingTableTimeout = 1 ora... ma _routingTableManager usa 600s default!
        return base.InitializeAsync(config);
    }
}
```

### ❌ Uso Scorretto - Helper DI sovrascritto

```csharp
public override Task<bool> InitializeAsync(LayerConfiguration? config)
{
    // ❌ BUG: Sovrascrive helper passato via DI!
    _routingTableManager = new RoutingTableManager(_logger, cfg.Timeout);
    return base.InitializeAsync(config);
}
```

---

## Stato Attuale per Layer

### Layer Conformi

| Layer | Helper | Pattern | Stato |
|-------|--------|---------|-------|
| **SessionLayer** | `SessionManager` | Creato in InitializeAsync | ✅ Conforme |
| **PresentationLayer** | `CryptoProvider` | Costruttore + `SetKey()` | ✅ Conforme |
| **ApplicationLayer** | `CommandHandlerRegistry` | DI esterno rispettato | ✅ Conforme |

### Layer da Correggere

| Layer | Helper | Problema | Issue |
|-------|--------|----------|-------|
| **NetworkLayer** | `RoutingTableManager` | Config ignorata | Da fixare |
| **NetworkLayer** | `BroadcastManager` | Config ignorata | Da fixare |
| **NetworkLayer** | `DeviceDiscoveryService` | Config ignorata | Da fixare |
| **NetworkLayer** | `RouteCalculator` | Config ignorata | Da fixare |
| **NetworkLayer** | `PacketForwarder` | Config ignorata | Da fixare |
| **NetworkLayer** | `NetworkMetricsCollector` | Config ignorata | Da fixare |
| **TransportLayer** | `ChunkReassembler` | `ReassemblyTimeout` non applicato | Da fixare |

---

## Strategie Alternative

Per casi specifici, sono accettabili strategie alternative:

### B) Helper con metodo Configure()

```csharp
public class RoutingTableManager
{
    public void Configure(TimeSpan timeout) => _routeTimeout = timeout;
}
// In InitializeAsync: _routingTableManager.Configure(cfg.Timeout);
```

**Quando usare:** Helper esistenti difficili da rifattorizzare, nessuna race condition.

### C) Helper con Func&lt;T&gt; per config

```csharp
public RoutingTableManager(Func<TimeSpan> getTimeout) => _getTimeout = getTimeout;
```

**Quando usare:** Supporto hot-reload configurazione.

### D) Factory pattern

```csharp
_routingTableManager = _factory.CreateRoutingTableManager(cfg);
```

**Quando usare:** Scenari DI complessi, testing avanzato.

---

## Eccezioni

| Componente | Eccezione | Motivazione |
|------------|-----------|-------------|
| `PhysicalLayer` | Campi separati per timeout | Solo 2 parametri, semplicità |
| `DataLinkLayer` | Nessun salvataggio config | Non ha helper configurabili |
| `PresentationLayer` | `SetKey()` post-costruttore | Pattern crittografico standard |

---

## Enforcement

- [ ] **Code Review:** Verificare che helper configurabili siano creati in InitializeAsync
- [ ] **Code Review:** Verificare presenza di `EnsureInitialized()` guard
- [ ] **Test:** Ogni layer deve avere test che verifica applicazione config personalizzata

---

## Riferimenti

- `Protocol/Layers/Base/ProtocolLayerBase.cs` - Classe base layer
- `Protocol/Layers/*/Configuration/` - Classi configurazione per layer
- `Docs/Standards/THREAD_SAFETY_STANDARD.md` - Per helper thread-safe

---

## Changelog

| Data | Versione | Descrizione |
|------|----------|-------------|
| 2026-02-18 | 2.0 | Aggiunto regole HL-030..043 per ownership e UninitializeAsync (T-006) |
| 2026-02-13 | 1.0 | Conversione da issue T-013 a standard attivo |
| 2026-02-06 | 0.1 | Bozza iniziale come issue T-013 |

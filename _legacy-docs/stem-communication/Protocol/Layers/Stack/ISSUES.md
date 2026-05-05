# Stack Layer - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunità di refactoring e violazioni di best practice per il componente **Stack** (Orchestratore dello stack protocollare a 7 layer OSI).

> **Ultimo aggiornamento:** 2026-02-24

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 0 | 2 |
| **Media** | 6 | 0 |
| **Bassa** | 4 | 0 |

**Totale aperte:** 10  
**Totale risolte:** 2

---

## Issue Trasversali Correlate

| ID | Titolo | Status | Impatto su Stack |
|----|--------|--------|------------------|
| **T-006** | Rimuovere Shutdown() + UninitializeAsync() | ✅ Risolto | Rimosso `Shutdown()`, aggiunto `UninitializeAsync()` |

→ [Protocol/ISSUES.md](../../ISSUES.md) per dettagli completi.

---

## Indice Issue Aperte

- [STK-001 - Race Condition InitializeAsync/ShutdownAsync](#stk-001---race-condition-initializeasyncshutdownasync)
- [STK-003 - CloneContext Non Copia Metadata](#stk-003---clonecontext-non-copia-metadata)
- [STK-004 - ShutdownAsync con Task.CompletedTask Inutile](#stk-004---shutdownasync-con-taskcompletedtask-inutile)
- [STK-005 - AesKey Array Mutabile Esposto](#stk-005---aeskey-array-mutabile-esposto)
- [STK-006 - Builder Build() Multipli Condividono Config](#stk-006---builder-build-multipli-condividono-config)
- [STK-007 - Validazione Configurazione Incompleta](#stk-007---validazione-configurazione-incompleta)
- [STK-008 - Dispose Fire-and-Forget](#stk-008---dispose-fire-and-forget)
- [STK-009 - Magic Strings Messaggi Errore](#stk-009---magic-strings-messaggi-errore)
- [STK-010 - StackConfiguration Mutabile Post-Validazione](#stk-010---stackconfiguration-mutabile-post-validazione)
- [STK-011 - Documentazione XML Costruttore Interno](#stk-011---documentazione-xml-costruttore-interno)

## Indice Issue Risolte

- [STK-002 - Mancato Rollback Init Parziale](#stk-002---mancato-rollback-init-parziale)
- [STK-012 - Mancano Eventi Stato Connessione](#stk-012---mancano-eventi-stato-connessione)

---

## Priorità Alta

(Nessuna issue alta priorità aperta)

#### File Coinvolti

- `Protocol/Layers/Stack/ProtocolStack.cs`
- `Protocol/Layers/PhysicalLayer/PhysicalLayer.cs` (potrebbe dover propagare eventi dal driver)

#### Soluzione Proposta

1. **Aggiungere eventi su ProtocolStack:**

```csharp
/// <summary>Evento sollevato quando lo stato della connessione cambia.</summary>
public event EventHandler<ConnectionStateChangedEventArgs>? ConnectionStateChanged;

/// <summary>Evento sollevato quando la connessione viene persa inaspettatamente.</summary>
public event EventHandler<ConnectionLostEventArgs>? ConnectionLost;

/// <summary>Evento sollevato quando la riconnessione automatica ha successo.</summary>
public event EventHandler? Reconnected;
```

2. **Creare EventArgs:**

```csharp
public sealed class ConnectionStateChangedEventArgs : EventArgs
{
    public bool IsConnected { get; init; }
    public bool WasExpected { get; init; }
    public string? Reason { get; init; }
}

public sealed class ConnectionLostEventArgs : EventArgs
{
    public string? Reason { get; init; }
    public bool WillAttemptReconnect { get; init; }
}
```

3. **Propagare eventi dal driver:**
   - `IChannelDriver` potrebbe esporre `event EventHandler<ConnectionStateChangedEventArgs>? ConnectionStateChanged`
   - `PhysicalLayer` sottoscrive e propaga verso l'alto
   - `ProtocolStack` ri-espone gli eventi

#### Alternative Considerate

| Alternativa | Pro | Contro |
|-------------|-----|--------|
| Polling `IsConnected` | Già funziona | Inefficiente, latenza |
| Observable pattern | Reactive, composable | Dipendenza System.Reactive |
| Callback registration | Semplice | Meno flessibile degli eventi |

#### Benefici Attesi

- UI reattiva senza polling
- Pattern standard .NET (eventi)
- Gestione riconnessione trasparente
- Miglior UX in applicazioni production

#### Note

Richiesto per integrazione in **Stem.Production.Tracker** (applicazione WPF per tracciamento produzione dispositivi STEM).

---

(Nessuna altra issue alta priorità aperta)

---

## Priorità Media

### STK-001 - Race Condition InitializeAsync/ShutdownAsync

**Categoria:** Bug  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-15  

#### Descrizione

Pattern `lock` + `async` operations causa race condition. Fix T-005 mitiga parzialmente (Volatile per `_initialized`/`_disposed`) ma non risolve.

#### File Coinvolti

- `Protocol/Layers/Stack/ProtocolStack.cs` (righe 140-195)

#### Codice Problematico

```csharp
lock (_syncLock)
{
    if (Volatile.Read(ref _initialized))
        throw new InvalidOperationException("Already initialized.");
}
// Lock rilasciato, operazioni async seguono
await layer.InitializeAsync(config);
```

#### Soluzione Proposta

Usare `SemaphoreSlim` per async locking:

```csharp
private readonly SemaphoreSlim _initLock = new(1, 1);

await _initLock.WaitAsync();
try
{
    if (Volatile.Read(ref _initialized))
        throw new InvalidOperationException("Already initialized.");
    // ... init ...
}
finally
{
    _initLock.Release();
}
```

#### Benefici Attesi

- Elimina race condition
- Pattern async corretto

---

### STK-003 - CloneContext Non Copia Metadata

**Categoria:** Bug  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-20  

#### Descrizione

`CloneContext` non copia `Metadata` dictionary → perdita informazioni tra chunk.

#### File Coinvolti

- `Protocol/Layers/Stack/ProtocolStack.cs` (righe 420-435)

#### Soluzione Proposta

```csharp
foreach (var kvp in original.Metadata)
{
    clone.Metadata[kvp.Key] = kvp.Value;
}
```

---

### STK-004 - ShutdownAsync con Task.CompletedTask Inutile

**Categoria:** Code Smell  
**Priorità:** Media  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-22  

#### Descrizione

`async` method senza `await` reale → warning compiler, allocazione inutile state machine.

#### File Coinvolti

- `Protocol/Layers/Stack/ProtocolStack.cs` (righe 197-225)

#### Soluzione Proposta

Rimuovere `async`:

```csharp
public Task ShutdownAsync()
{
    if (Volatile.Read(ref _disposed)) return Task.CompletedTask;
    // ... operazioni sincrone ...
    return Task.CompletedTask;
}
```

---

### STK-005 - AesKey Array Mutabile Esposto

**Categoria:** Security  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-25  

#### Descrizione

`AesKey` property espone array diretto → modificabile esternamente, non azzerato dopo uso.

#### File Coinvolti

- `Protocol/Layers/Stack/StackConfiguration.cs` (righe 69-76)

#### Soluzione Proposta

```csharp
private byte[]? _aesKey;

public byte[]? AesKey
{
    get => _aesKey?.ToArray();  // Copia
    set => _aesKey = value?.ToArray();  // Copia
}

// In Dispose:
CryptographicOperations.ZeroMemory(_aesKey);
```

---

### STK-006 - Builder Build() Multipli Condividono Config

**Categoria:** Design  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-28  

#### Descrizione

Builder permette `Build()` multipli → stack condividono stessa `StackConfiguration` instance.

#### File Coinvolti

- `Protocol/Layers/Stack/ProtocolStackBuilder.cs` (righe 250-285)

#### Soluzione Proposta

Clone config per ogni build o invalidare builder dopo primo `Build()`.

---

### STK-007 - Validazione Configurazione Incompleta

**Categoria:** Bug  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-02-01  

#### Descrizione

`StackConfiguration.Validate()` non valida: `BaudRate`, `TxBufferSize`, `RxBufferSize`, `OperationTimeoutMs`, `HeartbeatInterval`, `SessionTimeout`.

#### File Coinvolti

- `Protocol/Layers/Stack/StackConfiguration.cs` (righe 120-145)

#### Soluzione Proposta

Aggiungere validazioni mancanti con fail-fast.

---

## Priorità Bassa

### STK-008 - Dispose Fire-and-Forget

**Categoria:** Anti-Pattern  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-02  

#### Descrizione

`Dispose()` sincrono chiama `_ = ShutdownAsync()` fire-and-forget → risorse potrebbero non essere rilasciate.

#### File Coinvolti

- `Protocol/Layers/Stack/ProtocolStack.cs` (righe 455-465)

#### Soluzione Proposta

Preferire `DisposeAsync` o documentare che `Dispose()` è best-effort.

---

### STK-009 - Magic Strings Messaggi Errore

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-03  

#### Descrizione

Messaggi errore hardcoded → difficile localizzazione.

#### File Coinvolti

- `Protocol/Layers/Stack/ProtocolStack.cs` (vari)
- `Protocol/Layers/Stack/StackConfiguration.cs` (vari)
- `Protocol/Layers/Stack/ProtocolStackBuilder.cs` (vari)

#### Soluzione Proposta

Centralizzare in `StackErrorMessages` class.

---

### STK-010 - StackConfiguration Mutabile Post-Validazione

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-04  

#### Descrizione

Tutte proprietà con setter pubblici → config modificabile dopo creazione stack.

#### File Coinvolti

- `Protocol/Layers/Stack/StackConfiguration.cs`

#### Soluzione Proposta

Usare `init` accessors o pattern "frozen" post-validazione.

---

### STK-011 - Documentazione XML Costruttore Interno

**Categoria:** Documentation  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-05  

#### Descrizione

Costruttore interno manca XML docs dettagliati per parametri.

#### File Coinvolti

- `Protocol/Layers/Stack/ProtocolStack.cs` (righe 92-125)

#### Soluzione Proposta

Aggiungere `<param>` tags per tutti i parametri.

---

## Issue Risolte

### STK-012 - Mancano Eventi Stato Connessione

**Categoria:** Feature Gap  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-02-24  
**Data Risoluzione:** 2026-02-24  
**Branch:** fix/stk-012  

#### Descrizione

`ProtocolStack` non esponeva eventi per notificare cambiamenti di stato della connessione. I consumatori dovevano fare polling su `IsConnected`.

#### Soluzione Implementata

1. **`ConnectionState` enum** - Stati: `Disconnected`, `Connecting`, `Connected`, `Reconnecting`
2. **`ConnectionStateChangedEventArgs`** - EventArgs con stato precedente/corrente, reason, wasExpected, willAttemptReconnect
3. **Evento su `IChannelDriver`** - Breaking change: tutti i driver devono implementare l'evento
4. **Implementazione in `BleChannelDriver`** - Solleva eventi su connect, disconnect, auto-reconnect
5. **Implementazione in `CanChannelDriver`** - Solleva eventi su connect, disconnect
6. **Propagazione via `PhysicalLayer`** - Sottoscrive evento dal driver e lo ri-espone
7. **Esposizione su `ProtocolStack`** - Evento pubblico `ConnectionStateChanged`

#### File Modificati

- `Protocol/Infrastructure/ConnectionState.cs` (nuovo)
- `Protocol/Infrastructure/ConnectionStateChangedEventArgs.cs` (nuovo)
- `Protocol/Infrastructure/IChannelDriver.cs` (modificato - nuovo evento)
- `Drivers.Ble/BleChannelDriver.cs` (modificato)
- `Drivers.Can/CanChannelDriver.cs` (modificato)
- `Protocol/Layers/PhysicalLayer/PhysicalLayer.cs` (modificato)
- `Protocol/Layers/Stack/ProtocolStack.cs` (modificato)

#### Test Aggiunti

25 test in `ConnectionStateTests.cs` e `ProtocolStackTests.cs`:
- Test enum values
- Test EventArgs invarianti (previous ≠ current, wasExpected implies !willReconnect)
- Test state transitions
- Test evento su ProtocolStack

#### Benefici Ottenuti

- UI reattiva senza polling
- Pattern standard .NET (eventi)
- Gestione auto-reconnect trasparente
- Pronto per integrazione in Stem.Production.Tracker

---

### STK-002 - Mancato Rollback Init Parziale

**Categoria:** Bug  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-01-20  
**Data Risoluzione:** 2026-02-06  
**Branch:** fix/stk-002  

#### Descrizione

Se un layer falliva durante `InitializeAsync`, i layer già inizializzati NON venivano arrestati. Stack rimaneva in stato inconsistente.

#### Soluzione Implementata

1. **Lista `initializedLayers`** - Tiene traccia dei layer inizializzati con successo
2. **Metodo `RollbackInitializationAsync()`** - Arresta i layer in ordine inverso (top-down)
3. **Rollback su fallimento** - Chiamato quando `InitializeAsync` ritorna `false`
4. **Rollback su eccezione** - Chiamato nel catch block prima di rethrow

```csharp
// STK-002: Tiene traccia dei layer inizializzati per eventuale rollback
var initializedLayers = new List<IProtocolLayer>();

foreach (var (layer, config) in layerConfigs)
{
    var success = await layer.InitializeAsync(config);

    if (!success)
    {
        // STK-002 FIX: Rollback dei layer già inizializzati
        await RollbackInitializationAsync(initializedLayers);
        return false;
    }

    initializedLayers.Add(layer);
}
```

#### Test Aggiunti

5 test in `ProtocolStackTests.cs`:
- `InitializeAsync_WhenPhysicalLayerFails_ShouldNotInitializeOtherLayers`
- `InitializeAsync_WhenFails_ShouldLeaveStackInConsistentState`
- `InitializeAsync_AfterFailure_ShouldBeAbleToRetry`
- `InitializeAsync_WhenDriverThrowsException_ShouldPropagateException`
- `InitializeAsync_WhenExceptionThrown_ShouldLeaveStackInConsistentState`

#### Benefici Ottenuti

- Stato sempre consistente dopo fallimento init
- Nessun resource leak (layer arrestati correttamente)
- Stack può essere reinizializzato dopo fallimento
- Eccezioni propagate correttamente dopo cleanup

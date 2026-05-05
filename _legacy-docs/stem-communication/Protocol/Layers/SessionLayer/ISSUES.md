# SessionLayer - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunita di refactoring e violazioni di best practice per il componente **SessionLayer**.  

> **Ultimo aggiornamento:** 2026-02-09

---

## Riepilogo

| Priorita | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 1 | 3 |
| **Media** | 4 | 3 |
| **Bassa** | 4 | 0 |

**Totale aperte:** 9  
**Totale risolte:** 6

---

## Indice Issue Aperte

- [SL-015 - UpdateRemoteDevice Non Gestisce Sessioni Broadcast](#sl-015---updateremotedevice-non-gestisce-sessioni-broadcast)
- [SL-005 - ProcessUpstreamAsync Apre Sessione Automaticamente Senza Configurazione](#sl-005---processupstreamasync-apre-sessione-automaticamente-senza-configurazione)
- [SL-006 - IsBroadcast Logica Duplicata e Hardcoded](#sl-006---isbroadcast-logica-duplicata-e-hardcoded)
- [SL-008 - SessionStateMachine ValidTransitions E Static Readonly Ma Mutabile](#sl-008---sessionstatemachine-validtransitions-e-static-readonly-ma-mutabile)
- [SL-009 - DeviceIdCalculator DecomposeId Manca Validazione](#sl-009---deviceidcalculator-decomposeid-manca-validazione)
- [SL-010 - Mancanza di Evento per Notifica Layer Superiori](#sl-010---mancanza-di-evento-per-notifica-layer-superiori)
- [SL-011 - Finalizer Non Necessario se Dispose Chiamato Correttamente](#sl-011---finalizer-non-necessario-se-dispose-chiamato-correttamente)
- [SL-012 - Heartbeat Timer Non Usa CancellationToken](#sl-012---heartbeat-timer-non-usa-cancellationtoken)
- [SL-014 - SessionLayerStatistics CurrentSessionDuration Calcolo Errato](#sl-014---sessionlayerstatistics-currentsessionduration-calcolo-errato)

## Indice Issue Risolte

- [SL-001 - SessionManager Non Implementa IDisposable Ma Gestisce Eventi](#sl-001---sessionmanager-non-implementa-idisposable-ma-gestisce-eventi)
- [SL-013 - SessionLayerStatistics Ha Proprieta Non Thread-Safe](#sl-013---sessionlayerstatistics-ha-proprieta-non-thread-safe)
- [SL-004 - SessionLayerConstants E Internal Ma Usata in Classe Pubblica](#sl-004---sessionlayerconstants-e-internal-ma-usata-in-classe-pubblica)
- [SL-007 - Mancanza di Statistiche Sessione](#sl-007---mancanza-di-statistiche-sessione)
- [SL-002 - Console WriteLine Usato per Logging in Produzione](#sl-002---console-writeline-usato-per-logging-in-produzione)
- [SL-003 - UpdateRemoteDevice Permette Cambio RemoteId a Sessione Attiva](#sl-003---updateremotedevice-permette-cambio-remoteid-a-sessione-attiva)

---

## Priorita Alta

### SL-015 - UpdateRemoteDevice Non Gestisce Sessioni Broadcast

**Categoria:** Bug  
**Priorita:** Alta  
**Impatto:** Alto  
**Status:** Aperto  
**Data Apertura:** 2026-02-09  

#### Descrizione

`SessionManager.UpdateRemoteDevice()` rifiuta messaggi da qualsiasi sender diverso dal `RemoteDeviceId` corrente, anche quando la sessione è stata aperta con un indirizzo broadcast.

**Scenario problematico:**
1. Apro sessione con `SRID_BROADCAST` (`0x1FFFFFFF`)
2. Ricevo messaggio da dispositivo reale (es. `0x00030141` - SRID_EDEN)
3. `currentRemote = 0x1FFFFFFF` ? `newRemoteId = 0x00030141`
4. Il messaggio viene **RIFIUTATO** come "hijacking" ? **BUG**

#### Comportamento Atteso

Quando `RemoteDeviceId` è un indirizzo broadcast:
- **Broadcast globale** (`0x1FFFFFFF`): Accettare messaggi da qualsiasi SRID valido
- **Broadcast pulsantiere** (`BoardNumber = 0x3F`): Accettare messaggi da tutte le pulsantiere del dispositivo

#### File Coinvolti

- `Protocol/Layers/SessionLayer/Helpers/SessionManager.cs`
- `Protocol/Layers/SessionLayer/Helpers/DeviceIdCalculator.cs`

#### Soluzione Proposta

1. Aggiungere metodo `IsBroadcast(uint srid)` in `DeviceIdCalculator`
2. Modificare `UpdateRemoteDevice()` per verificare se `currentRemote` è broadcast prima di rifiutare

```csharp
// In DeviceIdCalculator
public static bool IsBroadcast(uint srid)
{
    // Broadcast globale
    if (srid == SridConstants.SRID_GLOBAL_BROADCAST)
        return true;
    
    // Broadcast parziale (BoardNumber = 0x3F)
    return (srid & SridConstants.BOARD_NUMBER_MASK) == SridConstants.BROADCAST_BOARD_NUMBER;
}

// In UpdateRemoteDevice
if (currentRemote != 0 && currentRemote != newRemoteId)
{
    // Se la sessione è broadcast, accetta qualsiasi sender valido
    if (DeviceIdCalculator.IsBroadcast(currentRemote))
    {
        // TODO: Opzionalmente verificare che newRemoteId sia un SRID STEM valido
        return; // Accetta senza aggiornare RemoteDeviceId
    }
    
    // Altrimenti, rifiuta come hijacking
    ...
}
```

#### Benefici Attesi

- Sessioni broadcast funzionanti
- Comunicazione con gruppi di dispositivi possibile
- Nessun falso positivo per hijacking

#### Correlato A

- SL-006 (costanti broadcast)

---

## Priorita Media

### SL-005 - ProcessUpstreamAsync Apre Sessione Automaticamente Senza Configurazione

**Categoria:** Design  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

`ProcessUpstreamAsync` apre automaticamente una sessione se non e' attiva e riceve un pacchetto con `SenderId != 0`. Questo comportamento e' hardcoded e non configurabile.

#### File Coinvolti

- `Protocol/Layers/SessionLayer/SessionLayer.cs`

#### Benefici Attesi

- Comportamento configurabile
- Supporto scenari server/client diversi

---

### SL-006 - IsBroadcast Logica Duplicata e Hardcoded

**Categoria:** Code Smell  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

Il metodo `IsBroadcast()` ha logica hardcoded con magic number `0x3F` per determinare se un SRID e' broadcast. Le costanti per il broadcast non sono centralizzate.

#### File Coinvolti

- `Protocol/Layers/SessionLayer/SessionLayer.cs`
- `Protocol/Layers/SessionLayer/Helpers/DeviceIdCalculator.cs`
- `Protocol/Layers/Base/Enums/StemDevice.cs`

#### Soluzione Proposta

1. Creare classe `SridConstants` in `Protocol/Layers/Base/Models/`:

```csharp
public static class SridConstants
{
    /// <summary>Broadcast globale per tutti i dispositivi STEM.</summary>
    public const uint SRID_GLOBAL_BROADCAST = 0x1FFFFFFF;
    
    /// <summary>Maschera per estrarre BoardNumber (6 bit) da SRID.</summary>
    public const uint BOARD_NUMBER_MASK = 0x3F;
    
    /// <summary>BoardNumber per broadcast parziale (tutte le schede di quel tipo).</summary>
    public const byte BROADCAST_BOARD_NUMBER = 0x3F;
}
```

2. Aggiungere metodi in `DeviceIdCalculator`:

```csharp
/// <summary>Verifica se un SRID è un indirizzo broadcast.</summary>
public static bool IsBroadcast(uint srid)
{
    if (srid == SridConstants.SRID_GLOBAL_BROADCAST)
        return true;
    
    return (srid & SridConstants.BOARD_NUMBER_MASK) == SridConstants.BROADCAST_BOARD_NUMBER;
}

/// <summary>Verifica se un SRID è il broadcast globale.</summary>
public static bool IsGlobalBroadcast(uint srid) 
    => srid == SridConstants.SRID_GLOBAL_BROADCAST;

/// <summary>Verifica se un SRID è un broadcast parziale (pulsantiere).</summary>
public static bool IsPartialBroadcast(uint srid)
    => (srid & SridConstants.BOARD_NUMBER_MASK) == SridConstants.BROADCAST_BOARD_NUMBER
       && srid != SridConstants.SRID_GLOBAL_BROADCAST;
```

#### Benefici Attesi

- Logica centralizzata in DeviceIdCalculator
- Costanti documentate e riutilizzabili
- Magic numbers eliminati
- Supporto per broadcast globale e parziale

#### Correlato A

- SL-015 (gestione broadcast in UpdateRemoteDevice)

---

### SL-008 - SessionStateMachine ValidTransitions E Static Readonly Ma Mutabile

**Categoria:** Design  
**Priorita:** Media  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

`ValidTransitions` e' un `Dictionary<SessionState, SessionState[]>` statico readonly. Il contenuto potrebbe essere modificato accidentalmente.

#### File Coinvolti

- `Protocol/Layers/SessionLayer/Helpers/SessionStateMachine.cs`

#### Soluzione Proposta

Usare `FrozenDictionary<SessionState, FrozenSet<SessionState>>` (.NET 8+) per immutabilita' garantita.

#### Benefici Attesi

- Immutabilita' a compile time
- Thread-safety senza lock per lettura

---

### SL-014 - SessionLayerStatistics CurrentSessionDuration Calcolo Errato

**Categoria:** Bug  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

La proprieta `CurrentSessionDuration` calcola la durata dalla `LastStateTransitionAt`, che viene aggiornata ad ogni transizione di stato, non solo all'apertura della sessione.

#### File Coinvolti

- `Protocol/Layers/SessionLayer/Models/SessionLayerStatistics.cs`

#### Benefici Attesi

- Calcolo durata corretto
- Tracciamento separato SessionStartedAt

---

## Priorita Bassa

### SL-009 - DeviceIdCalculator DecomposeId Manca Validazione

**Categoria:** Bug  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

Il metodo `DecomposeId()` decompone qualsiasi `uint` senza validazione. Un SRID invalido (es. 0) viene decomposto normalmente.

#### File Coinvolti

- `Protocol/Layers/SessionLayer/Helpers/DeviceIdCalculator.cs`

#### Benefici Attesi

- Validazione esplicita
- API piu' sicura

---

### SL-010 - Mancanza di Evento per Notifica Layer Superiori

**Categoria:** API  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

Il metodo `OnSessionExpired` dovrebbe notificare i layer superiori tramite evento pubblico.

#### File Coinvolti

- `Protocol/Layers/SessionLayer/SessionLayer.cs`

#### Benefici Attesi

- Pattern event-driven completo
- Layer superiori notificati correttamente

---

### SL-011 - Finalizer Non Necessario se Dispose Chiamato Correttamente

**Categoria:** Performance  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

`SessionLayer` implementa un finalizer come safety net, ma non ci sono risorse unmanaged. Aggiunge overhead al GC.

#### File Coinvolti

- `Protocol/Layers/SessionLayer/SessionLayer.cs`

#### Benefici Attesi

- Minor overhead GC
- Design piu' pulito

---

### SL-012 - Heartbeat Timer Non Usa CancellationToken

**Categoria:** Bug  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

Il timer di heartbeat usa un flag volatile per controllare shutdown, ma potrebbe esserci race condition durante il dispose.

#### File Coinvolti

- `Protocol/Layers/SessionLayer/SessionLayer.cs`

#### Soluzione Proposta

Usare `PeriodicTimer` con `CancellationToken` per cooperative cancellation.

#### Benefici Attesi

- Shutdown piu' pulito
- Nessuna race condition

---

## Issue Risolte

### SL-001 - SessionManager Non Implementa IDisposable Ma Gestisce Eventi

**Categoria:** Resource Management  
**Priorita:** Alta  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-02-05  
**Branch:** fix/sl-001

#### Descrizione

`SessionManager` sottoscriveva l'evento `StateChanged` della `SessionStateMachine` nel costruttore, ma non implementava `IDisposable`. L'event handler `OnStateChanged` non veniva esplicitamente disconnesso.

#### File Coinvolti

- `Protocol/Layers/SessionLayer/Helpers/SessionManager.cs`
- `Protocol/Layers/SessionLayer/SessionLayer.cs`

#### Soluzione Implementata

**SessionManager ora implementa IDisposable:**

1. Aggiunta interfaccia `: IDisposable` alla classe
2. Aggiunto campo `_disposed` per idempotenza
3. Implementato metodo `Dispose()`:
   - Disconnette event handler `_stateMachine.StateChanged -= OnStateChanged`
   - Chiude la sessione se attiva
   - Imposta `_disposed = true`
   - Chiama `GC.SuppressFinalize(this)`

**SessionLayer.DisposeResources() aggiornato:**
- Chiama `_sessionManager.Dispose()` invece di `CloseSession()`
- Mantiene disconnessione eventi esterni (`SessionExpired`, etc.)

**Codice implementato:**

```csharp
public class SessionManager : IDisposable
{
    private bool _disposed;
    
    public void Dispose()
    {
        if (_disposed)
            return;

        _stateMachine.StateChanged -= OnStateChanged;

        if (IsActive)
            CloseSession("SessionManager disposed");

        _disposed = true;
        GC.SuppressFinalize(this);
    }
}
```

#### Test Aggiunti

**Unit Tests - `SessionManagerTests.cs` (7 test):**
- `SessionManager_ShouldImplementIDisposable`
- `Dispose_ShouldDisconnectStateChangedEventHandler`
- `Dispose_WhenSessionActive_ShouldCloseSession`
- `Dispose_CalledMultipleTimes_ShouldNotThrow`
- `Dispose_WhenNoActiveSession_ShouldNotThrow`
- `Dispose_WhenInitializedButNotConnected_ShouldNotThrow`
- `UsingStatement_ShouldDisposeCorrectly`

#### Benefici Ottenuti

- Nessun memory leak da event handler
- Pattern IDisposable completo e corretto
- Compatibilita con `using` statement
- Risorse rilasciate correttamente

---

### SL-013 - SessionLayerStatistics Ha Proprieta Non Thread-Safe

**Categoria:** Bug  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-02-03  
**Branch:** fix/t-005  

#### Descrizione

Le proprieta DateTime (`StartTime`, `LastHeartbeatSentAt`, `LastHeartbeatReceivedAt`, `LastStateTransitionAt`) erano auto-property non atomiche.

#### Soluzione Implementata

Pattern T-005: DateTime convertiti a `long` (Ticks) con `Interlocked.Read/Exchange`:

```csharp
private long _startTimeTicks = DateTime.UtcNow.Ticks;
private long _lastHeartbeatSentAtTicks;  // 0 = null

public DateTime StartTime => new(Interlocked.Read(ref _startTimeTicks));

public DateTime? LastHeartbeatSentAt
{
    get
    {
        var ticks = Interlocked.Read(ref _lastHeartbeatSentAtTicks);
        return ticks == 0 ? null : new DateTime(ticks);
    }
}
```

#### Benefici Ottenuti

- Zero torn reads
- Lock-free performance
- Pattern consistente con altri layer

---

### SL-004 - SessionLayerConstants E Internal Ma Usata in Classe Pubblica

**Categoria:** API  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-29  
**Branch:** fix/t-003  

#### Descrizione

`SessionLayerConstants` era dichiarata `internal`, ma `SessionLayerConfiguration` e' pubblica e usa i suoi valori.

#### Soluzione Implementata

Resa la classe `SessionLayerConstants` pubblica.

#### Benefici Ottenuti

- Costanti accessibili da assembly esterni
- API piu' usabile

---

### SL-007 - Mancanza di Statistiche Sessione

**Categoria:** Observability  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-29  
**Branch:** fix/t-004  

#### Descrizione

Il SessionLayer non esponeva statistiche aggregate.

#### Soluzione Implementata

Creata classe `SessionLayerStatistics` con metriche complete: SessionsEstablished, SessionsClosed, SessionsExpired, HeartbeatsSent, HeartbeatsReceived, SridMismatches, StateTransitions, SessionHijackAttempts.

#### Benefici Ottenuti

- Monitoraggio sessioni
- Identificazione problemi
- Base per alerting

---

### SL-002 - Console WriteLine Usato per Logging in Produzione

**Categoria:** Code Smell  
**Priorita:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-28  
**Branch:** fix/t-002  

#### Descrizione

`SessionManager.OnStateChanged()` e `SessionLayer.OnSessionExpired()` usavano `Console.WriteLine` per logging.

#### Soluzione Implementata

Aggiunto `ILogger<SessionLayer>?` nei costruttori. Tutti i `Console.WriteLine` sostituiti con logging strutturato.

#### Benefici Ottenuti

- Logging configurabile e strutturato
- Thread-safe
- Zero breaking changes

---

### SL-003 - UpdateRemoteDevice Permette Cambio RemoteId a Sessione Attiva

**Categoria:** Security  
**Priorita:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-28  
**Branch:** fix/sl-003  

#### Descrizione

`UpdateRemoteDevice()` permetteva di cambiare il `RemoteDeviceId` durante una sessione attiva senza validazione, causando potenziale session hijacking.

#### Soluzione Implementata

Implementato strict mode: una volta impostato il RemoteDeviceId, NON puo' essere cambiato. Messaggi da dispositivi diversi vengono ignorati con warning log e evento `SessionHijackAttempted`.

```csharp
public void UpdateRemoteDevice(uint newRemoteId)
{
    var currentRemote = Interlocked.CompareExchange(ref _remoteDeviceId, 0, 0);
    
    if (currentRemote != 0 && currentRemote != newRemoteId)
    {
        _logger?.LogWarning(
            "Ignoring message from device {SenderId:X8}: session bound to device {RemoteDeviceId:X8}",
            newRemoteId, currentRemote);
        SessionHijackAttempted?.Invoke(this, newRemoteId);
        return;
    }
    
    Interlocked.Exchange(ref _remoteDeviceId, newRemoteId);
}
```

#### Benefici Ottenuti

- Sessioni sicure, nessun hijacking possibile
- Miglioramento rispetto al protocollo C originale
- Warning logging per tentativi

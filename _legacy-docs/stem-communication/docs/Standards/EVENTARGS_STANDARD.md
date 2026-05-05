# Standard EventArgs - Criteri per Definizione EventArgs Tipizzati

> **Versione:** 1.1  
> **Data:** 2026-02-25  
> **Riferimento Issue:** T-021, STK-012  
> **Stato:** Active

---

## Scopo

Questo standard definisce i criteri per la creazione di classi `EventArgs` personalizzate, garantendo:

- **Type-safety:** EventArgs tipizzati invece di tipi primitivi generici
- **Immutabilità:** Stato readonly dopo costruzione
- **Self-documenting:** Proprietà con nomi espressivi
- **Consistenza:** Formato uniforme in tutto il progetto

Si applica a: tutti gli eventi in Protocol/, Drivers.Can/, Drivers.Ble/, Client/.

---

## Principi Guida

1. **Espressività:** Un EventArgs deve comunicare chiaramente cosa è successo
2. **Immutabilità:** Lo stato dell'evento non deve essere modificabile dopo la creazione
3. **Validazione:** Invarianti devono essere verificati nel costruttore
4. **Completezza:** Includere tutti i dati necessari per gestire l'evento
5. **Convenienza:** Fornire proprietà helper per casi d'uso comuni

---

## Regole

### Quando Creare EventArgs Custom

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| EA-001 | ✅ DEVE | Evento con dati → creare EventArgs custom (no `EventHandler<int>`) |
| EA-002 | ✅ DEVE | Evento senza dati ma con contesto utile → creare EventArgs custom |
| EA-003 | 💡 PUÒ | Evento senza dati e senza contesto → usare `EventHandler` standard |

### Naming e Struttura

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| EA-010 | ✅ DEVE | Nome formato `{Evento}EventArgs` (es. `ConnectionStateChangedEventArgs`) |
| EA-011 | ✅ DEVE | **Pubblici:** Derivare da `System.EventArgs` |
| EA-011b | 💡 PUÒ | **Interni:** Usare `readonly record struct` se alta frequenza |
| EA-012 | ✅ DEVE | Classe `sealed` (non estendibile) |
| EA-013 | ⚠️ DOVREBBE | Posizionare nel namespace del componente che definisce l'evento |

### Proprietà

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| EA-020 | ✅ DEVE | Tutte le proprietà readonly (`{ get; }`, no setter) |
| EA-021 | ✅ DEVE | Inizializzare tutte le proprietà nel costruttore |
| EA-022 | ⚠️ DOVREBBE | Includere `DateTime Timestamp { get; }` con valore `DateTime.UtcNow` |
| EA-023 | 💡 PUÒ | Aggiungere convenience properties per casi comuni (es. `IsConnected`) |

### Validazione e Invarianti

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| EA-030 | ⚠️ DOVREBBE | Validare invarianti nel costruttore con `ArgumentException` |
| EA-031 | ⚠️ DOVREBBE | Documentare invarianti in `<remarks>` con lista `<list type="bullet">` |
| EA-032 | ❌ NON DEVE | Mai lanciare eccezioni dalle proprietà getter |

### Documentazione XML

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| EA-040 | ✅ DEVE | `<summary>` sulla classe che descrive l'evento |
| EA-041 | ✅ DEVE | `<summary>` su ogni proprietà |
| EA-042 | ⚠️ DOVREBBE | `<remarks>` con esempi di valori per proprietà non ovvie |
| EA-043 | ⚠️ DOVREBBE | `<exception>` sul costruttore se valida invarianti |

---

## Scelta del Tipo: `class` vs `record struct`

### Quando Usare `sealed class : EventArgs` (Default)

| Criterio | Motivazione |
|----------|-------------|
| EventArgs **pubblico** | Compatibilità con pattern .NET standard |
| API esterna | Consumatori si aspettano `EventArgs` |
| Validazione invarianti | Costruttore può lanciare eccezioni |
| Dimensione > 16 bytes | Reference è più efficiente |
| Possibile serializzazione | Ampia compatibilità |

### Quando Usare `readonly record struct` (Eccezione)

| Criterio | Motivazione |
|----------|-------------|
| EventArgs **internal** | Non esposto, flessibilità interna |
| Alta frequenza (>1000/sec) | Zero allocazioni heap, no GC pressure |
| Dati piccoli (≤16 bytes) | Efficiente passaggio per valore |
| Nessuna validazione | Tutti i valori sono validi |
| Value equality necessaria | Built-in con record |

### Confronto

| Aspetto | `sealed class : EventArgs` | `readonly record struct` |
|---------|---------------------------|--------------------------|
| Allocazione | Heap (GC) | Stack (zero GC) ⚡ |
| Inheritance | ✅ Deriva da EventArgs | ❌ No inheritance |
| Equality | Reference | Value ✅ |
| Null | Può essere null | Mai null |
| Pattern .NET | ✅ Standard | ⚠️ Non standard |

### Esempi nel Progetto

```csharp
// ✅ Pubblico - usa class (Protocol/)
public sealed class SessionExpiredEventArgs : EventArgs { ... }

// ✅ Internal, alta frequenza - usa record struct (Drivers.Ble/)
internal readonly record struct BleDataReceivedEventArgs(byte[] Data, DateTime Timestamp);
```

---

## Esempi

### ✅ Uso Corretto - EventArgs Completo

```csharp
/// <summary>
/// Argomenti evento per il cambio di stato della connessione.
/// </summary>
/// <remarks>
/// <para><b>Invarianti:</b></para>
/// <list type="bullet">
///   <item><description><see cref="PreviousState"/> ≠ <see cref="CurrentState"/></description></item>
///   <item><description>Se <see cref="WasExpected"/> = true, allora <see cref="WillAttemptReconnect"/> = false</description></item>
/// </list>
/// </remarks>
public sealed class ConnectionStateChangedEventArgs : EventArgs
{
    /// <summary>
    /// Crea una nuova istanza di ConnectionStateChangedEventArgs.
    /// </summary>
    /// <exception cref="ArgumentException">Se previousState == currentState.</exception>
    public ConnectionStateChangedEventArgs(
        ConnectionState previousState,
        ConnectionState currentState,
        string? reason = null,
        bool wasExpected = false,
        bool willAttemptReconnect = false)
    {
        // EA-030: Validazione invarianti
        if (previousState == currentState)
            throw new ArgumentException(
                $"Previous and current state must differ. Both are {previousState}.",
                nameof(currentState));

        if (wasExpected && willAttemptReconnect)
            throw new ArgumentException(
                "Cannot attempt reconnect when disconnection was expected.",
                nameof(willAttemptReconnect));

        // EA-021: Inizializzazione proprietà
        PreviousState = previousState;
        CurrentState = currentState;
        Reason = reason;
        WasExpected = wasExpected;
        WillAttemptReconnect = willAttemptReconnect;
        Timestamp = DateTime.UtcNow;  // EA-022
    }

    /// <summary>Stato precedente della connessione.</summary>
    public ConnectionState PreviousState { get; }  // EA-020: readonly

    /// <summary>Stato corrente della connessione.</summary>
    public ConnectionState CurrentState { get; }

    /// <summary>Motivo del cambio di stato.</summary>
    public string? Reason { get; }

    /// <summary>True se il cambio è stato richiesto dall'utente.</summary>
    public bool WasExpected { get; }

    /// <summary>True se verrà tentata la riconnessione automatica.</summary>
    public bool WillAttemptReconnect { get; }

    /// <summary>Timestamp UTC del cambio di stato.</summary>
    public DateTime Timestamp { get; }

    // EA-023: Convenience properties
    /// <summary>True se la connessione è attiva.</summary>
    public bool IsConnected => CurrentState == ConnectionState.Connected;

    /// <summary>True se è in corso un tentativo di connessione.</summary>
    public bool IsConnecting => CurrentState is ConnectionState.Connecting 
                                              or ConnectionState.Reconnecting;
}
```

### ❌ Uso Scorretto - Tipi Primitivi Generici

```csharp
// ❌ NON fare: poco espressivo, cosa significa uint?
public event EventHandler<uint>? SessionHijackAttempted;

// ❌ NON fare: nessun dato, quando è scaduta? quale sessione?
public event EventHandler? SessionExpired;

// ❌ NON fare: int non descrive cosa rappresenta
public event EventHandler<int>? BuffersTimedOut;
```

### ✅ Correzione - EventArgs Tipizzati

```csharp
// ✅ Corretto: EventArgs espressivo
public sealed class SessionHijackAttemptedEventArgs : EventArgs
{
    public SessionHijackAttemptedEventArgs(uint attemptedSenderId, uint currentRemoteId)
    {
        AttemptedSenderId = attemptedSenderId;
        CurrentRemoteId = currentRemoteId;
        Timestamp = DateTime.UtcNow;
    }

    public uint AttemptedSenderId { get; }
    public uint CurrentRemoteId { get; }
    public DateTime Timestamp { get; }
}

// ✅ Corretto: include contesto utile
public sealed class SessionExpiredEventArgs : EventArgs
{
    public SessionExpiredEventArgs(uint remoteDeviceId, TimeSpan sessionDuration)
    {
        RemoteDeviceId = remoteDeviceId;
        SessionDuration = sessionDuration;
        Timestamp = DateTime.UtcNow;
    }

    public uint RemoteDeviceId { get; }
    public TimeSpan SessionDuration { get; }
    public DateTime Timestamp { get; }
}

// ✅ Corretto: dati completi
public sealed class BuffersTimedOutEventArgs : EventArgs
{
    public BuffersTimedOutEventArgs(int bufferCount, int totalBytesLost)
    {
        BufferCount = bufferCount;
        TotalBytesLost = totalBytesLost;
        Timestamp = DateTime.UtcNow;
    }

    public int BufferCount { get; }
    public int TotalBytesLost { get; }
    public DateTime Timestamp { get; }
}
```

### ❌ Uso Scorretto - Proprietà Mutabili

```csharp
// ❌ NON fare: proprietà mutabili
public class BadEventArgs : EventArgs
{
    public string? Message { get; set; }  // ❌ setter pubblico
    public int Count { get; set; }        // ❌ modificabile
}
```

---

## Eccezioni

| Componente | Eccezione | Motivazione |
|------------|-----------|-------------|
| Eventi hardware esistenti | `BleDataReceivedEventArgs` | Già in uso, breaking change evitato |
| Eventi terze parti | Plugin.BLE events | Non sotto nostro controllo |

---

## Stato Attuale nel Progetto

### EventArgs Conformi ✅

| EventArgs | Componente | Note |
|-----------|------------|------|
| `ConnectionStateChangedEventArgs` | Infrastructure | Esempio di riferimento |
| `SessionExpiredEventArgs` | SessionLayer | ✅ Convertito (T-021) |
| `SessionHijackAttemptedEventArgs` | SessionLayer | ✅ Convertito (T-021) |
| `SessionEstablishedEventArgs` | SessionLayer | Conforme |
| `SessionTerminatedEventArgs` | SessionLayer | ✅ Aggiunto Timestamp (T-021) |
| `StateChangedEventArgs` | SessionLayer | Conforme |
| `BuffersTimedOutEventArgs` | TransportLayer | ✅ Convertito (T-021) |
| `MessageReceivedEventArgs` | ApplicationLayer | ✅ Aggiunto Timestamp (T-021) |
| `AckReceivedEventArgs` | ApplicationLayer | ✅ Aggiunto Timestamp (T-021) |
| `DeviceDiscoveredEventArgs` | NetworkLayer | ✅ Aggiunto Timestamp (T-021) |
| `DeviceLostEventArgs` | NetworkLayer | ✅ Aggiunto Timestamp (T-021) |
| `RouteAddedEventArgs` | NetworkLayer | ✅ Aggiunto Timestamp (T-021) |
| `LinkQualityAlertEventArgs` | NetworkLayer | ✅ Aggiunto Timestamp (T-021) |
| `BleDataReceivedEventArgs` | Drivers.Ble | Conforme |
| `BleDisconnectedEventArgs` | Drivers.Ble | Conforme |

### Tutti gli EventArgs del protocollo sono ora conformi a EA-022 (Timestamp) ✅

---

## Enforcement

- [ ] **Code Review:** Verificare che nuovi eventi usino EventArgs custom
- [ ] **Analyzer:** Considerare analyzer per `EventHandler<primitive>`
- [ ] **Template:** Snippet Visual Studio per creazione EventArgs

---

## Riferimenti

- [Microsoft EventArgs Guidelines](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/event)
- [Protocol/Infrastructure/ConnectionStateChangedEventArgs.cs](../../Protocol/Infrastructure/ConnectionStateChangedEventArgs.cs) - Esempio di riferimento
- [T-021 Issue](../../Protocol/ISSUES.md) - Issue originale

---

## Changelog

| Data | Versione | Descrizione |
|------|----------|-------------|
| 2026-02-25 | 1.1 | Applicazione standard completa: tutti gli EventArgs ora hanno Timestamp (EA-022). Aggiunti: SessionExpiredEventArgs, SessionHijackAttemptedEventArgs, BuffersTimedOutEventArgs con invarianti. Aggiunto Timestamp a: SessionTerminatedEventArgs, MessageReceivedEventArgs, AckReceivedEventArgs, DeviceDiscoveredEventArgs, DeviceLostEventArgs, RouteAddedEventArgs, LinkQualityAlertEventArgs, BleDisconnectedEventArgs. Aggiunta regola EA-011b per record struct interni. Aggiunta sezione "Scelta del Tipo" |
| 2026-02-24 | 1.0 | Versione iniziale basata su STK-012 |

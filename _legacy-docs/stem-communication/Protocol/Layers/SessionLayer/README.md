# Session Layer (Layer 5)

## Panoramica

Il **Session Layer** è il quinto livello dello stack protocollare STEM, corrispondente al Layer 5 del modello OSI. Si occupa della gestione del ciclo di vita delle sessioni di comunicazione tra dispositivi, del tracking dello stato, della gestione del timeout e del calcolo degli identificativi dispositivo (SRID).

> **Ultimo aggiornamento:** 2026-02-11

---

## Responsabilità

- **Gestione ciclo di vita sessioni** (apertura, chiusura, timeout)
- **State machine** per transizioni di stato controllate
- **Calcolo SRID** (identificativo univoco dispositivo a 32 bit)
- **Heartbeat** opzionale per mantenere sessioni attive
- **Tracking attività** e timeout sessione
- **Rilevamento hijack** tentativi di session hijacking
- **Raccolta statistiche** su sessioni, heartbeat, transizioni e sicurezza

---

## Architettura

```
SessionLayer/
├── SessionLayer.cs                     # Implementazione principale del layer
├── Helpers/
│   ├── SessionManager.cs               # Gestione ciclo di vita sessione
│   ├── SessionStateMachine.cs          # Macchina a stati per transizioni
│   └── DeviceIdCalculator.cs           # Calcolo SRID da componenti
├── Models/
│   ├── SessionLayerConfiguration.cs    # Configurazione runtime
│   ├── SessionLayerConstants.cs        # Costanti (timeout, intervalli)
│   ├── SessionLayerStatistics.cs       # Statistiche aggregate
│   └── EventArgs.cs                    # Event arguments personalizzati
└── Enums/
    └── SessionState.cs                 # Stati possibili della sessione
```

---

## Formato Dati

### SRID (Stem Remote ID) - 32 bit

```
┌──────────┬──────────┬────────────┬─────────────┐
│ Network  │ Machine  │ BoardType  │ BoardNumber │
│  8 bit   │  8 bit   │  10 bit    │   6 bit     │
│ [31-24]  │ [23-16]  │  [15-6]    │   [5-0]     │
└──────────┴──────────┴────────────┴─────────────┘
```

| Campo | Bit | Range | Descrizione |
|-------|-----|-------|-------------|
| `Network` | 31-24 | 0-255 | Identificativo rete |
| `Machine` | 23-16 | 0-255 | Identificativo macchina nella rete |
| `BoardType` | 15-6 | 0-1023 | Tipo di scheda |
| `BoardNumber` | 5-0 | 0-63 | Numero della scheda |

**Esempio:** Network=1, Machine=0, BoardType=1, BoardNumber=3 → SRID = `0x01000043`

### Broadcast Detection

| Tipo Broadcast | Valore | Descrizione |
|----------------|--------|-------------|
| **Globale** | `0x1FFFFFFF` | Tutti i dispositivi STEM |
| **Pulsantiere** | `BoardNumber = 0x3F` | Tutte le pulsantiere di un device |

**Broadcast globale:** SRID `0x1FFFFFFF` (definito in `StemDevice.SRID_BROADCAST`)

**Broadcast parziale:** SRID con `BoardNumber = 0x3F` (es. `SRID_EDEN_BUTTON_PANEL_BROADCAST = 0x0003013F`). Usato dal dispositivo madre per comunicare con le sue pulsantiere o dal software per comunicare direttamente con esse.

> ⚠️ **Nota (SL-015):** La gestione broadcast nel `SessionManager.UpdateRemoteDevice()` non è ancora implementata. Vedere [ISSUES.md](./ISSUES.md) per dettagli.

---

## Componenti Principali

### SessionLayer

Classe principale che eredita da `ProtocolLayerBase`. Orchestra `SessionManager` e gestisce il timer per heartbeat.

```csharp
public class SessionLayer : ProtocolLayerBase
{
    public override string LayerName => "Session";
    public override int LayerLevel => 5;
    
    public SessionState State { get; }
    public uint LocalDeviceId { get; }
    public uint RemoteDeviceId { get; }
    public bool IsSessionActive { get; }
}
```

**Proprietà aggiuntive:**
- `State` - Stato corrente della sessione
- `LocalDeviceId` - SRID del dispositivo locale
- `RemoteDeviceId` - SRID del dispositivo remoto (0 se non connesso)
- `IsSessionActive` - `true` se sessione attiva

### Helper: SessionManager

Gestisce il ciclo di vita completo della sessione: apertura, chiusura, timeout.

**Metodi principali:**
- `OpenSession(uint remoteId)` - Apre sessione con dispositivo remoto
- `CloseSession()` - Chiude sessione corrente
- `UpdateActivity()` - Aggiorna timestamp ultima attività
- `CheckTimeout()` - Verifica timeout sessione

### Helper: SessionStateMachine

Macchina a stati con transizioni controllate e validazione.

**Stati:**
| Stato | Descrizione |
|-------|-------------|
| `Disconnected` | Sessione non inizializzata o terminata |
| `Initialized` | Layer inizializzato, pronto per connessione |
| `Connected` | Sessione attiva con dispositivo remoto |
| `Closing` | Sessione in fase di chiusura |

**Transizioni valide:**
```
Disconnected → Initialized (Initialize)
Initialized → Connected (OpenSession)
Initialized → Disconnected (CloseSession)
Connected → Closing (CloseSession)
Closing → Disconnected (Complete)
```

### Helper: DeviceIdCalculator

Calcola e scompone SRID da/in componenti.

**Metodi principali:**
- `CalculateId(network, machine, boardType, boardNumber)` - Componenti → SRID
- `DecomposeId(srid)` - SRID → (network, machine, boardType, boardNumber)

---

## Configurazione

Classe: `SessionLayerConfiguration`

| Proprietà | Tipo | Default | Min | Max | Descrizione |
|-----------|------|---------|-----|-----|-------------|
| `LocalDeviceId` | `uint` | `0` | - | - | SRID del dispositivo locale |
| `SessionTimeout` | `TimeSpan` | `600s` | `10s` | `3600s` | Timeout inattività sessione |
| `EnableHeartbeat` | `bool` | `false` | - | - | Abilita invio heartbeat |
| `HeartbeatInterval` | `TimeSpan` | `2s` | `1s` | `60s` | Intervallo tra heartbeat |

### Validazione

Il metodo `Validate()` verifica:
- `SessionTimeout` deve essere tra 10s e 3600s (1 ora)
- `HeartbeatInterval` (se abilitato) deve essere tra 1s e 60s

### Esempio

```csharp
var config = new SessionLayerConfiguration
{
    LocalDeviceId = DeviceIdCalculator.CalculateId(
        network: 1, 
        machine: 0, 
        boardType: 100, 
        boardNumber: 1),
    SessionTimeout = TimeSpan.FromMinutes(10),
    EnableHeartbeat = true,
    HeartbeatInterval = TimeSpan.FromSeconds(5)
};
config.Validate();
```

---

## Costanti

Classe: `SessionLayerConstants`

### Valori Default

| Costante | Valore | Usato da |
|----------|--------|----------|
| `DEFAULT_SESSION_TIMEOUT_SECONDS` | `600` | `Configuration.SessionTimeout` |
| `DEFAULT_HEARTBEAT_INTERVAL_SECONDS` | `2` | `Configuration.HeartbeatInterval` |

### Limiti Validazione

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `MIN_SESSION_TIMEOUT_SECONDS` | `10` | Timeout minimo sessione |
| `MAX_SESSION_TIMEOUT_SECONDS` | `3600` | Timeout massimo sessione (1 ora) |
| `MIN_HEARTBEAT_INTERVAL_SECONDS` | `1` | Intervallo minimo heartbeat |
| `MAX_HEARTBEAT_INTERVAL_SECONDS` | `60` | Intervallo massimo heartbeat |

---

## Flusso Dati

### State Machine

```
┌─────────────────┐
│  Disconnected   │◄────────────────────────────┐
└────────┬────────┘                             │
         │ InitializeAsync()                    │
         ▼                                      │
┌─────────────────┐                             │
│  Initialized    │─────────────────────────────┤
└────────┬────────┘     CloseSession()          │
         │ OpenSession()                        │
         ▼                                      │
┌─────────────────┐                             │
│   Connected     │                             │
└────────┬────────┘                             │
         │ CloseSession() / Timeout             │
         ▼                                      │
┌─────────────────┐                             │
│    Closing      │─────────────────────────────┘
└─────────────────┘
```

### Downstream (Trasmissione)

```
PresentationLayer (Layer 6)
      │
      ▼
┌──────────────────────────────┐
│   ProcessDownstreamAsync     │
│   ─────────────────────────  │
│   1. Verifica sessione attiva│
│   2. Aggiorna timestamp      │
│   3. Passa a layer inferiore │
└──────────────────────────────┘
      │
      ▼
TransportLayer (Layer 4)
```

### Upstream (Ricezione)

```
TransportLayer (Layer 4)
      │
      ▼
┌──────────────────────────────┐
│   ProcessUpstreamAsync       │
│   ─────────────────────────  │
│   1. Estrae SenderId         │
│   2. Verifica sessione/hijack│
│   3. Aggiorna timestamp      │
│   4. Passa a layer superiore │
└──────────────────────────────┘
      │
      ▼
PresentationLayer (Layer 6)
```

---

## Statistiche

Classe: `SessionLayerStatistics`

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `SessionsEstablished` | `long` | Sessioni stabilite con successo |
| `SessionsClosed` | `long` | Sessioni chiuse normalmente |
| `SessionsExpired` | `long` | Sessioni scadute per timeout |
| `HeartbeatsSent` | `long` | Heartbeat inviati |
| `HeartbeatsReceived` | `long` | Heartbeat ricevuti |
| `SridMismatches` | `long` | Mismatch SRID rilevati |
| `StateTransitions` | `long` | Transizioni di stato totali |
| `SessionHijackAttempts` | `long` | Tentativi hijacking rilevati |
| `CurrentState` | `SessionState` | Stato corrente sessione |
| `CurrentRemoteId` | `uint?` | SRID dispositivo remoto |
| `LastHeartbeatSentAt` | `DateTime?` | Timestamp ultimo heartbeat inviato |
| `LastHeartbeatReceivedAt` | `DateTime?` | Timestamp ultimo heartbeat ricevuto |
| `LastStateTransitionAt` | `DateTime?` | Timestamp ultima transizione |

### Accesso

```csharp
var stats = (SessionLayerStatistics)layer.Statistics;
Console.WriteLine($"Sessioni attive: {stats.SessionsEstablished - stats.SessionsClosed}");
Console.WriteLine($"Tentativi hijack: {stats.SessionHijackAttempts}");
```

---

## Eventi

Il SessionManager espone i seguenti eventi (conformi a [EVENTARGS_STANDARD.md](../../../Docs/Standards/EVENTARGS_STANDARD.md)):

| Evento | EventArgs | Descrizione |
|--------|-----------|-------------|
| `SessionEstablished` | `SessionEstablishedEventArgs` | Sessione stabilita con dispositivo remoto |
| `SessionTerminated` | `SessionTerminatedEventArgs` | Sessione terminata (chiusura o errore) |
| `SessionExpired` | `SessionExpiredEventArgs` | Sessione scaduta per timeout inattività |
| `SessionHijackAttempted` | `SessionHijackAttemptedEventArgs` | Tentativo di comunicazione da dispositivo diverso |

### EventArgs

#### SessionExpiredEventArgs

| Proprietà | Tipo | Descrizione |
|-----------|------|-------------|
| `RemoteDeviceId` | `uint` | SRID del dispositivo con cui era attiva la sessione |
| `SessionDuration` | `TimeSpan` | Durata della sessione prima della scadenza |
| `Timestamp` | `DateTime` | Timestamp UTC della scadenza |

**Invarianti:** `RemoteDeviceId ≠ 0`, `SessionDuration ≥ 0`

#### SessionHijackAttemptedEventArgs

| Proprietà | Tipo | Descrizione |
|-----------|------|-------------|
| `AttemptedSenderId` | `uint` | SRID del dispositivo che ha tentato di comunicare |
| `CurrentRemoteId` | `uint` | SRID del dispositivo con sessione attiva |
| `Timestamp` | `DateTime` | Timestamp UTC del tentativo |

**Invarianti:** `AttemptedSenderId ≠ CurrentRemoteId`, entrambi `≠ 0`

### Esempio Sottoscrizione

```csharp
sessionManager.SessionExpired += (sender, e) =>
{
    logger.LogWarning(
        "Session expired: remote={RemoteId:X8}, duration={Duration}",
        e.RemoteDeviceId, e.SessionDuration);
};

sessionManager.SessionHijackAttempted += (sender, e) =>
{
    logger.LogWarning(
        "Hijack attempt from {Attacker:X8}, session bound to {Current:X8}",
        e.AttemptedSenderId, e.CurrentRemoteId);
};
```

---

## Esempi di Utilizzo

### Inizializzazione Base

```csharp
var layer = new SessionLayer();
await layer.InitializeAsync(new SessionLayerConfiguration
{
    LocalDeviceId = 0x01000043
});

// Stato: Initialized
```

### Con Heartbeat Abilitato

```csharp
var config = new SessionLayerConfiguration
{
    LocalDeviceId = DeviceIdCalculator.CalculateId(1, 0, 100, 1),
    EnableHeartbeat = true,
    HeartbeatInterval = TimeSpan.FromSeconds(5),
    SessionTimeout = TimeSpan.FromMinutes(5)
};

var layer = new SessionLayer();
await layer.InitializeAsync(config);
```

### Gestione Sessione

```csharp
// Apri sessione con dispositivo remoto
await layer.SessionManager.OpenSession(remoteDeviceId);
// Stato: Connected

// Verifica stato
if (layer.IsSessionActive)
{
    Console.WriteLine($"Connesso a: 0x{layer.RemoteDeviceId:X8}");
}

// Chiudi sessione
await layer.SessionManager.CloseSession();
// Stato: Disconnected
```

### Calcolo SRID

```csharp
// Calcola SRID per dispositivo EDEN
uint edenId = DeviceIdCalculator.CalculateId(
    network: 1,
    machine: 0,
    boardType: 1,
    boardNumber: 3
);
// edenId = 0x01000043

// Scomponi SRID
var (net, mach, bType, bNum) = DeviceIdCalculator.DecomposeId(edenId);
Console.WriteLine($"Network: {net}, Machine: {mach}, BoardType: {bType}, BoardNumber: {bNum}");
```

---

## Issue Correlate

→ [SessionLayer/ISSUES.md](./ISSUES.md)

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| Alta | 1 | 3 |
| Media | 4 | 3 |
| Bassa | 4 | 0 |
| **Totale** | **9** | **6** |

### Issue Aperte Principali

| ID | Titolo | Priorità |
|----|--------|----------|
| SL-015 | UpdateRemoteDevice Non Gestisce Sessioni Broadcast | Alta |
| SL-005 | ProcessUpstreamAsync Apre Sessione Auto Senza Config | Media |
| SL-006 | IsBroadcast Logica Duplicata e Hardcoded | Media |
| SL-008 | SessionStateMachine ValidTransitions Mutabile | Media |

---

## Riferimenti Firmware C

| Componente C# | File C | Struttura/Funzione |
|---------------|--------|-------------------|
| `SessionLayer` | `SP_Session.c` | `SP_Session_*()` |
| `SessionManager` | `SP_Session.c` | `SP_Session_Open/Close()` |
| `DeviceIdCalculator` | `SP_Application.c` | `SP_App_Calculate_ID()` |
| SRID format | `SP_Application.h` | `SP_APP_SRID_*` defines |

**Repository:** `stem-fw-protocollo-seriale-stem/` (read-only)

---

## Links

- [Stack README](../Stack/README.md) - Orchestrazione layer
- [Base README](../Base/README.md) - Interfacce e classi base

# STEM Production Tracker - Issue Tracker

> **Ultimo aggiornamento:** 2026-03-11

---

## Riepilogo Globale

| Componente | Aperte | Risolte | Totale |
|------------|--------|---------|--------|
| [Core](./Core/ISSUES.md) | 11 | 0 | 11 |
| [Infrastructure.Persistence](./Infrastructure.Persistence/ISSUES.md) | 10 | 0 | 10 |
| [Infrastructure.Protocol](./Infrastructure.Protocol/ISSUES.md) | 7 | 0 | 7 |
| [Services](./Services/ISSUES.md) | 9 | 0 | 9 |
| [Devices](./Devices/ISSUES.md) | 5 | 0 | 5 |
| [GUI.Windows](./GUI.Windows/ISSUES.md) | 11 | 1 | 12 |
| **Totale** | **53** | **1** | **54** |

---

## Distribuzione per Priorità

| Priorità | Aperte | % |
|----------|--------|---|
| **Critica** | 0 | 0% |
| **Alta** | 5 | 9% |
| **Media** | 21 | 40% |
| **Bassa** | 27 | 51% |
| **Totale** | **53** | 100% |

```
Critica:     ░░░░░░░░░░░░░░░░░░░░  0
Alta:        ██░░░░░░░░░░░░░░░░░░  5
Media:       ████████░░░░░░░░░░░░ 21
Bassa:       ██████████░░░░░░░░░░ 27
```

---

## Issue Alta Priorità

| ID | Componente | Titolo | Categoria |
|----|------------|--------|-----------|
| **PROT-001** | Infrastructure.Protocol | State non thread-safe in BleDeviceConnection | Bug |
| **PROT-007** | Infrastructure.Protocol | Manca IFirmwareUploader per upload via BLE | Feature |
| **SVC-001** | Services | Reflection in TestSessionMapper per execution | Anti-Pattern |
| **PERS-002** | Infrastructure.Persistence | Manca Concurrency Token su entità critiche | Data Integrity |
| **GUI-010** | GUI.Windows | FirmwareUpdateViewModel upload simulato (TODO) | Feature |

---

## Issue Trasversali (T-xxx)

Issue che impattano multipli layer e richiedono coordinamento.

| ID | Titolo | Status | Componenti Coinvolti |
|----|--------|--------|----------------------|
| **T-001** | Concurrency Token mancante su entità critiche | Aperto | PERS, SVC, GUI |
| **T-002** | N+1 Query nei Service | Aperto | SVC (SVC-003, SVC-004) |
| **T-003** | Memory leak eventi non de-registrati | Aperto | GUI (GUI-001, GUI-005, GUI-007), PROT (PROT-006) |
| **T-004** | Validazione MAC Address mancante | Aperto | PROT-003, CORE-002 |
| **T-005** | ArgumentNullException inconsistente nei costruttori | Aperto | SVC-007, DEV-002 |
| **T-006** | DIP Violation - Services dipendono da Entity concrete | Aperto | Core, Services, Persistence |
| **T-007** | Leaky Abstraction - TestSheet passato dal chiamante | Aperto | Services, GUI |
| **T-008** | Missing Unit of Work - Repository commit singoli | Aperto | Persistence, Services |
| **T-009** | Firmware Upload BLE non implementato | Aperto | PROT-007, GUI-010 |

---

### T-001 - Concurrency Token mancante su entità critiche

**Categoria:** Design / Data Integrity  
**Priorità:** Alta  
**Impatto:** Alto - Lost updates in ambiente multi-PC  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

L'applicazione è **multi-PC** (requisito di progetto), ma le entità critiche non hanno `RowVersion` per gestire conflitti di concorrenza ottimistica. Questo significa che:

1. **Infrastructure.Persistence** (PERS-002): Entity senza concurrency token
2. **Services**: Non riceveranno `DbUpdateConcurrencyException`
3. **GUI.Windows**: Nessun feedback all'utente su conflitti

#### Scenario Problematico

```
PC-1 (Luca):     [Legge Device 001 Status=InProduction]
PC-2 (Daniel):   [Legge Device 001 Status=InProduction]
PC-1 (Luca):     [Completa montaggio → Status=InTesting, salva] ✅
PC-2 (Daniel):   [Completa montaggio → Status=InTesting, salva] ⚠️ SOVRASCRIVE!
```

#### Soluzione Coordinata

1. **PERS-002**: Aggiungere `RowVersion` a `DeviceEntity`, `AssemblySessionEntity`, `TestSessionEntity`
2. **Services**: Catturare `DbUpdateConcurrencyException` e rilanciare come `ConcurrencyConflictException`
3. **GUI**: Mostrare dialog "Il record è stato modificato da un altro utente. Ricaricare?"

#### Issue Correlate

- [PERS-002](../Infrastructure.Persistence/ISSUES.md#pers-002--manca-concurrency-token-su-entità-critiche)

---

### T-002 - N+1 Query nei Service

**Categoria:** Performance  
**Priorità:** Media  
**Impatto:** Medio - Performance degradate con dati in crescita  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Diversi metodi nei Service eseguono N query per caricare entità correlate invece di usare batch loading o Include.

#### Issue Correlate

- [SVC-003](../Services/ISSUES.md#svc-003--n1-query-in-phaseservicegetbyassemblerasync) - PhaseService.GetByAssemblerAsync
- [SVC-004](../Services/ISSUES.md#svc-004--n1-query-in-deviceservicegetbyworkorderidasync-e-simili) - DeviceService.GetByWorkOrderIdAsync

#### Soluzione Coordinata

Opzione A: Usare `.Include()` nei repository  
Opzione B: Batch load con dizionario  
Opzione C: Aggiungere `GetByIdsAsync()` ai repository

---

### T-003 - Memory leak eventi non de-registrati

**Categoria:** Resource Management  
**Priorità:** Media  
**Impatto:** Medio - Memory leak progressivo con uso prolungato  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Pattern ripetuto: sottoscrizione a eventi senza de-registrazione.

#### Issue Correlate

- [GUI-001](../GUI.Windows/ISSUES.md#gui-001--appxamlcs-showloginview-crea-sottoscrizioni-duplicate) - LoginConfirmed duplicato
- [GUI-005](../GUI.Windows/ISSUES.md#gui-005--sessionpanel-eventi-non-de-registrati-memory-leak) - SessionPanel eventi
- [GUI-007](../GUI.Windows/ISSUES.md#gui-007--loginviewmodel-non-de-registra-loginconfirmed) - LoginViewModel eventi
- [PROT-006](../Infrastructure.Protocol/ISSUES.md#prot-006--bledevicediscovery-devicediscovered-può-causare-memory-leak) - DeviceDiscovered

#### Soluzione Coordinata

1. **Pattern standard**: De-registrare prima di ri-sottoscrivere
2. **WeakEventManager** per eventi WPF
3. **IDisposable** per ViewModel con eventi

---

### T-004 - Validazione MAC Address mancante

**Categoria:** Input Validation  
**Priorità:** Bassa  
**Impatto:** Basso - Errori tardivi invece di fail-fast  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Il MAC Address non viene validato in nessun punto della pipeline.

#### Issue Correlate

- [PROT-003](../Infrastructure.Protocol/ISSUES.md#prot-003--connectionconfiguration-non-valida-macaddress) - ConnectionConfiguration

#### Soluzione Coordinata

Creare helper condiviso `MacAddressValidator` in Core o Infrastructure.

---

### T-005 - ArgumentNullException inconsistente nei costruttori

**Categoria:** Code Quality  
**Priorità:** Bassa  
**Impatto:** Basso - Inconsistenza, errori tardivi  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Alcuni costruttori usano `ArgumentNullException.ThrowIfNull()`, altri no.

#### Issue Correlate

- [SVC-007](../Services/ISSUES.md#svc-007--services-mancano-argumentnullexceptionthrowifnull-nel-costruttore)
- DEV-002 (validazione dipendenze)

#### Soluzione Coordinata

Standardizzare su `ArgumentNullException.ThrowIfNull()` per tutti i parametri DI.

---

### T-006 - DIP Violation - Services dipendono da Entity concrete

**Categoria:** Architecture / DIP Violation  
**Priorità:** Alta  
**Impatto:** Alto - Coupling stretto tra layer  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Le interfacce repository in `Core/Interfaces` usano parametro generico `<T>`, ma i Service iniettano il **tipo concreto Entity** da Infrastructure.Persistence. Questo viola la **Dependency Inversion Principle**: il layer Domain (Services) dipende dal layer Infrastructure.

#### Problema Architetturale

```csharp
// Core/Interfaces - astratto, corretto
public interface IDeviceRepository<T> : IRepository<T> where T : class, IEntity

// Services - DIPENDE dal tipo CONCRETO di Persistence!
public class DeviceService
{
    private readonly IDeviceRepository<DeviceEntity> _deviceRepository;  // ❌
    //                                  ^^^^^^^^^^^
    //                                  DeviceEntity è in Infrastructure.Persistence!
}
```

#### Flusso Dipendenze (Attuale - Errato)

```
Services (Domain) ──depends on──> Infrastructure.Persistence (Entity)
                                          ↓
                                       Core (IEntity)
```

**Dovrebbe essere:**
```
Services (Domain) ──depends on──> Core (Domain Models + Interfaces)
Infrastructure.Persistence ──depends on──> Core
```

#### Soluzione Proposta

**Opzione A: Repository ritornano Domain Model**

```csharp
// Core/Interfaces - Repository usa Domain Model
public interface IDeviceRepository
{
    Task<Device?> GetByIdAsync(int id, CancellationToken ct = default);
    Task<Device> AddAsync(Device device, CancellationToken ct = default);
}

// Infrastructure.Persistence - Implementazione fa mapping interno
public class DeviceRepository : IDeviceRepository
{
    public async Task<Device?> GetByIdAsync(int id, CancellationToken ct)
    {
        var entity = await _context.Devices.FindAsync(id);
        return entity is null ? null : DeviceMapper.ToDomain(entity, ...);
    }
}

// Services - Dipende SOLO da Core
public class DeviceService
{
    private readonly IDeviceRepository _repository;  // ✅ No Entity!
}
```

**Opzione B: Mantenere status quo (pragmatico)**

Per progetti piccoli, la dipendenza Services → Entity concrete è accettabile. Documentare la scelta.

#### Issue Correlate

- Tutti i Service in `Services/`
- Tutti i Repository in `Infrastructure.Persistence/Repositories/`
- Tutti i Mapper in `Services/Mapping/`

#### Benefici Attesi

- Clean Architecture rispettata
- Services testabili senza EF Core
- Mapping centralizzato in Persistence
- Possibilità di cambiare ORM senza toccare Services

---

### T-007 - Leaky Abstraction - TestSheet passato dal chiamante

**Categoria:** Design / Leaky Abstraction  
**Priorità:** Media  
**Impatto:** Medio - Logica duplicata nei consumer  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

`IAssemblySessionService.StartAsync(deviceId, sheet)` e `ITestSessionService.StartAsync(deviceId, sheet, ...)` richiedono che il chiamante passi il `TestSheet`. Ma la logica di selezione della scheda corretta è duplicata in ogni ViewModel.

#### File Coinvolti

- `Services\Interfaces\IAssemblySessionService.cs` (riga 26)
- `Services\Interfaces\ITestSessionService.cs` (riga 28)
- `GUI.Windows\ViewModels\AssemblySessionPanelViewModel.cs` (righe 139-147)
- `GUI.Windows\ViewModels\TestSessionPanelViewModel.cs` (righe 119-128)

#### Codice Problematico

```csharp
// AssemblySessionPanelViewModel.cs - Logica di selezione sheet
var sheets = await _testSheetProvider.GetByProductTypeAsync(device.WorkOrder.ProductType);
_currentSheet = sheets.FirstOrDefault();  // Logica duplicata!

if (_currentSheet is null)
{
    ErrorMessage = $"Scheda collaudo non trovata...";
    return;
}

var newSession = await _sessionService.StartAsync(device.Id, _currentSheet);

// TestSessionPanelViewModel.cs - STESSA logica duplicata!
var sheets = await _testSheetProvider.GetByProductTypeAsync(device.ProductType);
_currentSheet = sheets.Count > 0 ? sheets[0] : null;  // Duplicato!
```

#### Soluzione Proposta

**Il Service dovrebbe risolvere la TestSheet internamente:**

```csharp
// IAssemblySessionService.cs - Senza parametro TestSheet
public interface IAssemblySessionService
{
    /// <summary>
    /// Avvia una nuova sessione. La scheda collaudo viene determinata
    /// automaticamente dal tipo prodotto del device.
    /// </summary>
    Task<AssemblySession> StartAsync(int deviceId, CancellationToken ct = default);
}

// AssemblySessionService.cs - Risolve internamente
public async Task<AssemblySession> StartAsync(int deviceId, CancellationToken ct = default)
{
    var device = await GetDeviceAsync(deviceId, ct);

    var sheets = await _testSheetProvider.GetByProductTypeAsync(device.ProductType, ct);
    var sheet = sheets.FirstOrDefault()
        ?? throw new InvalidOperationException($"No test sheet found for {device.ProductType}");

    // ... crea sessione
}
```

#### Benefici Attesi

- Logica di selezione sheet centralizzata
- Consumer più semplici
- Gestione errori uniforme
- Meno duplicazione DRY

---

### T-008 - Missing Unit of Work - Repository commit singoli

**Categoria:** Architecture / Missing Pattern  
**Priorità:** Alta  
**Impatto:** Alto - Operazioni non atomiche  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Ogni repository chiama `SaveChangesAsync()` individualmente. Non è possibile fare operazioni atomiche su più entità senza transaction esplicita nel Service.

#### File Coinvolti

- Tutti i repository in `Infrastructure.Persistence\Repositories\`

#### Codice Problematico

```csharp
// DeviceRepository.cs
public async Task UpdateAsync(DeviceEntity entity, CancellationToken ct = default)
{
    _context.Devices.Update(entity);
    await _context.SaveChangesAsync(ct);  // Commit immediato!
}

// AssemblySessionRepository.cs
public async Task UpdateAsync(AssemblySessionEntity entity, CancellationToken ct = default)
{
    _context.AssemblySessions.Update(entity);
    await _context.SaveChangesAsync(ct);  // Commit separato!
}
```

#### Scenario Problematico

```csharp
// AssemblySessionService.CompleteAsync - 2 operazioni NON atomiche!
public async Task CompleteAsync(int sessionId, CancellationToken ct = default)
{
    // 1. Aggiorna sessione
    await _sessionRepository.UpdateAsync(sessionEntity, ct);  // COMMIT 1

    // 2. Transiziona device - SE FALLISCE, sessione già salvata!
    await _deviceRepository.UpdateAsync(deviceEntity, ct);    // COMMIT 2
}
```

#### Correlazione con SVC-005

SVC-005 già segnala il problema a livello Service. Questa T-008 evidenzia che la **causa root** è nei Repository.

#### Soluzione Proposta

**Opzione A: Unit of Work pattern**

```csharp
// Core/Interfaces/IUnitOfWork.cs
public interface IUnitOfWork
{
    IDeviceRepository Devices { get; }
    IAssemblySessionRepository AssemblySessions { get; }
    // ... altri repository

    Task<int> SaveChangesAsync(CancellationToken ct = default);
    Task BeginTransactionAsync(CancellationToken ct = default);
    Task CommitAsync(CancellationToken ct = default);
    Task RollbackAsync(CancellationToken ct = default);
}

// Nei Service
public async Task CompleteAsync(int sessionId, CancellationToken ct = default)
{
    await _unitOfWork.BeginTransactionAsync(ct);
    try
    {
        // Modifiche senza commit
        _unitOfWork.AssemblySessions.Update(sessionEntity);
        _unitOfWork.Devices.Update(deviceEntity);

        // Commit atomico
        await _unitOfWork.SaveChangesAsync(ct);
        await _unitOfWork.CommitAsync(ct);
    }
    catch
    {
        await _unitOfWork.RollbackAsync(ct);
        throw;
    }
}
```

**Opzione B: Repository senza SaveChanges (chiamato esternamente)**

```csharp
// Repository NON chiama SaveChanges
public async Task UpdateAsync(DeviceEntity entity, CancellationToken ct = default)
{
    _context.Devices.Update(entity);
    // NO SaveChanges!
}

// Service chiama SaveChanges una volta
await _deviceRepository.UpdateAsync(deviceEntity, ct);
await _sessionRepository.UpdateAsync(sessionEntity, ct);
await _context.SaveChangesAsync(ct);  // Commit unico
```

#### Benefici Attesi

- Operazioni atomiche
- Nessuno stato inconsistente
- Rollback automatico
- Pattern standard per EF Core

---

### T-009 - Firmware Upload BLE non implementato

**Categoria:** Feature Incompleta  
**Priorità:** Alta  
**Impatto:** Alto - Funzionalità critica non disponibile  
**Status:** Aperto  
**Data Apertura:** 2026-03-12

#### Descrizione

L'aggiornamento firmware via BLE non è implementato. L'UI esiste e funziona (download firmware, dialog selezione) ma l'upload effettivo sul dispositivo è simulato con `Task.Delay`.

#### Issue Correlate

- [PROT-007](./Infrastructure.Protocol/ISSUES.md#prot-007--manca-ifirmwareuploader-per-upload-via-ble-todo) - Manca IFirmwareUploader
- [GUI-010](./GUI.Windows/ISSUES.md#gui-010--firmwareupdateviewmodel-upload-simulato-todo) - Upload simulato in ViewModel

#### Componenti Coinvolti

| Layer | File | Stato |
|-------|------|-------|
| **Core** | `FirmwareInfo.cs` | ✅ Completato |
| **Persistence** | `IFirmwareProvider`, `StubFirmwareProvider`, `AzureFirmwareProvider` | ✅ Completato |
| **Protocol** | `IFirmwareUploader`, `BleFirmwareUploader` | 🔲 Da implementare |
| **GUI** | `FirmwareUpdateViewModel`, `FirmwareUpdateDialog` | ✅ Completato (simula upload) |

#### Soluzione Coordinata

1. **Infrastructure.Protocol**: Creare `IFirmwareUploader` e `BleFirmwareUploader`:
   - CommandId 5: START_BOOTLOADER
   - CommandId 7: UPDATE_BOOTLOADER_PAGE (loop per ogni pagina)
   - CommandId 6: STOP_BOOTLOADER

2. **GUI.Windows**: Iniettare `IFirmwareUploader` in `FirmwareUpdateViewModel`

3. **DI**: Registrare `BleFirmwareUploader` in `AddProtocol()`

#### Note

Richiede documentazione FW team su:
- Formato esatto payload per UPDATE_BOOTLOADER_PAGE
- Dimensione pagina per ogni tipo device
- Eventuale verifica CRC dopo upload

---

## Top 10 Issue da Risolvere

| # | ID | Componente | Titolo | Effort |
|---|-----|------------|--------|--------|
| 1 | **T-009** | Cross-cutting | Firmware Upload BLE | L |
| 2 | **PROT-001** | Protocol | State non thread-safe | S |
| 3 | **SVC-001** | Services | Reflection per execution | M |
| 4 | **T-006** | Cross-cutting | DIP Violation - Services → Entity | L |
| 5 | **T-008** | Cross-cutting | Missing Unit of Work | L |
| 6 | **T-001** | Cross-cutting | Concurrency Token | L |
| 7 | **GUI-003** | GUI.Windows | Async void pericolosi | S |
| 8 | **T-007** | Cross-cutting | Leaky Abstraction TestSheet | M |
| 9 | **SVC-008** | Services | IDeviceService viola ISP | M |
| 10 | **CORE-009** | Core | TestSheet viola SRP | M |

**Effort:** S = 1-2h, M = 4-8h, L = 1-2 giorni

---

## Metriche Qualità

| Aspetto | Stato | Note |
|---------|-------|------|
| **Architecture** | 75% | T-006 DIP, T-008 UoW da risolvere |
| **Thread Safety** | 85% | PROT-001, PERS-003, DEV-002 da risolvere |
| **Resource Management** | 70% | Memory leak eventi (T-003) |
| **Input Validation** | 75% | MAC, PartNumber non validati |
| **Performance** | 80% | N+1 query (T-002) |
| **Code Consistency** | 70% | Duplicazioni in Services/GUI, ISP (SVC-008) |
| **Test Coverage** | 95%+ | 643 CI, 951 Windows |
| **Feature Completeness** | 90% | Firmware upload BLE (T-009) da completare |

---

## Issue per Categoria

### Bug (6)
- PROT-001, PROT-002, PROT-003
- GUI-001
- SVC-005, SVC-006

### Architecture (3)
- T-006 (DIP Violation)
- T-007 (Leaky Abstraction)
- T-008 (Missing UoW)

### Feature Incompleta (2)
- PROT-007 (IFirmwareUploader)
- GUI-010 (Firmware upload simulato)

### Code Smell (12)
- PERS-001, PERS-008, PERS-009, PERS-010
- SVC-002
- DEV-003
- GUI-002, GUI-004, GUI-006, GUI-008, GUI-012
- CORE-001, CORE-007

### Design (10)
- PERS-004
- PROT-004, PROT-005
- DEV-001, DEV-004
- GUI-007
- CORE-003, CORE-004, CORE-009
- SVC-008

### Performance (4)
- PERS-006
- SVC-003, SVC-004
- CORE-006

### Anti-Pattern (2)
- SVC-001
- GUI-003

### Documentation (3)
- DEV-005
- GUI-009
- PERS-005

### Resource Management (2)
- GUI-005
- PROT-006

### UX (1)
- GUI-011 (Dialog non annulla operazione)

### Inconsistenza (4)
- CORE-005, CORE-008
- SVC-009
- SVC-007

---

## Come Contribuire

1. Seleziona issue da priorità alta o Top 10
2. Crea branch: `fix/{issue-id}` (es. `fix/gui-001`)
3. Implementa soluzione proposta nel file ISSUES.md del componente
4. Aggiungi test se applicabile
5. Aggiorna status issue a "Risolto" con data e branch
6. Pull Request verso `main`

---

## Links

- [ISSUES_TEMPLATE.md](./Docs/Standards/Templates/ISSUES_TEMPLATE.md) - Template per nuove issue
- [copilot-instructions.md](.github/copilot-instructions.md) - Istruzioni progetto
- [issues-agent.md](.github/agents/issues-agent.md) - Agent per analisi issue

---

## Changelog

| Data | Modifica |
|------|----------|
| 2026-03-12 | Aggiunte issue Firmware: PROT-007, PERS-008/009/010, GUI-010/011/012, T-009 (53 totali) |
| 2026-03-10 | ✅ **GUI-001 risolta** - Sottoscrizioni duplicate login (branch `fix/gui-001`) |
| 2026-03-10 | Aggiunta analisi cross-cutting: +4 CORE, +2 SVC, +3 T-xxx (47 issue totali) |
| 2026-03-10 | Creazione iniziale con 34 issue da 6 componenti |

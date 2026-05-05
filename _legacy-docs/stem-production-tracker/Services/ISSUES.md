# Services - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunità di refactoring e violazioni di best practice per il componente **Services**.

> **Ultimo aggiornamento:** 2026-03-10

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 1 | 0 |
| **Media** | 4 | 0 |
| **Bassa** | 4 | 0 |

**Totale aperte:** 9  
**Totale risolte:** 0

---

## Issue Trasversali Correlate

| ID | Titolo | Status | Impatto su Services |
|----|--------|--------|---------------------|
| **PERS-002** | Manca Concurrency Token | Aperto | Services non riceverà `DbUpdateConcurrencyException` per gestire conflitti |

→ [Infrastructure.Persistence/ISSUES.md](../Infrastructure.Persistence/ISSUES.md) per dettagli.

---

## Indice Issue Aperte

- [SVC-001 - Reflection in TestSessionMapper per aggiungere execution](#svc-001--reflection-in-testsessionmapper-per-aggiungere-execution)
- [SVC-002 - Duplicazione logica MapDeviceToDomainAsync in tutti i SessionService](#svc-002--duplicazione-logica-mapdevicetodomainasync-in-tutti-i-sessionservice)
- [SVC-003 - N+1 Query in PhaseService.GetByAssemblerAsync](#svc-003--n1-query-in-phaseservicegetbyassemblerasync)
- [SVC-004 - N+1 Query in DeviceService.GetByWorkOrderIdAsync e simili](#svc-004--n1-query-in-deviceservicegetbyworkorderidasync-e-simili)
- [SVC-005 - Mancata gestione transazionale in CompleteAsync](#svc-005--mancata-gestione-transazionale-in-completeasync)
- [SVC-006 - UserService.DeleteAsync non verifica esistenza](#svc-006--userservicedeleteasync-non-verifica-esistenza)
- [SVC-007 - Services mancano ArgumentNullException.ThrowIfNull nel costruttore](#svc-007--services-mancano-argumentnullexceptionthrowifnull-nel-costruttore)
- [SVC-008 - IDeviceService viola ISP (troppi metodi)](#svc-008--ideviceservice-viola-isp-troppi-metodi)
- [SVC-009 - Inconsistenza API Task vs Task<T>](#svc-009--inconsistenza-api-task-vs-taskt)

---

## Indice Issue Risolte

(Nessuna issue risolta)

---

## Priorità Alta

### SVC-001 - Reflection in TestSessionMapper per aggiungere execution

**Categoria:** Anti-Pattern  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

`TestSessionMapper.AddExecutionInternal()` usa reflection per accedere al campo privato `_executions` di `TestSession`. Questo è un **anti-pattern** grave che:
- Bypassa l'incapsulamento del domain model
- È fragile (cambio nome campo = runtime error)
- Ha performance overhead
- Non è AOT-compatible

#### File Coinvolti

- `Services\Mapping\TestSessionMapper.cs` (righe 77-84)

#### Codice Problematico

```csharp
/// <summary>Aggiunge execution bypassando il check sullo stato</summary>
private static void AddExecutionInternal(TestSession session, CheckExecution execution)
{
    var field = typeof(TestSession).GetField("_executions",
        System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
    var list = field?.GetValue(session) as List<CheckExecution>;
    list?.Add(execution);  // Può fallire silenziosamente!
}
```

#### Problema Specifico

Il problema è che `TestSession.AddExecution()` lancia se `Status == Completed`. Ma quando si ricostruisce una sessione completata dal DB, bisogna poter aggiungere le executions storiche.

#### Soluzione Proposta

**Opzione A: Modificare `TestSession.Restore()` per accettare executions**

La soluzione corretta è già presente in `AssemblySession.Restore()` ma non usata correttamente in `TestSessionMapper`:

```csharp
// TestSession.cs già supporta questo!
public static TestSession Restore(
    int id,
    Device device,
    TestSheet sheet,
    DateTime startedAt,
    string firmwareVersion,
    SessionStatus status,
    DateTime? completedAt = null,
    string? secondarySerial = null,
    string? secondaryFirmware = null)
{
    // Ma manca il parametro executions!
}
```

**Aggiungere parametro `executions` a `TestSession.Restore()`:**

```csharp
public static TestSession Restore(
    int id,
    Device device,
    TestSheet sheet,
    DateTime startedAt,
    string firmwareVersion,
    SessionStatus status,
    DateTime? completedAt,
    IEnumerable<CheckExecution> executions,  // NUOVO
    string? secondarySerial = null,
    string? secondaryFirmware = null)
{
    var session = new TestSession(device, sheet, startedAt, firmwareVersion, secondarySerial, secondaryFirmware)
    {
        Id = id,
        Status = status,
        CompletedAt = completedAt
    };

    foreach (var exec in executions)
        session._executions.Add(exec);

    return session;
}
```

**Poi aggiornare `TestSessionMapper.ToDomainWithExecutions()`:**

```csharp
public static TestSession ToDomainWithExecutions(
    TestSessionEntity entity,
    Device device,
    TestSheet sheet,
    IEnumerable<CheckExecutionEntity> executions)
{
    var domainExecutions = executions
        .OrderBy(e => e.ExecutedAt)
        .Select(CheckExecutionMapper.ToDomain);

    return TestSession.Restore(
        entity.Id,
        device,
        sheet,
        entity.StartedAt,
        entity.FirmwareVersion,
        entity.Status,
        entity.CompletedAt,
        domainExecutions,  // Passa executions al factory method
        entity.SecondarySerial,
        entity.SecondaryFirmware);
}
```

#### Benefici Attesi

- Eliminazione reflection
- Codice AOT-compatible
- Incapsulamento rispettato
- Consistenza con `AssemblySession.Restore()`

---

## Priorità Media

### SVC-002 - Duplicazione logica MapDeviceToDomainAsync in tutti i SessionService

**Categoria:** Code Smell  
**Priorità:** Media  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Il metodo `MapDeviceToDomainAsync()` è **identico** in `AssemblySessionService` e `TestSessionService`. Viola DRY.

#### File Coinvolti

- `Services\AssemblySessionService.cs` (righe 238-250)
- `Services\TestSessionService.cs` (righe 200-212)

#### Codice Problematico

```csharp
// Identico in entrambi i file!
private async Task<Device> MapDeviceToDomainAsync(DeviceEntity entity, CancellationToken ct)
{
    var workOrderEntity = await _workOrderRepository.GetByIdAsync(entity.WorkOrderId, ct)
        ?? throw new KeyNotFoundException($"WorkOrder with id '{entity.WorkOrderId}' not found");

    var phaseEntity = await _phaseRepository.GetByIdAsync(entity.PhaseId, ct)
        ?? throw new KeyNotFoundException($"Phase with id '{entity.PhaseId}' not found");

    var workOrder = WorkOrderMapper.ToDomain(workOrderEntity);
    var phase = PhaseMapper.ToDomain(phaseEntity, workOrder);

    return DeviceMapper.ToDomain(entity, workOrder, phase);
}
```

#### Soluzione Proposta

**Opzione A: Estrarre in classe helper/service condivisa**

```csharp
// Services/Mapping/DeviceMappingHelper.cs
public class DeviceMappingHelper
{
    private readonly IWorkOrderRepository<WorkOrderEntity> _workOrderRepository;
    private readonly IPhaseRepository<PhaseEntity> _phaseRepository;

    public DeviceMappingHelper(
        IWorkOrderRepository<WorkOrderEntity> workOrderRepository,
        IPhaseRepository<PhaseEntity> phaseRepository)
    {
        _workOrderRepository = workOrderRepository;
        _phaseRepository = phaseRepository;
    }

    public async Task<Device> MapToDomainAsync(DeviceEntity entity, CancellationToken ct)
    {
        // ... logica comune
    }
}
```

**Opzione B: Usare IDeviceService.GetByIdAsync() direttamente**

I SessionService potrebbero dipendere da `IDeviceService` invece di fare il mapping manualmente.

#### Benefici Attesi

- Eliminazione ~24 righe duplicate
- Singolo punto di manutenzione
- Facile aggiunta di caching se necessario

---

### SVC-003 - N+1 Query in PhaseService.GetByAssemblerAsync

**Categoria:** Performance  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Il metodo `GetByAssemblerAsync()` esegue una query per ogni fase per recuperare il relativo WorkOrder, causando N+1 query.

#### File Coinvolti

- `Services\PhaseService.cs` (righe 86-103)

#### Codice Problematico

```csharp
public async Task<IReadOnlyList<Phase>> GetByAssemblerAsync(string assemblerName, CancellationToken ct = default)
{
    var entities = await _phaseRepository.GetByAssemblerAsync(assemblerName, ct);

    var result = new List<Phase>();
    foreach (var entity in entities)
    {
        // N query qui! Una per ogni entity.WorkOrderId
        var workOrderEntity = await _workOrderRepository.GetByIdAsync(entity.WorkOrderId, ct);
        if (workOrderEntity is null) continue;

        var workOrder = WorkOrderMapper.ToDomain(workOrderEntity);
        result.Add(PhaseMapper.ToDomain(entity, workOrder));
    }

    return result;
}
```

#### Soluzione Proposta

**Opzione A: Eager loading nel repository**

Il repository già fa `.Include(p => p.WorkOrder)`, quindi le entity hanno già il WorkOrder navigazionale:

```csharp
public async Task<IReadOnlyList<Phase>> GetByAssemblerAsync(string assemblerName, CancellationToken ct = default)
{
    var entities = await _phaseRepository.GetByAssemblerAsync(assemblerName, ct);

    return entities
        .Where(e => e.WorkOrder is not null)  // Se usato Include
        .Select(e =>
        {
            var workOrder = WorkOrderMapper.ToDomain(e.WorkOrder);
            return PhaseMapper.ToDomain(e, workOrder);
        })
        .ToList();
}
```

**Opzione B: Batch load WorkOrders**

```csharp
var workOrderIds = entities.Select(e => e.WorkOrderId).Distinct().ToList();
var workOrders = await _workOrderRepository.GetByIdsAsync(workOrderIds, ct);  // Metodo da aggiungere
var workOrderDict = workOrders.ToDictionary(w => w.Id);

// Poi usa il dizionario
```

#### Benefici Attesi

- Riduzione da N+1 query a 1-2 query
- Performance migliorata con molte fasi
- Scalabilità garantita

---

### SVC-004 - N+1 Query in DeviceService.GetByWorkOrderIdAsync e simili

**Categoria:** Performance  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

I metodi `GetByWorkOrderIdAsync()`, `GetByPhaseIdAsync()`, `GetByStatusAsync()` in `DeviceService` eseguono N query per caricare WorkOrder e Phase per ogni device.

#### File Coinvolti

- `Services\DeviceService.cs` (righe 52-89)

#### Codice Problematico

```csharp
public async Task<IReadOnlyList<Device>> GetByWorkOrderIdAsync(int workOrderId, CancellationToken ct = default)
{
    var entities = await _deviceRepository.GetByWorkOrderIdAsync(workOrderId, ct);
    var result = new List<Device>();

    foreach (var entity in entities)
    {
        result.Add(await MapToDomainAsync(entity, ct));  // N+1 query qui!
    }

    return result;
}
```

Dove `MapToDomainAsync()` fa 2 query (WorkOrder + Phase) per ogni device.

#### Soluzione Proposta

Identica a SVC-003: usare Include nel repository o batch load.

```csharp
public async Task<IReadOnlyList<Device>> GetByWorkOrderIdAsync(int workOrderId, CancellationToken ct = default)
{
    // Carica tutto in anticipo
    var workOrderEntity = await _workOrderRepository.GetByIdAsync(workOrderId, ct)
        ?? throw new KeyNotFoundException(...);
    
    var workOrder = WorkOrderMapper.ToDomain(workOrderEntity);

    // Carica le fasi dell'ODL (batch)
    var phaseEntities = await _phaseRepository.GetByWorkOrderIdAsync(workOrderId, ct);
    var phases = phaseEntities.ToDictionary(
        p => p.Id,
        p => PhaseMapper.ToDomain(p, workOrder));

    // Ora mappa i device senza query
    var entities = await _deviceRepository.GetByWorkOrderIdAsync(workOrderId, ct);
    
    return entities
        .Select(e => DeviceMapper.ToDomain(e, workOrder, phases[e.PhaseId]))
        .ToList();
}
```

#### Benefici Attesi

- Riduzione da 2N+1 query a 3 query
- Performance significativamente migliorata
- Scalabilità con ODL grandi (50+ device)

---

## Priorità Bassa

### SVC-005 - Mancata gestione transazionale in CompleteAsync

**Categoria:** Bug  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

I metodi `CompleteAsync()` di `AssemblySessionService` e `TestSessionService` aggiornano sia la sessione che il device in due operazioni separate, senza transazione esplicita. Se il secondo update fallisce, si ha uno stato inconsistente.

#### File Coinvolti

- `Services\AssemblySessionService.cs` (righe 183-207)
- `Services\TestSessionService.cs` (righe 142-169)

#### Codice Problematico

```csharp
public async Task CompleteAsync(int sessionId, CancellationToken ct = default)
{
    // ... validazioni ...

    // Update 1
    session.Complete(DateTime.UtcNow);
    await _sessionRepository.UpdateAsync(sessionEntity, ct);

    // Update 2 - Se fallisce qui, la sessione è già completata ma device no!
    var device = await MapDeviceToDomainAsync(deviceEntity, ct);
    device.StartTesting();
    await _deviceRepository.UpdateAsync(deviceEntity, ct);
}
```

#### Soluzione Proposta

**Usare IDbContextTransaction:**

```csharp
public async Task CompleteAsync(int sessionId, CancellationToken ct = default)
{
    using var transaction = await _context.Database.BeginTransactionAsync(ct);
    try
    {
        // Update 1
        await _sessionRepository.UpdateAsync(sessionEntity, ct);

        // Update 2
        await _deviceRepository.UpdateAsync(deviceEntity, ct);

        await transaction.CommitAsync(ct);
    }
    catch
    {
        await transaction.RollbackAsync(ct);
        throw;
    }
}
```

**Nota:** Richiede accesso a `AppDbContext` nei service o un wrapper per transazioni.

#### Benefici Attesi

- Atomicità garantita
- Nessuno stato inconsistente
- Rollback automatico su failure

---

### SVC-006 - UserService.DeleteAsync non verifica esistenza

**Categoria:** Bug  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

`UserService.DeleteAsync()` chiama direttamente `SoftDeleteAsync` senza verificare che l'utente esista, a differenza degli altri service.

#### File Coinvolti

- `Services\UserService.cs` (righe 84-87)

#### Codice Problematico

```csharp
public async Task DeleteAsync(int id, CancellationToken ct = default)
{
    await _repository.SoftDeleteAsync(id, ct);  // Nessun check esistenza!
}
```

**Confronto con altri service:**

```csharp
// WorkOrderService.cs - pattern corretto
public async Task DeleteAsync(int id, CancellationToken ct = default)
{
    _ = await _repository.GetByIdAsync(id, ct)
        ?? throw new KeyNotFoundException($"WorkOrder with id '{id}' not found");

    await _repository.SoftDeleteAsync(id, ct);
}
```

#### Soluzione Proposta

```csharp
public async Task DeleteAsync(int id, CancellationToken ct = default)
{
    _ = await _repository.GetByIdAsync(id, ct)
        ?? throw new KeyNotFoundException($"User with ID {id} not found.");

    await _repository.SoftDeleteAsync(id, ct);
}
```

#### Benefici Attesi

- Comportamento consistente con gli altri service
- Errore chiaro se utente non esiste

---

### SVC-007 - Services mancano ArgumentNullException.ThrowIfNull nel costruttore

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Alcuni service non validano i parametri del costruttore, mentre altri lo fanno. Inconsistenza.

#### File Coinvolti

- `Services\AssemblySessionService.cs` (costruttore, mancano validazioni)
- `Services\TestSessionService.cs` (costruttore, mancano validazioni)
- `Services\UserService.cs` (costruttore, manca validazione)

#### Codice Problematico

```csharp
// UserService.cs - manca validazione
public UserService(IUserRepository<UserEntity> repository)
{
    _repository = repository;  // Nessun ThrowIfNull!
}

// DeviceService.cs - ha validazione (pattern corretto)
public DeviceService(
    IDeviceRepository<DeviceEntity> deviceRepository,
    IWorkOrderRepository<WorkOrderEntity> workOrderRepository,
    ...)
{
    ArgumentNullException.ThrowIfNull(deviceRepository);
    ArgumentNullException.ThrowIfNull(workOrderRepository);
    // ...
}
```

#### Soluzione Proposta

Aggiungere `ArgumentNullException.ThrowIfNull()` per tutti i parametri del costruttore in tutti i service.

#### Benefici Attesi

- Fail-fast su null injection
- Comportamento consistente
- Errori più chiari in fase di DI setup

---

### SVC-008 - IDeviceService viola ISP (troppi metodi)

**Categoria:** Design / ISP Violation  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

`IDeviceService` ha 14+ metodi che coprono responsabilità diverse:
- CRUD device (5 metodi)
- Transizioni stato (4 metodi)  
- Gestione FunctionalGroups (3 metodi)
- Configurazione (2 metodi)

Questo viola il **Interface Segregation Principle** (ISP): i client sono costretti a dipendere da metodi che non usano.

#### File Coinvolti

- `Services\Interfaces\IDeviceService.cs`

#### Codice Problematico

```csharp
public interface IDeviceService
{
    // CRUD (5)
    Task<Device> GetByIdAsync(...)
    Task<Device> GetByFullIdAsync(...)
    Task<IReadOnlyList<Device>> GetByWorkOrderIdAsync(...)
    Task<Device> CreateAsync(...)
    Task DeleteAsync(...)

    // State transitions (4)
    Task StartProductionAsync(...)
    Task StartTestingAsync(...)
    Task ReturnToProductionAsync(...)
    Task CompleteAsync(...)

    // FunctionalGroups (3)
    Task SetFunctionalGroupAsync(...)
    Task<IReadOnlyList<FunctionalGroup>> GetFunctionalGroupsAsync(...)
    Task RemoveFunctionalGroupAsync(...)

    // Query (2)
    Task<IReadOnlyList<Device>> GetByPhaseIdAsync(...)
    Task<IReadOnlyList<Device>> GetByStatusAsync(...)
}
```

#### Soluzione Proposta

**Opzione A: Segregare in interfacce più piccole**

```csharp
public interface IDeviceQueryService
{
    Task<Device> GetByIdAsync(...);
    Task<Device> GetByFullIdAsync(...);
    Task<IReadOnlyList<Device>> GetByWorkOrderIdAsync(...);
    Task<IReadOnlyList<Device>> GetByPhaseIdAsync(...);
    Task<IReadOnlyList<Device>> GetByStatusAsync(...);
}

public interface IDeviceCommandService
{
    Task<Device> CreateAsync(...);
    Task DeleteAsync(...);
}

public interface IDeviceWorkflowService
{
    Task StartProductionAsync(...);
    Task StartTestingAsync(...);
    Task ReturnToProductionAsync(...);
    Task CompleteAsync(...);
}

public interface IFunctionalGroupService
{
    Task SetFunctionalGroupAsync(...);
    Task<IReadOnlyList<FunctionalGroup>> GetFunctionalGroupsAsync(...);
    Task RemoveFunctionalGroupAsync(...);
}
```

**Opzione B: Mantenere interfaccia unica (status quo)**

Per progetti piccoli-medi, un'interfaccia "fat" può essere accettabile se ben documentata.

#### Benefici Attesi

- Interfacce più coese
- Dependency injection più preciso
- Mocking più semplice nei test
- Conformità SOLID

---

## Priorità Bassa (Nuove)

### SVC-009 - Inconsistenza API Task vs Task<T>

**Categoria:** Design / Inconsistenza  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Pattern inconsistente nei service: alcuni metodi ritornano `Task` (void), altri `Task<T>`. Il chiamante non sa lo stato dell'entità dopo l'operazione senza ri-leggerla.

#### File Coinvolti

- `Services\Interfaces\IDeviceService.cs`
- `Services\Interfaces\IAssemblySessionService.cs`
- `Services\Interfaces\ITestSessionService.cs`

#### Codice Problematico

```csharp
// Alcuni ritornano void (non permettono chaining)
Task StartProductionAsync(int deviceId, ...)      // ❌ Non ritorna Device
Task CompleteAsync(int sessionId, ...)            // ❌ Non ritorna Session

// Altri ritornano l'entità aggiornata
Task<Device> CreateAsync(...)                     // ✅ Ritorna Device
Task<AssemblySession> StartAsync(...)             // ✅ Ritorna Session
```

#### Problema Specifico

```csharp
// Dopo StartProductionAsync, il chiamante non conosce il nuovo stato
await _deviceService.StartProductionAsync(deviceId);
// Device.Status è ora InProduction, ma non ho l'oggetto aggiornato!
// Devo fare un'altra query:
var updatedDevice = await _deviceService.GetByIdAsync(deviceId);
```

#### Soluzione Proposta

**Standardizzare: tutti i metodi command ritornano l'entità aggiornata**

```csharp
// Prima
Task StartProductionAsync(int deviceId, CancellationToken ct = default);

// Dopo
Task<Device> StartProductionAsync(int deviceId, CancellationToken ct = default);
```

#### Benefici Attesi

- API consistente
- Meno query di re-fetch
- Chaining possibile
- Stato sempre noto dopo operazione

---

## Issue Risolte

(Nessuna issue risolta al momento)

---

## Wontfix

(Nessuna issue wontfix al momento)

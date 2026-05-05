# Infrastructure.Persistence - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunità di refactoring e violazioni di best practice per il componente **Infrastructure.Persistence**.

> **Ultimo aggiornamento:** 2026-03-11

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 1 | 0 |
| **Media** | 4 | 0 |
| **Bassa** | 5 | 0 |

**Totale aperte:** 10  
**Totale risolte:** 0

---

## Indice Issue Aperte

- [PERS-001 - Repository duplicano logica CRUD](#pers-001--repository-duplicano-logica-crud)
- [PERS-002 - Manca Concurrency Token su entità critiche](#pers-002--manca-concurrency-token-su-entità-critiche)
- [PERS-003 - JsonTestSheetProvider non è thread-safe per EnsureAllLoadedAsync](#pers-003--jsontestsheetprovider-non-è-thread-safe-per-ensureallloadedasync)
- [PERS-004 - CheckExecutionEntity FK mutualmente esclusivi non validati a DB](#pers-004--checkexecutionentity-fk-mutualmente-esclusivi-non-validati-a-db)
- [PERS-005 - JsonException silenziosa in JsonTestSheetProvider](#pers-005--jsonexception-silenziosa-in-jsontestsheetprovider)
- [PERS-006 - Mancano indici su colonne usate in query frequenti](#pers-006--mancano-indici-su-colonne-usate-in-query-frequenti)
- [PERS-007 - DeviceRepository.GetByFullIdAsync parsing naive del FullId](#pers-007--devicerepositorygetbyfulllidasync-parsing-naive-del-fullid)
- [PERS-008 - AzureFirmwareProvider non usa IHttpClientFactory](#pers-008--azurefirmwareprovider-non-usa-ihttpclientfactory)
- [PERS-009 - AzureFirmwareProvider.Dispose non thread-safe](#pers-009--azurefirmwareproviderdispose-non-thread-safe)
- [PERS-010 - StubFirmwareProvider lista statica non estensibile](#pers-010--stubfirmwareprovider-lista-statica-non-estensibile)

---

## Indice Issue Risolte

(Nessuna issue risolta)

---

## Priorità Alta

### PERS-002 - Manca Concurrency Token su entità critiche

**Categoria:** Bug  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Le entità critiche (`DeviceEntity`, `AssemblySessionEntity`, `TestSessionEntity`) non hanno un campo `RowVersion` per gestire i conflitti di concorrenza ottimistica. In un ambiente multi-PC (come specificato nei requisiti) questo può causare lost updates silenti.

#### File Coinvolti

- `Infrastructure.Persistence\Entities\DeviceEntity.cs`
- `Infrastructure.Persistence\Entities\AssemblySessionEntity.cs`
- `Infrastructure.Persistence\Entities\TestSessionEntity.cs`

#### Problema Specifico

Scenario: Due operatori aprono lo stesso device contemporaneamente.
1. Operatore A legge Device con Status = InProduction
2. Operatore B legge lo stesso Device con Status = InProduction
3. Operatore A completa il montaggio → Status = InTesting, salva
4. Operatore B completa il montaggio → Status = InTesting, salva (SOVRASCRIVE modifiche di A!)

Senza concurrency token, l'ultimo salvataggio "vince" silenziosamente.

#### Soluzione Proposta

**Aggiungere RowVersion a BaseEntity:**

```csharp
public abstract class BaseEntity : IEntity
{
    public int Id { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime? DeletedAt { get; set; }

    [Timestamp]
    public byte[] RowVersion { get; set; } = null!;
}
```

**Oppure solo sulle entità critiche:**

```csharp
public class DeviceEntity : BaseEntity
{
    // ...

    [Timestamp]
    public byte[] RowVersion { get; set; } = null!;
}
```

**Migration:**

```csharp
migrationBuilder.AddColumn<byte[]>(
    name: "RowVersion",
    table: "Devices",
    type: "BLOB",
    rowVersion: true,
    nullable: false,
    defaultValue: Array.Empty<byte>());
```

#### Benefici Attesi

- Rilevamento conflitti di concorrenza
- `DbUpdateConcurrencyException` invece di lost updates
- Possibilità di implementare retry o merge logic

---

## Priorità Media

### PERS-001 - Repository duplicano logica CRUD

**Categoria:** Code Smell  
**Priorità:** Media  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Tutti i repository (`WorkOrderRepository`, `PhaseRepository`, `DeviceRepository`, ecc.) implementano la stessa logica per `GetByIdAsync`, `GetAllAsync`, `AddAsync`, `UpdateAsync`, `SoftDeleteAsync`. Sono ~50 righe duplicate per ogni repository (8 repository = ~400 righe duplicate).

#### File Coinvolti

- `Infrastructure.Persistence\Repositories\*.cs` (tutti gli 8 repository)

#### Codice Problematico

```csharp
// Identico in tutti i repository
public async Task<WorkOrderEntity?> GetByIdAsync(int id, CancellationToken ct = default)
{
    return await _context.WorkOrders.FirstOrDefaultAsync(w => w.Id == id, ct);
}

public async Task<IReadOnlyList<WorkOrderEntity>> GetAllAsync(bool includeDeleted = false, CancellationToken ct = default)
{
    var query = includeDeleted
        ? _context.WorkOrders.IgnoreQueryFilters()
        : _context.WorkOrders;

    return await query.ToListAsync(ct);
}

// ... AddAsync, UpdateAsync, SoftDeleteAsync identici
```

#### Soluzione Proposta

**Opzione A: Repository base generico**

```csharp
public abstract class RepositoryBase<TEntity> : IRepository<TEntity>
    where TEntity : BaseEntity
{
    protected readonly AppDbContext Context;
    protected abstract DbSet<TEntity> DbSet { get; }

    protected RepositoryBase(AppDbContext context) => Context = context;

    public virtual async Task<TEntity?> GetByIdAsync(int id, CancellationToken ct = default)
        => await DbSet.FirstOrDefaultAsync(e => e.Id == id, ct);

    public virtual async Task<IReadOnlyList<TEntity>> GetAllAsync(bool includeDeleted = false, CancellationToken ct = default)
    {
        var query = includeDeleted ? DbSet.IgnoreQueryFilters() : DbSet;
        return await query.ToListAsync(ct);
    }

    public virtual async Task<TEntity> AddAsync(TEntity entity, CancellationToken ct = default)
    {
        DbSet.Add(entity);
        await Context.SaveChangesAsync(ct);
        return entity;
    }

    public virtual async Task UpdateAsync(TEntity entity, CancellationToken ct = default)
    {
        DbSet.Update(entity);
        await Context.SaveChangesAsync(ct);
    }

    public virtual async Task SoftDeleteAsync(int id, CancellationToken ct = default)
    {
        var entity = await DbSet.IgnoreQueryFilters().FirstOrDefaultAsync(e => e.Id == id, ct);
        if (entity is not null)
        {
            entity.IsDeleted = true;
            entity.DeletedAt = DateTime.UtcNow;
            await Context.SaveChangesAsync(ct);
        }
    }
}

// Repository specifici ereditano
public class WorkOrderRepository : RepositoryBase<WorkOrderEntity>, IWorkOrderRepository<WorkOrderEntity>
{
    protected override DbSet<WorkOrderEntity> DbSet => Context.WorkOrders;

    public WorkOrderRepository(AppDbContext context) : base(context) { }

    // Solo metodi specifici
    public async Task<WorkOrderEntity?> GetByNumberAsync(string number, CancellationToken ct = default)
        => await Context.WorkOrders.FirstOrDefaultAsync(w => w.Number == number, ct);
}
```

#### Benefici Attesi

- Eliminazione ~400 righe di codice duplicato
- Singolo punto di manutenzione per logica CRUD
- Repository specifici contengono solo metodi specifici

---

### PERS-003 - JsonTestSheetProvider non è thread-safe per EnsureAllLoadedAsync

**Categoria:** Bug  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Il metodo `EnsureAllLoadedAsync()` in `JsonTestSheetProvider` controlla `_allLoaded` senza sincronizzazione. Se due thread chiamano `GetByProductTypeAsync()` contemporaneamente, entrambi potrebbero eseguire il caricamento.

#### File Coinvolti

- `Infrastructure.Persistence\TestSheets\Providers\JsonTestSheetProvider.cs` (righe 114-150)

#### Codice Problematico

```csharp
private bool _allLoaded;  // Non volatile, nessun lock

private async Task EnsureAllLoadedAsync(CancellationToken ct)
{
    if (_allLoaded)  // Race condition qui
        return;

    // ... carica tutti i file ...

    _allLoaded = true;
}
```

#### Soluzione Proposta

**Opzione A: SemaphoreSlim**

```csharp
private readonly SemaphoreSlim _loadLock = new(1, 1);
private bool _allLoaded;

private async Task EnsureAllLoadedAsync(CancellationToken ct)
{
    if (Volatile.Read(ref _allLoaded))
        return;

    await _loadLock.WaitAsync(ct);
    try
    {
        if (_allLoaded)  // Double-check
            return;

        // ... carica tutti i file ...

        Volatile.Write(ref _allLoaded, true);
    }
    finally
    {
        _loadLock.Release();
    }
}
```

**Opzione B: Lazy<Task> (più elegante)**

```csharp
private readonly Lazy<Task> _loadAllTask;

public JsonTestSheetProvider(string dataPath)
{
    _dataPath = dataPath;
    _loadAllTask = new Lazy<Task>(LoadAllAsync);
}

private async Task EnsureAllLoadedAsync(CancellationToken ct)
{
    await _loadAllTask.Value;
}
```

#### Benefici Attesi

- Thread-safety garantita
- Caricamento singolo anche con chiamate concorrenti
- Pattern standard per lazy initialization async

---

### PERS-006 - Mancano indici su colonne usate in query frequenti

**Categoria:** Performance  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Alcune colonne usate frequentemente in WHERE clause non hanno indici. Man mano che il DB cresce, le query diventeranno più lente.

#### Colonne senza indice usate in query

| Tabella | Colonna | Repository Method |
|---------|---------|-------------------|
| `Phases` | `AssignedAssembler` | `GetByAssemblerAsync` |
| `Phases` | `WorkOrderId` | `GetByWorkOrderIdAsync` |
| `Devices` | `WorkOrderId` | `GetByWorkOrderIdAsync` |
| `Devices` | `PhaseId` | `GetByPhaseIdAsync` |
| `Devices` | `Status` | `GetByStatusAsync` |
| `Users` | `Username` | `GetByUsernameAsync` |
| `Users` | `Role` | `GetByRoleAsync` |

#### Soluzione Proposta

**Migration per aggiungere indici:**

```csharp
public partial class AddFrequentQueryIndexes : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateIndex(
            name: "IX_Phases_AssignedAssembler",
            table: "Phases",
            column: "AssignedAssembler");

        migrationBuilder.CreateIndex(
            name: "IX_Devices_Status",
            table: "Devices",
            column: "Status");

        migrationBuilder.CreateIndex(
            name: "IX_Users_Username",
            table: "Users",
            column: "Username",
            unique: true);  // Username dovrebbe essere univoco!

        migrationBuilder.CreateIndex(
            name: "IX_Users_Role",
            table: "Users",
            column: "Role");
    }
}
```

#### Benefici Attesi

- Query più veloci su tabelle grandi
- Username.Unique garantito a livello DB
- Prevenzione degradazione performance

---

## Priorità Bassa

### PERS-004 - CheckExecutionEntity FK mutualmente esclusivi non validati a DB

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

`CheckExecutionEntity` ha `AssemblySessionId` e `TestSessionId` che dovrebbero essere mutualmente esclusivi (uno deve essere valorizzato, l'altro null). Questa regola non è enforced a livello database.

#### File Coinvolti

- `Infrastructure.Persistence\Entities\CheckExecutionEntity.cs` (righe 10-14)

#### Codice Problematico

```csharp
/// <summary>FK verso AssemblySession (mutualmente esclusivo con TestSessionId)</summary>
public int? AssemblySessionId { get; set; }

/// <summary>FK verso TestSession (mutualmente esclusivo con AssemblySessionId)</summary>
public int? TestSessionId { get; set; }
```

#### Soluzione Proposta

**Check constraint in migration:**

```csharp
migrationBuilder.Sql(@"
    ALTER TABLE CheckExecutions 
    ADD CONSTRAINT CK_CheckExecution_SessionXOR 
    CHECK (
        (AssemblySessionId IS NOT NULL AND TestSessionId IS NULL) OR
        (AssemblySessionId IS NULL AND TestSessionId IS NOT NULL)
    )
");
```

#### Benefici Attesi

- Integrità dati garantita a livello DB
- Impossibile inserire record con entrambi i FK valorizzati
- Impossibile inserire record con entrambi i FK null

---

### PERS-005 - JsonException silenziosa in JsonTestSheetProvider

**Categoria:** Observability  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

In `JsonTestSheetProvider`, le `JsonException` vengono catturate e ignorate silenziosamente. Se un file JSON è malformato, non c'è modo di saperlo.

#### File Coinvolti

- `Infrastructure.Persistence\TestSheets\Providers\JsonTestSheetProvider.cs` (righe 107-111, 146-148)

#### Codice Problematico

```csharp
catch (JsonException)
{
    // Log error in production  <-- Commento ma nessun log!
    return null;
}

// e anche:
catch (JsonException)
{
    // Skip invalid files  <-- Silenzioso!
}
```

#### Soluzione Proposta

**Opzione A: Aggiungere ILogger**

```csharp
public sealed class JsonTestSheetProvider : ITestSheetProvider
{
    private readonly ILogger<JsonTestSheetProvider>? _logger;

    public JsonTestSheetProvider(string dataPath, ILogger<JsonTestSheetProvider>? logger = null)
    {
        _dataPath = dataPath;
        _logger = logger;
    }

    private async Task<TestSheet?> LoadFromFileAsync(string partNumber, CancellationToken ct)
    {
        // ...
        catch (JsonException ex)
        {
            _logger?.LogWarning(ex, 
                "Failed to parse test sheet from {FilePath}", filePath);
            return null;
        }
    }
}
```

#### Benefici Attesi

- Errori di parsing visibili nei log
- Facilità di debug in produzione
- Pattern standard per dependency injection di logger

---

### PERS-007 - DeviceRepository.GetByFullIdAsync parsing naive del FullId

**Categoria:** Bug  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Il metodo `GetByFullIdAsync` usa `Split('-')` assumendo che il FullId abbia sempre il formato `{workOrderNumber}-{serialSuffix}`. Se `workOrderNumber` contiene un trattino, il parsing fallisce.

#### File Coinvolti

- `Infrastructure.Persistence\Repositories\DeviceRepository.cs` (righe 61-76)

#### Codice Problematico

```csharp
public async Task<DeviceEntity?> GetByFullIdAsync(string fullId, CancellationToken ct = default)
{
    // fullId format: "{workOrderNumber}-{serialSuffix}" es. "12345-001"
    var parts = fullId.Split('-');
    if (parts.Length != 2)  // <-- Fallisce se WO è "12-345"
        return null;

    var workOrderNumber = parts[0];
    var serialSuffix = parts[1];
    // ...
}
```

#### Soluzione Proposta

**Opzione A: Split dall'ultimo trattino**

```csharp
public async Task<DeviceEntity?> GetByFullIdAsync(string fullId, CancellationToken ct = default)
{
    if (string.IsNullOrWhiteSpace(fullId))
        return null;

    // L'ultimo segmento dopo "-" è il serialSuffix
    var lastDashIndex = fullId.LastIndexOf('-');
    if (lastDashIndex <= 0 || lastDashIndex == fullId.Length - 1)
        return null;

    var workOrderNumber = fullId[..lastDashIndex];
    var serialSuffix = fullId[(lastDashIndex + 1)..];

    return await _context.Devices
        .Include(d => d.WorkOrder)
        .FirstOrDefaultAsync(d =>
            d.WorkOrder.Number == workOrderNumber &&
            d.SerialSuffix == serialSuffix, ct);
}
```

**Nota:** Il problema esiste anche in `PhaseRepository.GetByFullIdAsync` con il separatore `/`.

#### Benefici Attesi

- Robustezza con numeri ODL che contengono trattini
- Parsing corretto in tutti i casi edge

---

## Issue Risolte

(Nessuna issue risolta al momento)

---

### PERS-008 - AzureFirmwareProvider non usa IHttpClientFactory

**Categoria:** Best Practice  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-11

#### Descrizione

`AzureFirmwareProvider` crea un `HttpClient` nel costruttore e lo dispone nel `Dispose()`. Questo è sconsigliato perché:
1. HttpClient è thread-safe e pensato per essere riutilizzato
2. Creare nuove istanze può esaurire le socket disponibili
3. Non beneficia del pooling delle connessioni

#### File Coinvolti

- `Infrastructure.Persistence\Firmware\Providers\AzureFirmwareProvider.cs` (righe 43-56)

#### Codice Problematico

```csharp
public AzureFirmwareProvider(IOptions<FirmwareApiOptions> options)
{
    _httpClient = new HttpClient  // Creazione diretta
    {
        BaseAddress = new Uri(_options.BaseUrl)
    };
    _httpClient.DefaultRequestHeaders.Add("X-Api-Key", _options.ApiKey);
}

public void Dispose() => _httpClient.Dispose();
```

#### Soluzione Proposta

Usare `IHttpClientFactory`:

```csharp
// Registrazione in DI
services.AddHttpClient<IFirmwareProvider, AzureFirmwareProvider>(client =>
{
    client.BaseAddress = new Uri(options.BaseUrl);
    client.DefaultRequestHeaders.Add("X-Api-Key", options.ApiKey);
});

// In AzureFirmwareProvider
public AzureFirmwareProvider(HttpClient httpClient, IOptions<FirmwareApiOptions> options)
{
    _httpClient = httpClient;  // Iniettato, non creato
    _options = options.Value;
}
// Niente Dispose - gestito dal factory
```

---

### PERS-009 - AzureFirmwareProvider.Dispose non thread-safe

**Categoria:** Bug Potenziale  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-11

#### Descrizione

Il `Dispose()` non è protetto da chiamate multiple o concorrenti. Se chiamato più volte o durante un'operazione async, potrebbe causare `ObjectDisposedException`.

#### File Coinvolti

- `Infrastructure.Persistence\Firmware\Providers\AzureFirmwareProvider.cs` (riga 118)

#### Codice Problematico

```csharp
public void Dispose() => _httpClient.Dispose();
```

#### Soluzione Proposta

Pattern Dispose standard:

```csharp
private bool _disposed;

public void Dispose()
{
    Dispose(true);
    GC.SuppressFinalize(this);
}

protected virtual void Dispose(bool disposing)
{
    if (_disposed) return;
    if (disposing)
    {
        _httpClient.Dispose();
    }
    _disposed = true;
}
```

**Nota:** Se si adotta PERS-008 (IHttpClientFactory), questa issue diventa obsoleta.

---

### PERS-010 - StubFirmwareProvider lista statica non estensibile

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-11

#### Descrizione

La lista dei firmware fake in `StubFirmwareProvider` è hardcodata nel codice. Per aggiungere nuovi firmware di test serve ricompilare.

#### File Coinvolti

- `Infrastructure.Persistence\Firmware\Providers\StubFirmwareProvider.cs` (righe 13-36)

#### Codice Problematico

```csharp
private static readonly List<FirmwareInfo> _stubFirmwares =
[
    new("2.1.0", ProductType.OptimusXp, ...),
    // ... hardcoded
];
```

#### Soluzione Proposta

Caricare da file JSON in development:

```csharp
public StubFirmwareProvider()
{
    var path = Path.Combine(AppContext.BaseDirectory, "Firmware", "Data", "stub-firmwares.json");
    if (File.Exists(path))
    {
        var json = File.ReadAllText(path);
        _stubFirmwares = JsonSerializer.Deserialize<List<FirmwareInfo>>(json) ?? _defaultFirmwares;
    }
    else
    {
        _stubFirmwares = _defaultFirmwares;
    }
}
```

#### Benefici

- Sviluppatori possono aggiungere firmware di test senza ricompilare
- Consistente con pattern DeviceDefinitions e TestSheets

---

## Wontfix

(Nessuna issue wontfix al momento)

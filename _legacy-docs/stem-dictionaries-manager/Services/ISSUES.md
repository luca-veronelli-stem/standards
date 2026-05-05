# Services - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunità di refactoring e violazioni di best practice per il componente **Services**.

> **Ultimo aggiornamento:** 2026-04-10

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 0 | 3 |
| **Media** | 0 | 4 |
| **Bassa** | 3 | 2 |

**Totale aperte:** 3  
**Totale risolte:** 9

---

## Indice Issue Aperte

- [SVC-005 - CommandService.GetWithDeviceStatesAsync non espone DeviceStates](#svc-005--commandservicegetwithdevicestatesasync-non-espone-devicestates)
- [SVC-006 - Manca validazione business rules centralizzata](#svc-006--manca-validazione-business-rules-centralizzata)
- [SVC-007 - DependencyInjection non valida prerequisiti](#svc-007--dependencyinjection-non-valida-prerequisiti)

## Indice Issue Risolte

- [SVC-002 - Manca IAuditService per gestione audit trail](#svc-002--manca-iauditservice-per-gestione-audit-trail)
- [SVC-012 - Mapper + Service per StandardVariableOverride (T-006)](#svc-012--mapper--service-per-standardvariableoverride-t-006)
- [SVC-010 - Class1.cs placeholder non rimosso](#svc-010--class1cs-placeholder-non-rimosso)
- [SVC-003 - GetAllAsync senza paginazione nei services](#svc-003--getallasync-senza-paginazione-nei-services) (Wontfix)
- [SVC-009 - VariableMapper.ToDomain non mappa Format](#svc-009--variablemappertodomain-non-mappa-format)
- [SVC-011 - Refactoring Services per Domain v2](#svc-011--refactoring-services-per-domain-v2)
- [SVC-008 - DictionaryService.AddAsync blocca Shared Peripheral se Standard esiste](#svc-008--dictionaryserviceaddasync-blocca-shared-peripheral-se-standard-esiste)
- [SVC-004 - Mancano mapper per BoardMapper con overload](#svc-004--mancano-mapper-per-boardmapper-con-overload)
- [SVC-001 - Services dipendono direttamente da AppDbContext](#svc-001--services-dipendono-direttamente-da-appdbcontext-risolto)

---

## Issue Risolte

### SVC-002 - Manca IAuditService per gestione audit trail

**Categoria:** Feature Mancante  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** ✅Risolto  
**Data Apertura:** 2026-03-18  
**Data Risoluzione:** 2026-04-08  
**Branch:** fix/svc-002

#### Soluzione Implementata

1. **Creato** `AuditEntryMapper.cs`: ToDomain, ToEntity, ToDomainList (no UpdateEntity — AuditEntry immutabile)
2. **Creato** `IAuditService.cs`: 5 metodi Query + 3 metodi Log (parametri espliciti, no generics)
3. **Creato** `AuditService.cs`: implementazione con validazione input e factory methods del domain model
4. **Modificato** `DependencyInjection.cs`: +`IAuditService` registration
5. **Modificato** `IAuditEntryRepository.cs`: +`GetByDateRangeAsync`
6. **Modificato** `AuditEntryRepository.cs`: implementazione `GetByDateRangeAsync`

#### Design

- **Query** (per futura GUI "Cronologia"): GetByIdAsync, GetByEntityAsync, GetByUserAsync, GetRecentAsync, GetByDateRangeAsync
- **Log** (chiamati dagli altri service in futuro): LogCreateAsync, LogUpdateAsync, LogDeleteAsync — usano `AuditEntry.ForCreate/ForUpdate/ForDelete` factory methods
- **No `<T>` generico**: serializzazione JSON è responsabilità del chiamante (il service che fa il CRUD)
- **Immutabile**: nessun UpdateAsync/DeleteAsync nel service (come nel repository)

#### Test Aggiunti

- `AuditEntryMapperTests.cs`: 10 metodi (ToDomain, ToEntity, ToDomainList, RoundTrip, null guards)
- `AuditServiceTests.cs`: 20 metodi (Query + Log + validazione + scenario full trail)
- `AuditEntryRepositoryTests.cs`: +3 metodi per GetByDateRangeAsync
- `DependencyInjectionTests.cs`: +2 metodi (RegistersAuditService, AllServicesResolvable)

#### Benefici Ottenuti

- Gestione centralizzata dell'audit trail a livello applicativo ✅
- Query su audit trail per entity, user, data, recenti ✅
- Metodi Log pronti per integrazione con altri service ✅
- Parametri espliciti — zero accoppiamento con domain models ✅
- **Log attivato in 5 service** (16 punti: Add/Update/Delete) con `ICurrentUserProvider` ✅
- **ICurrentUserProvider** singleton settato dalla GUI dopo login ✅

---

## Priorità Bassa

### SVC-005 - CommandService.GetWithDeviceStatesAsync non espone DeviceStates

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-18  

#### Descrizione

`GetWithDeviceStatesAsync` carica i DeviceStates ma il Domain Model `Command` non li espone. Il chiamante deve usare `GetDeviceStateAsync` separatamente.

#### File Coinvolti

- `Services/CommandService.cs` (righe 85-95)
- `Core/Models/Command.cs` (manca collezione DeviceStates)

#### Codice Problematico

```csharp
public async Task<Command?> GetWithDeviceStatesAsync(int id, CancellationToken ct = default)
{
    var entity = await _repository.GetWithDeviceStatesAsync(id, ct);
    if (entity is null)
        return null;
    
    var command = CommandMapper.ToDomain(entity);
    // Nota: DeviceStates sono caricati ma non esposti nel Domain Model Command.
    // Per accedere agli stati, usare GetDeviceStateAsync o SetDeviceStateAsync.
    return command;
}
```

#### Soluzione Proposta

**Opzione A: Estendere Domain Model**

```csharp
// Core/Models/Command.cs
public class Command
{
    // ... existing
    private readonly List<CommandDeviceState> _deviceStates = [];
    public IReadOnlyList<CommandDeviceState> DeviceStates => _deviceStates.AsReadOnly();
}

// CommandMapper - aggiungere mapping DeviceStates
```

**Opzione B: DTO dedicato (se non vogliamo modificare Domain)**

```csharp
public record CommandWithStates(Command Command, IReadOnlyList<CommandDeviceState> States);
```

#### Benefici Attesi

- API più intuitiva
- Riduzione chiamate N+1

---

### SVC-006 - Manca validazione business rules centralizzata

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-18  

#### Descrizione

Le business rules (unicità nome, unicità indirizzo, etc.) sono sparse nei vari services. Manca un layer di validazione centralizzato.

#### File Coinvolti

- Tutti i files in `Services/*.cs`

#### Esempio Problematico

```csharp
// DictionaryService.cs - validazione inline
var existingByName = await _dictionaryRepository.GetByNameAsync(dictionary.Name, ct);
if (existingByName is not null)
    throw new InvalidOperationException($"Dictionary with name '{dictionary.Name}' already exists.");

// VariableService.cs - stessa logica duplicata
var existingByAddress = await _repository.GetByAddressAsync(...);
if (existingByAddress is not null)
    throw new InvalidOperationException(...);
```

#### Soluzione Proposta

Introdurre un Validator pattern:

```csharp
// Services/Validation/IDictionaryValidator.cs
public interface IDictionaryValidator
{
    Task<ValidationResult> ValidateForCreateAsync(Dictionary dictionary, CancellationToken ct);
    Task<ValidationResult> ValidateForUpdateAsync(Dictionary dictionary, CancellationToken ct);
}

// ValidationResult
public record ValidationResult(bool IsValid, IReadOnlyList<string> Errors);

// Usage in service
public async Task<Dictionary> AddAsync(Dictionary dictionary, CancellationToken ct = default)
{
    var validation = await _validator.ValidateForCreateAsync(dictionary, ct);
    if (!validation.IsValid)
        throw new ValidationException(validation.Errors);
    // ...
}
```

#### Benefici Attesi

- Business rules centralizzate e testabili
- Riuso delle validazioni
- Messaggi di errore consistenti

---

### SVC-007 - DependencyInjection non valida prerequisiti

**Categoria:** Robustezza  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-18  

#### Descrizione

`AddServices()` richiede che `AddInfrastructure()` sia stato chiamato prima, ma non lo valida. Se Infrastructure non è registrato, si ottiene errore runtime non chiaro.

#### File Coinvolti

- `Services/DependencyInjection.cs`

#### Codice Attuale

```csharp
public static IServiceCollection AddServices(this IServiceCollection services)
{
    // Richiede che Infrastructure sia già registrato (AddInfrastructure).
    // <-- Ma non lo verifica!
    services.AddScoped<IDictionaryService, DictionaryService>();
    // ...
}
```

#### Soluzione Proposta

```csharp
public static IServiceCollection AddServices(this IServiceCollection services)
{
    // Verifica prerequisiti
    if (!services.Any(s => s.ServiceType == typeof(IDictionaryRepository)))
        throw new InvalidOperationException(
            "Infrastructure services not registered. Call AddInfrastructure() before AddServices().");
    
    services.AddScoped<IDictionaryService, DictionaryService>();
    // ...
    return services;
}
```

#### Benefici Attesi

- Fail-fast con messaggio chiaro
- Documentazione implicita delle dipendenze

---

## Issue Risolte

### SVC-012 - Mapper + Service per StandardVariableOverride (T-006)

**Categoria:** Refactoring  
**Priorità:** Alta  
**Impatto:** Alto — cambiamento di dominio fondamentale  
**Status:** ✅Risolto  
**Data Apertura:** 2026-03-30  
**Data Risoluzione:** 2026-04-07  
**Branch:** fix/t-006  
**Parent Issue:** [T-006](../ISSUES_TRACKER.md#t-006--standardvariableoverride-per-dizionario-domain-v7)

#### Soluzione Implementata

1. **Creato** `StandardVariableOverrideMapper.cs`: ToDomain, ToEntity, UpdateEntity, ToDomainList
2. **Eliminato** `VariableDeviceStateMapper.cs`
3. **Modificato** `BitInterpretationMapper.cs`: `DeviceId` → `DictionaryId` in tutti i metodi
4. **Modificato** `IVariableService.cs`: rimossi `*DeviceState*`, aggiunti `SetOverrideAsync`, `GetOverrideAsync`, `GetOverridesByDictionaryAsync`, `GetOverridesByVariableAsync`, `*ForDictionary*`
5. **Modificato** `VariableService.cs`: `IVariableDeviceStateRepository` → `IStandardVariableOverrideRepository`, implementazione completa con BR-011 (v7)

#### Benefici Ottenuti

- Override per-dizionario con BR-011 enforced ✅
- BitInterpretation risoluzione per-dizionario > template (BR-018) ✅
- API semanticamente corretta (dizionario, non device) ✅
- Mapper completo con ToDomainList ✅

---

### SVC-010 - Class1.cs placeholder non rimosso

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Nullo  
**Status:** ✅Risolto  
**Data Apertura:** 2026-03-24  
**Data Risoluzione:** 2026-03-25  
**Branch:** fix/svc-003

#### Soluzione Implementata

File `Services/Class1.cs` eliminato.

#### Benefici Ottenuti

- Codebase più pulita ✅
- Nessuna classe vuota nel namespace ✅

---

### SVC-003 - GetAllAsync senza paginazione nei services

**Categoria:** Performance  
**Priorità:** Media  
**Impatto:** Basso (per questo progetto)  
**Status:** ⚪ Wontfix  
**Data Apertura:** 2026-03-18  
**Data Chiusura:** 2026-03-25  
**Motivazione:** Duplicato di INFRA-002

#### Descrizione Originale

I metodi `GetAllAsync` nei services caricano l'intera collezione in memoria senza paginazione.

#### Razionale Wontfix

1. **INFRA-002 già copre questo caso**: Il warning `Debug.WriteLineIf` aggiunto in `RepositoryBase.GetAllAsync` notifica lo sviluppatore se una tabella supera 500 record
2. **I Services chiamano i Repository**: Quindi il warning viene già emesso quando un Service chiama `GetAllAsync`
3. **Desktop app con tabelle piccole**: Paginazione = 2 query (Count + Skip/Take) = più lento per dataset piccoli
4. **YAGNI**: Se in futuro serve paginazione, si aggiungerà quando necessario

#### Riferimento

Vedi [INFRA-002](../Infrastructure/ISSUES.md#infra-002--getallasync-senza-paginazione-rischia-performance-issues) per la soluzione implementata.

---

### SVC-009 - VariableMapper.ToDomain non mappa Format

**Categoria:** Bug (Data Loss)  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** ✅Risolto  
**Data Apertura:** 2026-03-24  
**Data Risoluzione:** 2026-03-25  
**Branch:** fix/svc-009

#### Soluzione Implementata

Mappato `Format` in tutte e 3 le direzioni del `VariableMapper`:

1. **ToDomain:** `format: entity.Format` (era `null` con commento errato)
2. **ToEntity:** `Format = domain.Format` (era mancante)
3. **UpdateEntity:** `entity.Format = domain.Format` (era mancante)

#### Test Aggiunti

- Assert `Format` in `ToDomain_ValidEntity_ReturnsVariable`
- Assert `Format` in `ToEntity_ValidDomain_ReturnsEntity`
- Assert `Format` in `UpdateEntity_ValidInputs_UpdatesAllFields`
- Assert `Format` in `RoundTrip_EntityToDomainToEntity_PreservesData`

#### Benefici Ottenuti

- Round-trip corretto per il campo Format ✅
- Nessuna perdita di dati ✅
- Commento errato rimosso ✅

---

### SVC-011 - Refactoring Services per Domain v2

**Categoria:** Refactoring  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-03-25  
**Data Risoluzione:** 2026-03-25  
**Branch:** domain/ridefinizione-dominio-v2  
**Master Issue:** T-002

#### Soluzione Implementata

1. **DELETE:** `Mapping/BoardTypeMapper.cs`
2. **MODIFY:** `BoardMapper.cs` — FirmwareType da Board, DictionaryId?, IsPrimary
3. **MODIFY:** `DictionaryMapper.cs` — IsStandard flag, no DeviceType/BoardType
4. **MODIFY:** `BoardService.cs`, `DictionaryService.cs` — Standard check via IsStandard

#### Benefici Ottenuti

- Services allineati al Domain v2 ✅
- Risolve anche SVC-008 e SVC-004 ✅

---

### SVC-008 - DictionaryService.AddAsync blocca Shared Peripheral se Standard esiste

**Categoria:** Bug  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-03-24  
**Data Risoluzione:** 2026-03-25  
**Branch:** domain/ridefinizione-dominio-v2

#### Soluzione Implementata

Il bug non esiste più: la semantica 3-tuple `(DeviceType?, BoardType?)` è stata sostituita con `IsStandard` flag. La logica di validazione ora controlla solo `if (dictionary.IsStandard)` → verifica unicità.

---

### SVC-004 - Mancano mapper per BoardMapper con overload

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-03-18  
**Data Risoluzione:** 2026-03-25  
**Branch:** domain/ridefinizione-dominio-v2

#### Soluzione Implementata

BoardMapper riscritto: `BoardType` rimosso, `FirmwareType`/`DictionaryId?`/`IsPrimary` mappati direttamente. Nessun Include richiesto per BoardType.

---


### SVC-001 - Services dipendono direttamente da AppDbContext

**Categoria:** Design/Architettura  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-03-18  
**Data Risoluzione:** 2026-03-18  

#### Descrizione

Alcuni services (`DictionaryService`, `VariableService`, `CommandService`) dipendono direttamente da `AppDbContext` oltre che dai repository. Questo viola il pattern Repository e crea accoppiamento con l'infrastruttura.

#### File Coinvolti

- `Services/DictionaryService.cs` (riga 18)
- `Services/VariableService.cs` (riga 19)
- `Services/CommandService.cs` (riga 18)

#### Codice Problematico

```csharp
// DictionaryService.cs
public class DictionaryService : IDictionaryService
{
    private readonly IDictionaryRepository _dictionaryRepository;
    private readonly Infrastructure.AppDbContext _context;  // <-- Dipendenza diretta
    
    // Usato per query dirette:
    var entities = await _context.Dictionaries
        .Include(d => d.BoardType)
        .ToListAsync(ct);
}
```

#### Problema Specifico

- Viola separation of concerns (Services non dovrebbero conoscere EF Core)
- Difficile da testare con mock (richiede DbContext reale o in-memory)
- Query duplicate tra Services e Repository
- Accoppiamento forte con Infrastructure

#### Soluzione Proposta

**Opzione A: Estendere Repository (raccomandata)**

Aggiungere metodi mancanti ai repository invece di usare DbContext direttamente:

```csharp
// IDictionaryRepository.cs
Task<IReadOnlyList<DictionaryEntity>> GetAllWithBoardTypeAsync(CancellationToken ct);

// DictionaryService.cs - dopo
public async Task<IReadOnlyList<Dictionary>> GetAllAsync(CancellationToken ct = default)
{
    var entities = await _dictionaryRepository.GetAllWithBoardTypeAsync(ct);
    return DictionaryMapper.ToDomainList(entities);
}
```

**Opzione B: Unit of Work Pattern**

Introdurre `IUnitOfWork` per coordinare repository senza esporre DbContext.

#### Benefici Attesi

- Services layer completamente disaccoppiato da EF Core
- Test più semplici con mock
- Single responsibility per ogni layer

#### Soluzione Implementata

Applicata **Opzione A: Estensione Repository**:

1. **Nuovi metodi su repository esistenti:**
   - `IDictionaryRepository.GetAllWithBoardTypeAsync()`, `ExistsAsync()`
   - `IVariableRepository.ExistsAsync()`, `GetWithBitInterpretationsAsync()`

2. **Nuovi repository creati:**
   - `IBitInterpretationRepository` / `BitInterpretationRepository`
   - `ICommandDeviceStateRepository` / `CommandDeviceStateRepository`

3. **Services refactored:**
   - `DictionaryService` - rimosso `_context`, usa repository methods
   - `VariableService` - rimosso `_context`, usa `_bitInterpretationRepository`
   - `CommandService` - rimosso `_context`, usa `_deviceStateRepository`

4. **Test aggiornati** per riflettere i nuovi costruttori

**Risultato:** 752 test passati, nessuna dipendenza diretta da `AppDbContext` nei Services.

---

## Wontfix

*(Nessuna issue in wontfix)*

---

## Metriche Qualità Services

| Metrica | Valore | Target |
|---------|--------|--------|
| Copertura test | ~95% | 90% |
| Complessità ciclomatica media | Bassa | Bassa |
| Dipendenze esterne | 2 (Core, Infrastructure) | ≤3 |
| LOC per file (media) | ~120 | ≤200 |
| Numero services | 7 | - |
| Numero mapper | 9 | - |

---

## Note per Sviluppo Futuro

### Export/Import Feature

Quando verrà implementata la funzionalità di export (CSV, JSON), considerare:
- `IExportService` per generazione file
- `IImportService` per parsing e validazione
- Formato compatibile con Excel esistente

### API Layer

Se verrà aggiunto un API layer (REST/GraphQL):
- I services sono già pronti per essere esposti
- Aggiungere DTOs specifici per API
- Gestione errori HTTP-friendly

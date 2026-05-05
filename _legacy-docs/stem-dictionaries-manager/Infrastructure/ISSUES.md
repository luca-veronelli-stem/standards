# Infrastructure - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunità di refactoring e violazioni di best practice per il componente **Infrastructure**.

> **Ultimo aggiornamento:** 2026-04-13

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 0 | 4 |
| **Media** | 0 | 2 |
| **Bassa** | 2 | 1 |

**Totale aperte:** 2  
**Totale risolte:** 7

---

## Issue Trasversali Correlate

| ID | Titolo | Status | Impatto su Infrastructure |
|----|--------|--------|---------------------------|
| **T-006** | StandardVariableOverride per-dizionario (Domain v7) | **✅ Risolto** | **INFRA-009**: ✅ Risolto |
| **T-004** | Aggiungere DB constraints per regole di business | **✅ Risolto** | Migration `AddBusinessRuleConstraints`: 6 constraint aggiunti |
| **T-003** | Aggiungere logging infrastructure | Aperto | ILogger<T> in RepositoryBase e services |

→ [ISSUES_TRACKER.md](../ISSUES_TRACKER.md) per dettagli completi.

---

## Indice Issue Aperte

- [INFRA-005 - CommandEntity.ParametersJson non ha conversione JSON tipizzata](#infra-005--commandentityparametersjson-non-ha-conversione-json-tipizzata)
- [INFRA-006 - DictionaryRepository.GetByNameAsync non normalizza input](#infra-006--dictionaryrepositorygetbynameasync-non-normalizza-input)

## Indice Issue Risolte

- [INFRA-009 - Entity + Repository + Migration per Domain v7 (T-006)](#infra-009--entity--repository--migration-per-domain-v7-t-006)
- [INFRA-003 - DesignTimeDbContextFactory ha path hardcoded fragile](#infra-003--designtimedbcontextfactory-ha-path-hardcoded-fragile)
- [INFRA-002 - GetAllAsync senza paginazione rischia performance issues](#infra-002--getallasync-senza-paginazione-rischia-performance-issues)
- [INFRA-008 - Refactoring Infrastructure per Domain v2](#infra-008--refactoring-infrastructure-per-domain-v2)
- [INFRA-007 - DatabaseSeeder.CreateBoard usa boardTypeId invece di FirmwareType](#infra-007--databaseseedercreateboard-usa-boardtypeid-invece-di-firmwaretype)
- [INFRA-001 - RepositoryBase.DeleteAsync non solleva eccezione se entity non trovata](#infra-001--repositorybasedeleteasync-non-solleva-eccezione-se-entity-non-trovata)
- [INFRA-004 - Mancano repository per BitInterpretation e CommandDeviceState](#infra-004--mancano-repository-per-bitinterpretation-e-commanddevicestate-risolto)

---

## Priorità Media

*(Nessuna issue media priorità aperta)*

---

## Priorità Bassa

### INFRA-005 - CommandEntity.ParametersJson non ha conversione JSON tipizzata

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-18  

#### Descrizione

`CommandEntity.ParametersJson` è una stringa JSON grezza. EF Core 10 supporta conversioni JSON native che renderebbero il codice più type-safe.

#### File Coinvolti

- `Infrastructure/Entities/CommandEntity.cs` (riga 12)
- `Infrastructure/AppDbContext.cs` (configurazione Command)

#### Codice Problematico

```csharp
public class CommandEntity : IAuditable
{
    // ...
    public string ParametersJson { get; set; } = "[]";  // <-- Stringa grezza
}
```

#### Problema Specifico

- Serializzazione/deserializzazione manuale nel Services layer
- Possibili errori JSON non catturati a compile-time
- Non sfrutta le capacità JSON di EF Core 10

#### Soluzione Proposta

```csharp
// Entity
public class CommandEntity : IAuditable
{
    public int Id { get; set; }
    // ...
    public List<string> Parameters { get; set; } = [];
}

// OnModelCreating
modelBuilder.Entity<CommandEntity>(entity =>
{
    entity.Property(e => e.Parameters)
        .HasConversion(
            v => JsonSerializer.Serialize(v, JsonSerializerOptions.Default),
            v => JsonSerializer.Deserialize<List<string>>(v, JsonSerializerOptions.Default) ?? []);
});
```

#### Benefici Attesi

- Type-safety a compile-time
- Meno boilerplate nel Services layer
- Sfrutta funzionalità EF Core moderne

---

### INFRA-006 - DictionaryRepository.GetByNameAsync non normalizza input

**Categoria:** Bug  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-18  

#### Descrizione

`DictionaryRepository.GetByNameAsync` confronta il nome esatto, mentre `UserRepository.GetByUsernameAsync` normalizza l'input con `ToLowerInvariant()`. Inconsistenza tra repository.

#### File Coinvolti

- `Infrastructure/Repositories/DictionaryRepository.cs` (righe 13-17)
- `Infrastructure/Repositories/UserRepository.cs` (righe 13-18 - corretto)

#### Codice Problematico

```csharp
// DictionaryRepository - NON normalizza
public async Task<DictionaryEntity?> GetByNameAsync(string name, 
    CancellationToken cancellationToken = default)
{
    return await DbSet.FirstOrDefaultAsync(d => d.Name == name, cancellationToken);
}

// UserRepository - Normalizza
public async Task<UserEntity?> GetByUsernameAsync(string username, 
    CancellationToken cancellationToken = default)
{
    var normalizedUsername = username.ToLowerInvariant();  // <-- Normalizza
    return await DbSet.FirstOrDefaultAsync(u => u.Username == normalizedUsername, cancellationToken);
}
```

#### Problema Specifico

- `GetByNameAsync("OPTIMUS-XP")` non trova "optimus-xp"
- Dipende da come i dati sono stati inseriti
- Inconsistenza con comportamento UserRepository
- Potrebbe causare bug difficili da debuggare

#### Soluzione Proposta

**Opzione A: Normalizzare nel repository**

```csharp
public async Task<DictionaryEntity?> GetByNameAsync(string name, 
    CancellationToken cancellationToken = default)
{
    var normalizedName = name.ToLowerInvariant();
    return await DbSet.FirstOrDefaultAsync(
        d => d.Name.ToLower() == normalizedName, cancellationToken);
}
```

**Opzione B: Case-insensitive collation (DB level)**

Configurare SQLite con collation NOCASE:
```sql
CREATE TABLE Dictionaries (..., Name TEXT COLLATE NOCASE);
```

#### Benefici Attesi

- Coerenza tra repository
- Ricerca case-insensitive prevedibile
- Meno bug in fase di lookup

---

## Issue Risolte

### INFRA-009 - Entity + Repository + Migration per Domain v7 (T-006)

**Categoria:** Refactoring  
**Priorità:** Alta  
**Impatto:** Alto — cambiamento di dominio fondamentale  
**Status:** ✅Risolto  
**Data Apertura:** 2026-03-30  
**Data Risoluzione:** 2026-04-07  
**Branch:** fix/t-006  
**Parent Issue:** [T-006](../ISSUES_TRACKER.md#t-006--standardvariableoverride-per-dizionario-domain-v7)

#### Soluzione Implementata

1. **Creato** `StandardVariableOverrideEntity.cs`: Id, DictionaryId (FK), StandardVariableId (FK), IsEnabled, Description?, nav Dictionary + StandardVariable
2. **Creato** `IStandardVariableOverrideRepository.cs`: GetByDictionaryIdAsync, GetByDictionaryAndVariableAsync, GetByVariableIdAsync
3. **Creato** `StandardVariableOverrideRepository.cs`
4. **Eliminati** 3 file `VariableDeviceState*` (Entity, Interface, Repository)
5. **Modificato** `BitInterpretationEntity.cs`: `DeviceId?` → `DictionaryId?`, nav `Device?` → `Dictionary?`
6. **Modificato** `VariableEntity.cs`: rimossa navigation `DeviceStates`
7. **Modificato** `DictionaryEntity.cs`: +`StandardVariableOverrides`, +`BitInterpretations`
8. **Modificato** `AppDbContext.cs`: config StandardVariableOverride (BR-010 unique), BitInterpretation con DictionaryId
9. **Modificato** `DependencyInjection.cs`: `IStandardVariableOverrideRepository` registrato
10. **Modificato** `DatabaseSeeder.cs`: commentato SeedSpykeOverridesAsync (TODO riscrittura)
11. **Reset** migration `InitialCreate` rigenerata

#### Benefici Ottenuti

- StandardVariableOverride entity con BR-010 unique constraint ✅
- BitInterpretation scope per-dizionario (BR-017) ✅
- Repository con query per-dizionario e per-variabile ✅
- Migration pulita senza riferimenti a VariableDeviceState ✅

---

### INFRA-003 - DesignTimeDbContextFactory ha path hardcoded fragile

**Categoria:** Manutenibilità  
**Priorità:** Media  
**Impatto:** Basso  
**Status:** ✅Risolto  
**Data Apertura:** 2026-03-18  
**Data Risoluzione:** 2026-03-25  
**Branch:** fix/infra-003

#### Soluzione Implementata

Applicata **Opzione A: Cercare verso l'alto fino a .slnx/.sln**:

```csharp
private static string? FindSolutionDirectory()
{
    // Prova prima con la directory corrente (dove viene eseguito dotnet ef)
    var directory = new DirectoryInfo(Directory.GetCurrentDirectory());

    while (directory != null)
    {
        // Cerca .slnx (nuovo formato) o .sln (legacy)
        if (directory.GetFiles("*.slnx").Length > 0 || directory.GetFiles("*.sln").Length > 0)
            return directory.FullName;

        directory = directory.Parent;
    }

    // Fallback: prova dalla location dell'assembly
    // ...
}
```

#### Miglioramenti rispetto al codice originale

| Aspetto | Prima | Dopo |
|---------|-------|------|
| Path resolution | Hardcoded 4 livelli up | Cerca `.slnx`/`.sln` risalendo |
| Single-file publish | ❌ Crash (Location vuota) | ✅ Fallback su CurrentDirectory |
| CI/CD | ❌ Fragile | ✅ Robusto |
| Validazione | ❌ Nessuna | ✅ Exception con messaggio chiaro |
| Directory Data | ❌ Non creata | ✅ Creata automaticamente |

#### Benefici Ottenuti

- Robustezza in diversi ambienti ✅
- Supporto `.slnx` (nuovo formato .NET 10) ✅
- Fail-fast con messaggio chiaro se solution non trovata ✅
- Creazione automatica directory Data ✅

---

### INFRA-002 - GetAllAsync senza paginazione rischia performance issues

**Categoria:** Performance  
**Priorità:** Media  
**Impatto:** Basso (per questo progetto)  
**Status:** ✅Risolto  
**Data Apertura:** 2026-03-18  
**Data Risoluzione:** 2026-03-25  
**Branch:** fix/infra-002

#### Soluzione Implementata

Approccio **pragmatico**: warning in Debug invece di paginazione.

Per un'app desktop con tabelle piccole (Users, Boards, Dictionaries, Commands < 500 record), la paginazione sarebbe overengineering. Aggiunto invece un **warning automatico** quando il dataset supera 500 record:

```csharp
protected const int LargeResultSetWarningThreshold = 500;

public virtual async Task<IReadOnlyList<TEntity>> GetAllAsync(...)
{
    var result = await DbSet.ToListAsync(cancellationToken);

    // Warning in Debug se il dataset è grande
    Debug.WriteLineIf(result.Count > LargeResultSetWarningThreshold,
        $"[PERFORMANCE WARNING] {typeof(TEntity).Name}: GetAllAsync returned {result.Count} records. " +
        $"Consider adding pagination if this table continues to grow.");

    return result;
}
```

#### Razionale

- Desktop app con single user → nessun beneficio da paginazione
- Paginazione = 2 query (Count + Skip/Take) → **più lento** per dataset piccoli
- Warning in Debug notifica lo sviluppatore se serve azione
- Zero breaking changes, zero overhead in Release

#### Benefici Ottenuti

- Monitoraggio automatico crescita tabelle ✅
- Nessun overhead in produzione ✅
- API invariata (retrocompatibile) ✅
- YAGNI rispettato ✅

### INFRA-008 - Refactoring Infrastructure per Domain v2

**Categoria:** Refactoring  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-03-25  
**Data Risoluzione:** 2026-03-25  
**Branch:** domain/ridefinizione-dominio-v2  
**Master Issue:** T-002

#### Descrizione

Eliminazione `BoardTypeEntity`, `IBoardTypeRepository`, `BoardTypeRepository`. Aggiunta `FirmwareType`, `DictionaryId?`, `IsStandard` su entities. Nuova migration. Riscrittura `DatabaseSeeder`.

#### Soluzione Implementata

1. **DELETE:** `BoardTypeEntity.cs`, `IBoardTypeRepository.cs`, `BoardTypeRepository.cs`
2. **MODIFY:** `BoardEntity.cs`: +FirmwareType, +DictionaryId?, +IsPrimary, -BoardTypeId
3. **MODIFY:** `DictionaryEntity.cs`: +IsStandard, -DeviceType?, -BoardTypeId?
4. **MODIFY:** `AppDbContext.cs`: -BoardTypes DbSet, +Board→Dictionary FK (SetNull)
5. **MODIFY:** `DatabaseSeeder.cs`: riscritto con FirmwareType diretto
6. **MODIFY:** `DependencyInjection.cs`: -IBoardTypeRepository
7. **ADD:** Migration `InitialCreate_DomainV2`

#### Benefici Ottenuti

- Infrastructure allineata al Domain v2 ✅
- Seeder con indirizzi protocol corretti ✅
- Risolve anche INFRA-007 ✅

---

### INFRA-007 - DatabaseSeeder.CreateBoard usa boardTypeId invece di FirmwareType

**Categoria:** Bug  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-03-23  
**Data Risoluzione:** 2026-03-25  
**Branch:** domain/ridefinizione-dominio-v2  

#### Descrizione

`DatabaseSeeder.CreateBoard` calcolava il `ProtocolAddress` usando `boardTypeId` invece di `FirmwareType`. Risolto dal refactoring T-002: `BoardType` rimosso, `CreateBoard` ora accetta `firmwareType` direttamente.

#### Benefici Ottenuti

- Indirizzi protocol corretti ✅
- Coerenza con `Board.CalculateAddress` ✅

---

### INFRA-001 - RepositoryBase.DeleteAsync non solleva eccezione se entity non trovata

**Categoria:** API  
**Priorità:** Alta  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-03-18  
**Data Risoluzione:** 2026-03-18  
**Branch:** fix/infra-001  

#### Descrizione

Il metodo `DeleteAsync` in `RepositoryBase` non notificava il chiamante se l'entity da eliminare non esisteva.

#### Soluzione Implementata

Implementata **Opzione A: Throw se non trovato**.

**Modifiche Effettuate:**

1. **File `Infrastructure/Repositories/RepositoryBase.cs`:**
   - Modificato `DeleteAsync` per lanciare `KeyNotFoundException` se entity non trovata

**Codice Implementato:**

```csharp
public virtual async Task DeleteAsync(int id, CancellationToken cancellationToken = default)
{
    var entity = await GetByIdAsync(id, cancellationToken)
        ?? throw new KeyNotFoundException($"Entity with Id {id} not found.");

    DbSet.Remove(entity);
    await Context.SaveChangesAsync(cancellationToken);
}
```

#### Test Aggiunti

**Integration Tests - `UserRepositoryTests.cs` (1 test):**
- `DeleteAsync_NotFound_ThrowsKeyNotFoundException`

#### Benefici Ottenuti

- Fail-fast su errori di logica ✅
- API più prevedibile ✅
- Coerenza con pattern REST (404 se non trovato) ✅

---

### INFRA-004 - Mancano repository per BitInterpretation e CommandDeviceState

**Categoria:** API  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-03-18  
**Data Risoluzione:** 2026-03-18  
**Branch:** fix/svc-001  

> Nota: Risolto come parte di SVC-001.

#### Descrizione

Le entities `BitInterpretationEntity` e `CommandDeviceStateEntity` non avevano repository dedicati. Erano accessibili solo tramite `Include()` dai parent (Variable, Command).

#### Soluzione Implementata

1. **Creati nuovi repository:**
   - `IBitInterpretationRepository` / `BitInterpretationRepository`
   - `ICommandDeviceStateRepository` / `CommandDeviceStateRepository`

2. **Metodi implementati:**
   - `GetByVariableIdAsync()` per BitInterpretation
   - `GetByCommandIdAsync()`, `GetByCommandAndDeviceAsync()`, `GetByDeviceTypeAsync()` per CommandDeviceState

3. **Registrazione in DependencyInjection.cs**

#### Test Aggiunti

- `BitInterpretationRepositoryTests.cs` (10 test)
- `CommandDeviceStateRepositoryTests.cs` (10 test)

#### Benefici Ottenuti

- API completa per tutte le entities ✅
- Query ottimizzate per casi d'uso specifici ✅
- Coerenza con altri repository ✅
- Services layer disaccoppiato da AppDbContext ✅

---

## Wontfix

*(Nessuna issue in wontfix)*

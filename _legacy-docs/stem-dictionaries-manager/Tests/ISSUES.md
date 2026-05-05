# Tests - ISSUES

> **Scopo:** Questo documento traccia problemi di struttura, copertura, significatività e consistenza per la suite di test del progetto **Stem.Dictionaries.Manager**.

> **Ultimo aggiornamento:** 2026-04-10

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 0 | 3 |
| **Media** | 1 | 4 |
| **Bassa** | 1 | 2 |

**Totale aperte:** 2  
**Totale risolte:** 9

---

## Indice Issue Aperte

- [TEST-011 - Riorganizzazione completa suite di test](#test-011--riorganizzazione-completa-suite-di-test)
- [TEST-006 - Magic strings ripetute nei test](#test-006--magic-strings-ripetute-nei-test)

## Indice Issue Risolte

- [TEST-010 - Aggiornare/riscrittura test per Domain v7 (T-006)](#test-010--aggiornareriscitura-test-per-domain-v7-t-006)
- [TEST-008 - VariableMapperTests non testa Format round-trip](#test-008--variablemappertests-non-testa-format-round-trip)
- [TEST-009 - Aggiornamento test per Domain v2](#test-009--aggiornamento-test-per-domain-v2)
- [TEST-007 - Manca test integration per Shared Peripheral in DictionaryService](#test-007--manca-test-integration-per-shared-peripheral-in-dictionaryservice)
- [TEST-001 - Mancano test per BoardRepository e CommandRepository](#test-001--mancano-test-per-boardrepository-e-commandrepository)
- [TEST-002 - Mancano test per BoardTypeRepository](#test-002--mancano-test-per-boardtyperepository)
- [TEST-003 - Uso di .Wait() bloccante nei costruttori test](#test-003--uso-di-wait-bloccante-nei-costruttori-test)
- [TEST-004 - Mancano test per DependencyInjection](#test-004--mancano-test-per-dependencyinjection-infrastructure-e-services)
- [TEST-005 - Mancano test per scenari di rilavorazione/update entities](#test-005--mancano-test-per-scenari-di-rilavorazioneupdate-entities)

---

## Copertura Attuale

| Componente | Unit | Integration | Copertura |
|------------|------|-------------|-----------|
| Core/Enums (5) | ✅ 16 | - | 100% |
| Core/Models (9) | ✅ 82 | - | 100% |
| Services/Mapping (8) | ✅ 84 | - | ~100% |
| Infrastructure/DI | ✅ 14 | - | 100% |
| Services/DI | ✅ 10 | - | 100% |
| Infrastructure/Repositories (10) | - | ✅ 107 | ~98% |
| Services (5) | - | ✅ 106 | ~95% |
| GUI.Windows/ViewModels (15) | ✅ 254 | ✅ 11 | ~90% |
| GUI.Windows/Services (3) | ✅ 15 | - | ~70% |
| GUI.Windows/Converters (2) | ✅ 20 | - | 100% |
| GUI.Windows/DI | ✅ 22 | - | 100% |

> **Nota:** I conteggi sono metodi test `[Fact]`/`[Theory]`. I metodi `[Theory]` con `[InlineData]` generano più test case nel runner xUnit.

---

## Priorità Media

### TEST-011 — Riorganizzazione completa suite di test

**Categoria:** Struttura/Manutenibilità  
**Priorità:** Media  
**Impatto:** Medio — test incasinati riducono fiducia nella copertura e rallentano lo sviluppo  
**Status:** Aperto  
**Data Apertura:** 2026-04-13  
**Effort stimato:** L (8-16h)

#### Descrizione

La suite di test (~1420 metodi / ~2330 test cases) è cresciuta organicamente per 48 sessioni. Risultato: duplicazioni, namespace inconsistenti, scenari sovrapposti, copertura non verificabile con certezza. Serve una riorganizzazione completa.

#### Problemi Identificati

**1. Namespace e posizionamento file incoerenti**
- `WordBitGroupTests` e `CommandParameterItemTests` in `Unit/GUI/ViewModels/` — sono model test, non ViewModel test
- `SettingsViewModelTests` ancora presente ma Settings rimosso dalla sidebar (UI v1)
- `Unit/GUI/Mocks/` contiene mock usati sia da Unit che da Integration/GUI — dovrebbe essere shared

**2. Duplicazione tra Integration/GUI e Integration/E2E**
- `DictionaryEditFlowTests` (Integration/GUI) e `DictionaryWorkflowTests` (Integration/E2E) testano scenari simili con approcci diversi
- `DeviceFlowTests` + `DeviceDetailFlowTests` (Integration/GUI) vs `DeviceWorkflowTests` (Integration/E2E) — sovrapposizione
- Non è chiaro quale layer sia responsabile di cosa

**3. Mock services duplicati e frammentati**
- `MockDataServices.cs` (450+ righe) con 6+ mock service in un unico file
- `MockServices.cs` con mock UI services — stessa logica, file diverso
- Alcuni test integration (es. `VariableEditFlowTests`) creano mock locali invece di usare quelli centralizzati

**4. Copertura non verificabile**
- Tabella copertura in ISSUES.md è manuale e probabilmente non aggiornata
- Nessun tool di code coverage configurato
- Alcuni componenti a ~70% (GUI Services) senza piano per migliorare

**5. Test "di accumulo" senza valore chiaro**
- Test DI registration (22 per GUI, 14 per Infra, 10 per Services = 46 test) — verificano solo che il DI resolve. Utili ma sproporzionati
- Test enum con `HasExpectedCount` e `HasExpectedValues` — fragili (rompono ogni volta che aggiungi un valore)

**6. Convenzione nomi non uniforme**
- Alcuni: `MethodName_Scenario_Expected` (corretto)
- Altri: `MethodName_ExpectedBehavior` (manca lo scenario)
- Flow tests: nomi lunghi descrittivi vs nomi brevi

#### Soluzione Proposta

**Fase 1 — Namespace e struttura** (4h)
```
Tests/
├── Shared/                          # Mock, factory, costanti (ex Mocks/)
│   ├── TestData.cs                  # Factory + costanti (incorpora TEST-006)
│   ├── MockServices.cs              # Mock UI services
│   └── MockDataServices.cs          # Mock data services
├── Unit/
│   ├── Core/                        # Enums + Models (merge, non separati)
│   ├── Infrastructure/              # DI tests
│   ├── Services/                    # Mapping + DI tests
│   ├── GUI/                         # ViewModels + Converters + Services
│   └── API/                         # Middleware + Mapper
├── Integration/
│   ├── Infrastructure/              # Repository CRUD
│   ├── Services/                    # Service business logic
│   └── Scenarios/                   # Flussi GUI + E2E (merge)
└── E2E/
    ├── DatabaseSeederTests.cs       # Seed verification (170 test)
    └── AuditTrailTests.cs           # Audit verification
```

**Fase 2 — Eliminare duplicazioni** (4h)
- Merge flow tests + workflow tests in `Integration/Scenarios/`
- Consolidare mock in `Shared/`
- Rimuovere test DI ridondanti (tenere 1 per servizio, non 3)

**Fase 3 — Magic strings e factory** (2h)
- Incorpora TEST-006: creare `TestData.cs` con factory method
- Tutti i test usano factory invece di costruttori inline

**Fase 4 — Convenzione nomi** (2h)
- Allineare tutti a `MethodName_Scenario_Expected`
- Rinominare file: `*FlowTests` + `*WorkflowTests` → `*ScenarioTests`

#### Note

- TEST-006 (Magic strings) viene incorporata in questa issue (Fase 3)
- Non aggiungere code coverage tool — verifica manuale è sufficiente per ora
- I 170 test DatabaseSeeder restano separati (sono un mondo a sé)

---

## Priorità Bassa

### TEST-006 - Magic strings ripetute nei test

**Categoria:** Manutenibilità  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-18  

#### Descrizione

Molti test usano magic strings ripetute per nomi, username, dataTypeRaw. Se cambia il formato atteso, bisogna modificare molti file.

#### File Coinvolti

- Tutti i file in `Tests/Unit/Models/`
- Tutti i file in `Tests/Integration/Infrastructure/`

#### Codice Problematico

```csharp
// VariableTests.cs
var variable = new Variable(
    name: "Firmware macchina",
    dataTypeRaw: "uint16_t",  // <-- Ripetuto ovunque
    // ...

// DictionaryTests.cs
var variable = new Variable("Test", 0x00, 0x01, DataTypeKind.UInt8, 
    AccessMode.ReadOnly, "uint8_t");  // <-- Magic string

// UserRepositoryTests.cs
var user = new UserEntity { Username = "luca", DisplayName = "Luca V." };
```

#### Soluzione Proposta

Creare una classe `TestData` con costanti/factory:

```csharp
// Tests/TestData.cs
public static class TestData
{
    public static class DataTypes
    {
        public const string UInt8 = "uint8_t";
        public const string UInt16 = "uint16_t";
        public const string String20 = "String[20]";
    }
    
    public static class Users
    {
        public static UserEntity CreateAdmin() => 
            new() { Username = "admin", DisplayName = "Admin" };
    }
    
    public static Variable CreateVariable(
        string name = "TestVar",
        byte addressHigh = 0x00,
        byte addressLow = 0x01) => 
        new(name, addressHigh, addressLow, DataTypeKind.UInt8, 
            AccessMode.ReadOnly, DataTypes.UInt8);
}
```

#### Benefici Attesi

- Single point of change
- Test più leggibili
- Refactoring più sicuro

---

## Issue Risolte

### TEST-010 - Aggiornare/riscrittura test per Domain v7 (T-006)

**Categoria:** Copertura  
**Priorità:** Alta  
**Impatto:** Alto — test rossi dopo refactoring  
**Status:** ✅Risolto  
**Data Apertura:** 2026-03-30  
**Data Risoluzione:** 2026-04-07  
**Branch:** fix/t-006  
**Parent Issue:** [T-006](../ISSUES_TRACKER.md#t-006--standardvariableoverride-per-dizionario-domain-v7)

#### Descrizione

Aggiornare la suite di test per Domain v7. I test esistenti per VariableDeviceState vanno convertiti a StandardVariableOverride, i test BitInterpretation devono usare DictionaryId invece di DeviceId.

#### Soluzione Implementata

1. **Aggiornati** test BitInterpretation (DeviceId → DictionaryId):
   - `BitInterpretationRepositoryTests.cs`: `DeviceEntity`/`DeviceId` → `DictionaryEntity`/`DictionaryId`, metodo `GetByVariableAndDevice` → `GetByVariableAndDictionary`
   - `BitInterpretationMapperTests.cs`: già aggiornato (INFRA-009/SVC-012)
   - `BitInterpretationTests.cs`: già aggiornato (CORE-008)

2. **Aggiornati** test VariableService (override per-dizionario):
   - `VariableServiceTests.cs`: `SetOverrideAsync` con dizionari reali (FK constraint fix), `GetOverridesByDictionaryAsync`/`GetOverridesByVariableAsync` con dizionari creati nel test, `GetBitInterpretationsForDictionaryAsync` con DictionaryId

3. **Aggiornati** test E2E:
   - `DatabaseSeederTests.cs`: rimossi test Spyke per-device override (seeder non li crea più)
   - `DeviceWorkflowTests.cs`: `VariableDeviceState` per-device → `StandardVariableOverride` per-dizionario
   - `VariableWorkflowTests.cs`: `DeviceId` → `DictionaryId` nelle BitInterpretation

4. **Aggiornati** test GUI:
   - `VariableEditViewModelTests.cs`: `DeviceContext` → `DictionaryContext`, `StandardVariableOverride.Restore` con parametro `description`
   - `DeviceDetailFlowTests.cs`: `ViewType.DeviceVariables` → `ViewType.DictionaryEdit`

5. **Aggiornati** test DI:
   - `DependencyInjectionTests.cs`: `IVariableDeviceStateRepository` → `IStandardVariableOverrideRepository`

6. **Fix test AuditEntityType**:
   - `AuditEntityTypeTests.cs`: count da 7 → 8 (+StandardVariableOverride)

#### Benefici Ottenuti

- 1786/1786 test verdi ✅
- Test allineati al Domain v7 ✅
- Override per-dizionario verificati end-to-end ✅
- FK constraint corretti nei test integration ✅

---

### TEST-008 - VariableMapperTests non testa Format round-trip

**Categoria:** Copertura (legata a bug SVC-009)  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** ✅Risolto  
**Data Apertura:** 2026-03-24  
**Data Risoluzione:** 2026-03-25  
**Branch:** fix/svc-009

#### Soluzione Implementata

Aggiunto `Format` con valore non-null nei test esistenti e verificato in tutti gli Assert:

1. `ToDomain_ValidEntity_ReturnsVariable`: entity con `Format = "%04X"`, assert `result.Format`
2. `ToEntity_ValidDomain_ReturnsEntity`: domain con `format: "%.2f"`, assert `result.Format`
3. `UpdateEntity_ValidInputs_UpdatesAllFields`: domain con `format: "%d ms"`, assert `entity.Format`
4. `RoundTrip_EntityToDomainToEntity_PreservesData`: entity con `Format = "0x%04X"`, assert preservato

#### Benefici Ottenuti

- Round-trip Format verificato ✅
- Regressione protetta ✅
- Implementato insieme al fix SVC-009 ✅

---

### TEST-009 - Aggiornamento test per Domain v2

**Categoria:** Refactoring  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-03-25  
**Data Risoluzione:** 2026-03-25  
**Branch:** domain/ridefinizione-dominio-v2  
**Master Issue:** T-002

#### Soluzione Implementata

1. **DELETE:** `BoardTypeTests.cs`, `BoardTypeMapperTests.cs`, `BoardTypeRepositoryTests.cs`
2. **REWRITE:** `BoardTests.cs`, `DictionaryTests.cs`, `BoardMapperTests.cs`, `DictionaryMapperTests.cs` — nuovi campi FirmwareType, DictionaryId, IsStandard
3. **UPDATE:** ~20 file test (integration + GUI mocks) allineati a Domain v2
4. **NEW:** `VariableDeviceStateTests.cs`, `VariableDeviceStateMapperTests.cs`, `VariableDeviceStateRepositoryTests.cs` (SESSION_025)

#### Benefici Ottenuti

- Test allineati al Domain v2 ✅
- 1252/1252 test verdi ✅
- Risolve anche TEST-007 ✅

---

### TEST-007 - Manca test integration per Shared Peripheral in DictionaryService

**Categoria:** Copertura  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-03-24  
**Data Risoluzione:** 2026-03-25  
**Branch:** domain/ridefinizione-dominio-v2

#### Soluzione Implementata

Il concetto di "Shared Peripheral" non esiste più: la semantica 3-tuple `(DeviceType?, BoardType?)` è stata sostituita con `IsStandard` flag e semantica derivata dai Board. I test di `DictionaryService` verificano `IsStandard` uniqueness (BR-004). La semantica Dedicated/Shared/Orphan è derivata a runtime.

---

### TEST-001 - Mancano test per BoardRepository e CommandRepository

**Categoria:** Copertura  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-03-18  
**Data Risoluzione:** 2026-03-18  
**Branch:** fix/test-001-002  

#### Descrizione

I repository `BoardRepository` e `CommandRepository` non avevano file di test dedicati.

#### Soluzione Implementata

Creati i file di test:

**`Tests/Integration/Infrastructure/BoardRepositoryTests.cs` (12 test):**
- `AddAsync_CreatesBoard`
- `GetByIdAsync_ReturnsBoard_WithBoardType`
- `GetByIdAsync_NotFound_ReturnsNull`
- `GetByDeviceTypeAsync_ReturnsMatchingBoards`
- `GetByDeviceTypeAsync_NoMatch_ReturnsEmptyList`
- `GetByDeviceTypeAsync_IncludesBoardType`
- `GetByProtocolAddressAsync_ReturnsBoard`
- `GetByProtocolAddressAsync_NotFound_ReturnsNull`
- `GetByProtocolAddressAsync_IncludesBoardType`
- `DeleteAsync_RemovesBoard`
- `DeleteAsync_NotFound_ThrowsKeyNotFoundException`

**`Tests/Integration/Infrastructure/CommandRepositoryTests.cs` (11 test):**
- `AddAsync_CreatesCommand`
- `GetByIdAsync_ReturnsCommand`
- `GetByIdAsync_NotFound_ReturnsNull`
- `GetByCodeAsync_ReturnsCommand`
- `GetByCodeAsync_DistinguishesRequestFromResponse`
- `GetByCodeAsync_NotFound_ReturnsNull`
- `GetWithDeviceStatesAsync_ReturnsCommand_WithDeviceStates`
- `GetWithDeviceStatesAsync_NoStates_ReturnsEmptyCollection`
- `GetWithDeviceStatesAsync_NotFound_ReturnsNull`
- `GetAllAsync_ReturnsAllCommands`
- `DeleteAsync_RemovesCommand`
- `DeleteAsync_NotFound_ThrowsKeyNotFoundException`

#### Benefici Ottenuti

- Copertura repository completa ✅
- Confidenza nelle query custom ✅
- Regressioni catturate prima ✅

---

### TEST-002 - Mancano test per BoardTypeRepository

**Categoria:** Copertura  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-03-18  
**Data Risoluzione:** 2026-03-18  
**Branch:** fix/test-001-002  

#### Descrizione

`BoardTypeRepository` non aveva test per i metodi custom (`GetByNameAsync`, `GetByFirmwareTypeAsync`).

#### Soluzione Implementata

Creato il file di test:

**`Tests/Integration/Infrastructure/BoardTypeRepositoryTests.cs` (10 test):**
- `AddAsync_CreatesBoardType`
- `GetByIdAsync_ReturnsBoardType`
- `GetByIdAsync_NotFound_ReturnsNull`
- `GetByNameAsync_ExistingName_ReturnsBoardType`
- `GetByNameAsync_NotFound_ReturnsNull`
- `GetByFirmwareTypeAsync_ExistingType_ReturnsBoardType`
- `GetByFirmwareTypeAsync_NotFound_ReturnsNull`
- `GetAllAsync_ReturnsAllBoardTypes`
- `DeleteAsync_RemovesBoardType`
- `DeleteAsync_NotFound_ThrowsKeyNotFoundException`

#### Benefici Ottenuti

- Verifica comportamento lookup per nome/firmwareType ✅
- Copertura metodi custom ✅

---

### TEST-003 - Uso di .Wait() bloccante nei costruttori test

**Categoria:** Anti-Pattern  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-03-18  
**Data Risoluzione:** 2026-03-18  
**Branch:** fix/test-003  

#### Descrizione

Diversi test di integrazione usavano `.Wait()` nei costruttori per setup asincroni, che è un anti-pattern (blocking su async).

#### File Coinvolti (3 file)

- `Tests/Integration/Infrastructure/AuditEntryRepositoryTests.cs`
- `Tests/Integration/Services/DictionaryServiceTests.cs`
- `Tests/Integration/Services/BoardServiceTests.cs`

#### Soluzione Implementata

1. **IntegrationTestBase** ora implementa `IAsyncLifetime` con metodi virtuali:
   - `InitializeAsync()` - default vuoto, override per setup async
   - `DisposeAsync()` - default vuoto, override per cleanup async

2. **Classi derivate** fanno `override InitializeAsync()` invece di `.Wait()`:

```csharp
// Prima (anti-pattern)
public AuditEntryRepositoryTests()
{
    SetupTestUser().Wait();  // ❌ Blocking call
}

// Dopo (best practice)
public override async Task InitializeAsync()
{
    await SetupTestUser();  // ✅ Async all the way
}
```

#### Benefici Ottenuti

- Eliminato anti-pattern blocking ✅
- Coerenza con best practice xUnit ✅
- Previene potenziali deadlock ✅
- Pattern riusabile per futuri test ✅

---

### TEST-004 - Mancano test per DependencyInjection (Infrastructure e Services)

**Categoria:** Struttura/Copertura  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-03-18  
**Data Risoluzione:** 2026-03-18  
**Branch:** fix/test-004  

#### Descrizione

I metodi `AddInfrastructure()` e `AddServices()` non avevano unit test. La struttura cartelle non prevedeva `Unit/Infrastructure/` né `Unit/Services/DependencyInjectionTests.cs`.

#### Soluzione Implementata

Creati i file di test:

**`Tests/Unit/Infrastructure/DependencyInjectionTests.cs` (13 test):**
- `AddInfrastructure_ReturnsServiceCollection`
- `AddInfrastructure_RegistersAppDbContext`
- `AddInfrastructure_RegistersUserRepository`
- `AddInfrastructure_RegistersBoardTypeRepository`
- `AddInfrastructure_RegistersBoardRepository`
- `AddInfrastructure_RegistersDictionaryRepository`
- `AddInfrastructure_RegistersVariableRepository`
- `AddInfrastructure_RegistersCommandRepository`
- `AddInfrastructure_RegistersAuditEntryRepository`
- `AddInfrastructure_RegistersBitInterpretationRepository`
- `AddInfrastructure_RegistersCommandDeviceStateRepository`
- `AddInfrastructure_RegistersRepositoriesAsScoped`
- `AddInfrastructure_SameScopeReturnsSameInstance`

**`Tests/Unit/Services/DependencyInjectionTests.cs` (10 test):**
- `AddServices_ReturnsServiceCollection`
- `AddServices_RegistersDictionaryService`
- `AddServices_RegistersVariableService`
- `AddServices_RegistersCommandService`
- `AddServices_RegistersBoardService`
- `AddServices_RegistersUserService`
- `AddServices_RegistersServicesAsScoped`
- `AddServices_SameScopeReturnsSameInstance`
- `AddServices_WithoutInfrastructure_ThrowsOnResolve`
- `AddServices_AllServicesResolvable`

#### Benefici Ottenuti

- Verifica registrazione DI corretta ✅
- Struttura cartelle più consistente ✅
- Cattura errori di configurazione DI ✅
- Test scoped lifetime verificato ✅

---

### TEST-005 - Mancano test per scenari di rilavorazione/update entities

**Categoria:** Copertura  
**Priorità:** Bassa  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-03-18  
**Data Risoluzione:** 2026-03-18  
**Branch:** fix/test-004  

#### Descrizione

I test di integrazione coprivano principalmente scenari CRUD base (Add, GetById). Mancavano test per scenari più complessi.

#### Soluzione Implementata

Creato il file di test:

**`Tests/Integration/Infrastructure/CrudScenariosTests.cs` (18 test):**

**Update Scenarios (4 test):**
- `UpdateAsync_User_ModifiesDisplayName`
- `UpdateAsync_Dictionary_PreservesVariables`
- `UpdateAsync_Variable_SetsUpdatedAt`
- `UpdateAsync_Command_ModifiesParameters`

**Delete with Cascade (4 test):**
- `DeleteDictionary_CascadesDeleteToVariables`
- `DeleteVariable_CascadesDeleteToBitInterpretations`
- `DeleteCommand_CascadesDeleteToDeviceStates`
- `DeleteBoardType_WithBoards_ThrowsException`

**Unique Constraint Violations (6 test):**
- `AddUser_DuplicateUsername_ThrowsDbUpdateException`
- `AddDictionary_DuplicateName_ThrowsDbUpdateException`
- `AddVariable_DuplicateAddressInSameDictionary_ThrowsDbUpdateException`
- `AddVariable_SameAddressDifferentDictionary_Succeeds`
- `AddCommand_DuplicateCode_ThrowsDbUpdateException`
- `AddCommand_SameCodeDifferentIsResponse_Succeeds`

**Audit Trail Complete Lifecycle (2 test):**
- `AuditTrail_CreateUpdateDelete_TracksAllChanges`
- `AuditTrail_MultipleUpdates_UpdatesTimestampEachTime`

**Repository Update/Delete (2 test):**
- `UserRepository_UpdateAsync_ModifiesEntity`
- `DictionaryRepository_DeleteAsync_RemovesCascadedVariables`

#### Benefici Ottenuti

- Copertura scenari reali di utilizzo ✅
- Verifica comportamento FK (Cascade vs Restrict) ✅
- Test unique constraint violations ✅
- Verifica audit trail completo ✅
- Confidenza in operazioni complesse ✅

---

## Wontfix

*(Nessuna issue in wontfix)*

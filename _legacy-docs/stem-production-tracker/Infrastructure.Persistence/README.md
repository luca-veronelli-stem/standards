# Infrastructure.Persistence

> **Layer di persistenza con EF Core e SQLite per il sistema di tracciamento produzione STEM.**  
> **Ultimo aggiornamento:** 2026-03-11

---

## Panoramica

Il progetto **Infrastructure.Persistence** implementa l'accesso ai dati utilizzando:
- **Entity Framework Core 10** come ORM
- **SQLite** come database di sviluppo (Azure SQL in produzione)
- **Repository Pattern** per l'astrazione dell'accesso ai dati
- **Soft Delete** per tutte le entità (nessuna cancellazione fisica)
- **Device Definitions** per definizioni variabili device (JSON runtime)
- **Test Sheets** per schede collaudo (JSON runtime)
- **Firmware Provider** per gestione firmware (Stub/Azure)

---

## Caratteristiche

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **EF Core DbContext** | ✅ | AppDbContext con global query filters |
| **Entities** | ✅ | 8 entità con audit fields |
| **Repositories** | ✅ | 8 repository con soft delete |
| **Soft Delete** | ✅ | IsDeleted + DeletedAt su tutte le entità |
| **Audit Fields** | ✅ | CreatedAt/UpdatedAt automatici |
| **Device Definitions** | ✅ | JSON files per variabili device (runtime) |
| **Test Sheets** | ✅ | JSON files per schede collaudo con ReferenceValue/Tolerance/Unit |
| **Firmware Provider** | ✅ | StubFirmwareProvider (dev) / AzureFirmwareProvider (prod) |
| **DI Extension** | ✅ | AddPersistence() + AddFirmwareProvider() |
| **Migrations** | ✅ | 4 migrations |

---

## Requisiti

- **.NET 10.0** o superiore

### Dipendenze

| Package | Versione | Uso |
|---------|----------|-----|
| `Microsoft.EntityFrameworkCore` | 10.0.3 | ORM |
| `Microsoft.EntityFrameworkCore.Sqlite` | 10.0.3 | Provider SQLite |
| `Microsoft.EntityFrameworkCore.Design` | 10.0.3 | Migrations (design-time) |
| `Microsoft.Extensions.DependencyInjection.Abstractions` | 10.0.3 | DI extensions |
| `Core` | Project | Interfacce repository |

---

## Quick Start

```csharp
// Registrare i servizi in DI
services.AddPersistence("Data Source=production.db");

// Usare un repository
public class MyService
{
    private readonly IWorkOrderRepository<WorkOrderEntity> _repo;

    public MyService(IWorkOrderRepository<WorkOrderEntity> repo)
    {
        _repo = repo;
    }

    public async Task<WorkOrderEntity?> GetWorkOrder(string number)
    {
        return await _repo.GetByNumberAsync(number);
    }
}
```

### Migrations

```bash
# Creare una nuova migration
dotnet ef migrations add <NomeMigration> -p Infrastructure.Persistence -s Windows.GUI

# Applicare migrations
dotnet ef database update -p Infrastructure.Persistence -s Windows.GUI
```

---

## Struttura

```
Infrastructure.Persistence/
├── AppDbContext.cs              # DbContext con query filters e audit
├── DependencyInjection.cs       # Extension method AddPersistence()
├── DesignTimeDbContextFactory.cs # Factory per EF CLI tools
├── Entities/
│   ├── BaseEntity.cs            # Classe base con audit fields
│   ├── WorkOrderEntity.cs
│   ├── PhaseEntity.cs
│   ├── DeviceEntity.cs
│   ├── FunctionalGroupEntity.cs
│   ├── AssemblySessionEntity.cs
│   ├── TestSessionEntity.cs
│   ├── CheckExecutionEntity.cs
│   └── UserEntity.cs            # Utente del sistema
├── Repositories/
│   ├── WorkOrderRepository.cs
│   ├── PhaseRepository.cs
│   ├── DeviceRepository.cs
│   ├── FunctionalGroupRepository.cs
│   ├── AssemblySessionRepository.cs
│   ├── TestSessionRepository.cs
│   ├── CheckExecutionRepository.cs
│   └── UserRepository.cs        # GetByUsername, GetByRole
├── DeviceDefinitions/           # NEW - Definizioni variabili device
│   ├── Data/
│   │   ├── common/
│   │   │   └── standard-variables.json
│   │   └── devices/
│   │       └── optimus-xp.json
│   ├── Interfaces/
│   │   └── IDeviceDefinitionProvider.cs
│   ├── Models/
│   │   ├── VariableDefinitionDto.cs
│   │   ├── DeviceDefinitionDto.cs
│   │   └── JsonDtos.cs
│   ├── Providers/
│   │   └── JsonFileDefinitionProvider.cs
│   └── README.md
├── TestSheets/                  # NEW - Schede collaudo
│   ├── Data/
│   │   └── optimus-xp.json
│   ├── Interfaces/
│   │   └── ITestSheetProvider.cs
│   ├── Models/
│   │   ├── TestSheetDto.cs
│   │   ├── CheckDefinitionDto.cs
│   │   └── FunctionalGroupTemplateDto.cs
│   ├── Providers/
│   │   └── JsonTestSheetProvider.cs
│   └── README.md
├── Migrations/
│   ├── 20260224085618_InitialCreate.cs
│   └── 20260303151505_UpdateSessionModels.cs
└── Data/
    └── development.db           # Database SQLite (gitignored)
```

---

## Device Definitions

Sistema per definire le variabili dei dispositivi STEM in file JSON, caricati a **runtime**.

→ Vedi [DeviceDefinitions/README.md](./DeviceDefinitions/README.md) per documentazione completa.

### Quick Overview

```
DeviceDefinitions/Data/
├── common/
│   └── standard-variables.json    # Variabili comuni (0x00xx) - 24 vars
└── devices/
    └── optimus-xp.json            # OPTIMUS XP specifiche (0x80xx) - 48 vars
```

### Utilizzo

```csharp
// IDeviceDefinitionProvider è registrato da AddPersistence()
public class MyService
{
    private readonly IDeviceDefinitionProvider _provider;

    public async Task LoadDeviceAsync()
    {
        var definition = await _provider.GetDefinitionAsync("OptimusXp");
        // definition.Variables contiene standard + device-specific merged
    }
}
```

---

## Test Sheets

Sistema per definire le schede collaudo dei prodotti STEM in file JSON, caricati a **runtime**.

→ Vedi [TestSheets/README.md](./TestSheets/README.md) per documentazione completa.

### Quick Overview

```
TestSheets/Data/
└── optimus-xp.json    # Scheda collaudo OPTIMUS XP (27 controlli: 13 Assembly + 14 Testing)
```

### Campi Check Value

I controlli di tipo `Value` supportano:
- `referenceValue`: Valore di riferimento (es. 220)
- `tolerance`: Tolleranza ammessa (es. 5 → ±5)
- `unit`: Unità di misura per display (es. "mm")

Se `referenceValue` è null, il check registra solo il valore (es. finecorsa).

### Utilizzo

```csharp
// ITestSheetProvider è registrato da AddPersistence()
public class MyService
{
    private readonly ITestSheetProvider _provider;

    public async Task LoadTestSheetAsync()
    {
        var sheet = await _provider.GetByPartNumberAsync("OPTIMUS-XP");
        // sheet.Checks contiene la lista dei controlli

        var check = sheet.Checks.First(c => c.Id == 16);
        bool valid = check.IsValueInTolerance(218);  // true (220 ± 5)
    }
}
```
```

---

## API / Componenti

### AppDbContext

| Feature | Descrizione |
|---------|-------------|
| **Global Query Filter** | Esclude automaticamente record con `IsDeleted = true` |
| **Audit Fields** | Imposta `CreatedAt`/`UpdatedAt` automaticamente in SaveChanges |
| **DbSets** | WorkOrders, Phases, Devices, FunctionalGroups, AssemblySessions, TestSessions, CheckExecutions, Users |

### Entities

| Entity | FK | Note |
|--------|-----|------|
| `WorkOrderEntity` | - | Root aggregate |
| `PhaseEntity` | WorkOrderId | `AssignedAssembler` = **username** |
| `DeviceEntity` | WorkOrderId, PhaseId | + `FirmwareVersion`, `BleMacAddress` per collaudo |
| `FunctionalGroupEntity` | DeviceId | Componente tracciato |
| `AssemblySessionEntity` | DeviceId | Sessione montaggio |
| `TestSessionEntity` | DeviceId | Sessione collaudo, legge FirmwareVersion dal device |
| `CheckExecutionEntity` | AssemblySessionId XOR TestSessionId | `Operator` = **username** |
| `UserEntity` | - | Username, DisplayName, Role |

### BaseEntity (Audit Fields)

```csharp
public abstract class BaseEntity
{
    public int Id { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime? DeletedAt { get; set; }
}
```

### DependencyInjection

```csharp
// Registra DbContext + tutti i repository + IDeviceDefinitionProvider
services.AddPersistence("Data Source=app.db");
```

---

## Configurazione

### Connection String

| Ambiente | Connection String |
|----------|-------------------|
| Development | `Data Source=Infrastructure.Persistence/Data/development.db` |
| Production | Azure SQL (TBD) |

### Soft Delete

Tutti i record usano soft delete:
- `IsDeleted = true` marca il record come eliminato
- `DeletedAt` registra quando è stato eliminato
- I query filters escludono automaticamente i record eliminati
- Usare `IgnoreQueryFilters()` per includere i record eliminati

---

## Issue Correlate

→ [Infrastructure.Persistence/ISSUES.md](./ISSUES.md)

---

## Links

- [README Soluzione](../README.md)
- [DeviceDefinitions](./DeviceDefinitions/README.md)
- [Core](../Core/README.md)
- [Services](../Services/README.md)
- [Devices](../Devices/README.md)
- [Infrastructure.Protocol](../Infrastructure.Protocol/README.md)
- [ER Schema](../docs/ER_Schema.puml)
- [Tests](../Tests/README.md)
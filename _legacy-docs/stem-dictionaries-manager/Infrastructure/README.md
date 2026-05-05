# Infrastructure

> **Layer di persistenza con Entity Framework Core, SQLite / Azure SQL e pattern Repository.**  
> **Ultimo aggiornamento:** 2026-04-13

---

## Panoramica

Il progetto **Infrastructure** gestisce la persistenza dati per Stem.Dictionaries.Manager. Implementa:

- **Entity Framework Core** - ORM per accesso dati
- **SQLite** - Database di sviluppo
- **Azure SQL (SQL Server)** - Database di produzione
- **Dual Provider** - Selezionabile via `appsettings.json` (`DatabaseProvider`)
- **Pattern Repository** - Astrazione accesso dati con interfacce
- **Audit automatico** - CreatedAt/UpdatedAt gestiti in SaveChanges

Questo layer è l'unico che conosce il database. I modelli di dominio (Core) sono separati dalle Entity.

---

## Caratteristiche

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **Entities** | ✅ | 10 entity classes con IAuditable |
| **Repositories** | ✅ | 10 repository + base generica |
| **Migrations** | ✅ | SQL Server target (DesignTimeDbContextFactory), SQLite usa EnsureCreated |
| **Dual Provider** | ✅ | SQLite (dev) / SQL Server (prod), selezionabile a runtime |
| **Audit Fields** | ✅ | CreatedAt/UpdatedAt automatici |
| **DI Extension** | ✅ | AddInfrastructure() per registrazione |
| **Database Seeder** | ✅ | Dati iniziali (auto-skip se DB già popolato) |

---

## Requisiti

- **.NET 10.0** o superiore

### Dipendenze

| Package | Versione | Uso |
|---------|----------|-----|
| Microsoft.EntityFrameworkCore | 10.0.5 | ORM |
| Microsoft.EntityFrameworkCore.Sqlite | 10.0.5 | Provider SQLite (sviluppo) |
| Microsoft.EntityFrameworkCore.SqlServer | 10.0.5 | Provider SQL Server (produzione Azure SQL) |
| Microsoft.EntityFrameworkCore.Design | 10.0.5 | Migrations tooling |

### Dipendenze Progetto

| Progetto | Uso |
|----------|-----|
| Core | Enums (DataTypeKind, AccessMode, etc.) |

---

## Quick Start

```csharp
using Infrastructure;
using Microsoft.Extensions.DependencyInjection;

// Registrazione servizi (SQLite)
services.AddInfrastructure("Data Source=dictionaries.db");

// Registrazione servizi (Azure SQL)
services.AddInfrastructure(connectionString, useSqlServer: true);

// Uso repository
public class MyService
{
    private readonly IDictionaryRepository _dictionaries;
    
    public MyService(IDictionaryRepository dictionaries)
    {
        _dictionaries = dictionaries;
    }
    
    public async Task<DictionaryEntity?> GetDictionaryAsync(int id)
    {
        return await _dictionaries.GetByIdAsync(id);
    }
}
```

---

## Struttura

```
Infrastructure/
├── Entities/
│   ├── UserEntity.cs                  # Utente sistema
│   ├── BoardEntity.cs                 # Scheda con FirmwareType, DictionaryId?, IsPrimary
│   ├── VariableEntity.cs              # Variabile dizionario (incl. Format)
│   ├── DictionaryEntity.cs            # Dizionario con IsStandard flag
│   ├── BitInterpretationEntity.cs     # Interpretazione bit bitmapped (v7: DictionaryId?)
│   ├── CommandEntity.cs               # Comando protocollo (ParametersJson)
│   ├── CommandDeviceStateEntity.cs    # Stato comando per device
│   ├── DeviceEntity.cs                # Dispositivo STEM
│   ├── StandardVariableOverrideEntity.cs # Override per-dizionario variabile standard (v7)
│   └── AuditEntryEntity.cs            # Audit trail (no IAuditable)
├── Interfaces/
│   ├── IAuditable.cs                  # Interface per audit fields
│   ├── IRepository.cs                 # Interface generica CRUD
│   ├── IUserRepository.cs
│   ├── IBoardRepository.cs
│   ├── IDictionaryRepository.cs
│   ├── IVariableRepository.cs
│   ├── ICommandRepository.cs
│   ├── IBitInterpretationRepository.cs
│   ├── ICommandDeviceStateRepository.cs
│   ├── IDeviceRepository.cs
│   ├── IStandardVariableOverrideRepository.cs
│   └── IAuditEntryRepository.cs
├── Repositories/
│   ├── RepositoryBase.cs              # Implementazione CRUD comune
│   ├── UserRepository.cs
│   ├── BoardRepository.cs
│   ├── DictionaryRepository.cs
│   ├── VariableRepository.cs
│   ├── CommandRepository.cs
│   ├── BitInterpretationRepository.cs
│   ├── CommandDeviceStateRepository.cs
│   ├── DeviceRepository.cs
│   ├── StandardVariableOverrideRepository.cs
│   └── AuditEntryRepository.cs
├── Migrations/
│   ├── InitialCreate                  # Schema completo Domain v7
│   └── AddBusinessRuleConstraints      # 6 constraint DB per business rules (T-004)
├── AppDbContext.cs                    # DbContext con audit automatico (10 DbSet)
├── DatabaseSeeder.cs                  # Dati iniziali (skip se DB già popolato)
├── DesignTimeDbContextFactory.cs      # Factory per migrations CLI (SQL Server target)
├── DependencyInjection.cs             # Extension method AddInfrastructure()
├── README.md
└── ISSUES.md
```

---

## API / Componenti

### Entities

| Entity | Tabella | IAuditable | Note |
|--------|---------|:----------:|------|
| `UserEntity` | Users | ✅ | Username univoco |
| `BoardEntity` | Boards | ✅ | FirmwareType, DictionaryId?, IsPrimary, ProtocolAddress |
| `VariableEntity` | Variables | ✅ | FK → Dictionary, Format, unique (DictionaryId, AddressHigh, AddressLow) |
| `DictionaryEntity` | Dictionaries | ✅ | IsStandard flag, Name univoco |
| `BitInterpretationEntity` | BitInterpretations | ✅ | FK → Variable, Dictionary? (v7: DictionaryId?) |
| `CommandEntity` | Commands | ✅ | ParametersJson, unique (CodeHigh, CodeLow, IsResponse) |
| `CommandDeviceStateEntity` | CommandDeviceStates | ✅ | FK → Command, DeviceId, unique (CommandId, DeviceId) |
| `DeviceEntity` | Devices | ✅ | Name, MachineCode, Description |
| `StandardVariableOverrideEntity` | StandardVariableOverrides | ✅ | FK → Dictionary, Variable, unique (DictionaryId, StandardVariableId) BR-010 |
| `AuditEntryEntity` | AuditEntries | ❌ | Immutabile, FK → User |

### Repository Interfaces

| Interface | Metodi Custom |
|-----------|---------------|
| `IRepository<T>` | GetByIdAsync, GetAllAsync, AddAsync, UpdateAsync, DeleteAsync |
| `IUserRepository` | GetByUsernameAsync |
| `IBoardRepository` | GetByDeviceIdAsync, GetByProtocolAddressAsync |
| `IDictionaryRepository` | GetByNameAsync, GetWithVariablesAsync, GetAllWithVariablesAsync, GetStandardDictionaryAsync, ExistsAsync |
| `IVariableRepository` | GetByDictionaryIdAsync, GetByAddressAsync, GetWithBitInterpretationsAsync, ExistsAsync |
| `ICommandRepository` | GetByCodeAsync, GetByNameAsync, GetWithDeviceStatesAsync |
| `IBitInterpretationRepository` | GetByVariableIdAsync, GetByVariableAndDictionaryAsync, SyncByVariableIdAsync |
| `ICommandDeviceStateRepository` | GetByCommandAndDeviceAsync, GetByCommandIdAsync, GetByDeviceIdAsync |
| `IDeviceRepository` | GetByNameAsync, GetByMachineCodeAsync |
| `IStandardVariableOverrideRepository` | GetByDictionaryIdAsync, GetByDictionaryAndVariableAsync, GetByVariableIdAsync |
| `IAuditEntryRepository` | GetByEntityAsync, GetByUserAsync, GetRecentAsync, GetByDateRangeAsync |

### Audit Automatico

```csharp
// AppDbContext.SaveChanges() imposta automaticamente:
// - CreatedAt (UTC) per entity Added
// - UpdatedAt (UTC) per entity Modified

public interface IAuditable
{
    DateTime CreatedAt { get; set; }
    DateTime? UpdatedAt { get; set; }
}
```

---

## Configurazione

### Connection String

```csharp
// Sviluppo (SQLite) - default, path in AppData
services.AddInfrastructure("Data Source=path/to/dictionaries.db");

// Produzione (Azure SQL) - connection string da appsettings.json / User Secrets
services.AddInfrastructure(connectionString, useSqlServer: true);
```

### Provider Selection

Il provider è selezionato in `GUI.Windows/appsettings.json`:

```json
{
  "DatabaseProvider": "SqlServer",
  "ConnectionStrings": {
    "SqlServer": "",
    "Sqlite": ""
  }
}
```

- `DatabaseProvider: "SqlServer"` → usa `MigrateAsync()` (migrations versionati)
- `DatabaseProvider: "Sqlite"` (o assente) → usa `EnsureCreatedAsync()` (ricrea schema dal modello)
- Connection string vuota per SQLite → fallback a `%AppData%\STEM\DictionariesManager\`
- Connection string per SQL Server → consigliato via **User Secrets** (non committare nel repo)

### Migrations

Le migrations sono generate per **SQL Server** (target produzione Azure SQL).  
Per SQLite in sviluppo, `EnsureCreatedAsync()` ricrea lo schema dal modello.

```bash
# Creare nuova migration (SQL Server target)
dotnet ef migrations add NomeMigration -p Infrastructure -s GUI.Windows

# Applicare migrations (SQL Server)
dotnet ef database update -p Infrastructure -s GUI.Windows

# Rollback (SQL Server)
dotnet ef database update PreviousMigration -p Infrastructure -s GUI.Windows
```

> **Nota:** `DesignTimeDbContextFactory` usa una connection string fittizia SQL Server.  
> Le migrations non vengono mai applicate a SQLite — usano `EnsureCreated` all'avvio.

---

## Issue Correlate

→ [Infrastructure/ISSUES.md](./ISSUES.md) — 2 issue aperte, 8 risolte

---

## Links

- [Core/README.md](../Core/README.md) - Modelli dominio ed enums
- [Docs/ER-schema.puml](../Docs/ER-schema.puml) - Schema ER database
- [.copilot/copilot-instructions.md](../.copilot/copilot-instructions.md) - Architettura e decisioni

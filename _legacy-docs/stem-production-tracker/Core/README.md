# Core

> **Modelli di dominio, enums e interfacce per il sistema di tracciamento produzione STEM.**  
> **Ultimo aggiornamento:** 2026-03-10

---

## Panoramica

Il progetto **Core** contiene le definizioni fondamentali del dominio applicativo:
- **Modelli** che rappresentano le entità di business (ODL, Device, Sessioni, etc.)
- **Enums** per stati, tipi e outcome
- **Interfacce** per i repository (pattern Repository)

È il layer più interno dell'architettura e non ha dipendenze esterne.

---

## Caratteristiche

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **Domain Models** | ✅ | 11 modelli completi con validazione |
| **Enums** | ✅ | 8 enumerazioni per stati, tipi e ruoli |
| **Repository Interfaces** | ✅ | 8 interfacce per persistenza |
| **Validation** | ✅ | Fail-fast nei costruttori |
| **Session Workflow** | ✅ | CanComplete(), Save(), Complete(), `Id` e `Restore()` per tracking |
| **Rework Support** | ✅ | ReturnToProduction(), CreateReworkSession() |
| **Device BLE Info** | ✅ | FirmwareVersion, BleMacAddress per tracciabilità collaudo |

---

## Requisiti

- **.NET 10.0** o superiore

### Dipendenze

Nessuna dipendenza esterna. Core è il layer più interno.

---

## Quick Start

```csharp
// Creare un Ordine di Lavoro
var workOrder = new WorkOrder("12345", ProductType.EdenBs8, 10);

// Creare una Fase (AssignedAssembler = username, non DisplayName)
var phase = new Phase(workOrder, 10, "mario");  // username

// Creare un Device
var device = new Device(workOrder, "001", phase);

// Transizione di stato
device.StartProduction();  // Ordered → InProduction
device.StartTesting();     // InProduction → InTesting
device.Complete("SN-FINAL-001");  // InTesting → Completed

// Rilavorazione (rework)
device.ReturnToProduction();  // InTesting → InProduction

// Informazioni BLE (impostate durante montaggio/collaudo)
device.SetFirmwareVersion("1.2.3");
device.SetBleMacAddress("AA:BB:CC:DD:EE:FF");

// Sessione di collaudo (legge FirmwareVersion dal device)
var session = new TestSession(device, sheet, DateTime.Now, device.FirmwareVersion!);
session.AddExecution(new CheckExecution(10, CheckOutcome.Ok, "luigi", DateTime.Now));  // username
if (session.CanComplete())
    session.Complete(DateTime.Now);
```

---

## Struttura

```
Core/
├── Enums/
│   ├── ProductType.cs        # Tipi prodotto (EdenBs8, OptimusXp, etc.)
│   ├── DeviceStatus.cs       # Stati device (Ordered → Completed, + rework)
│   ├── ProgressStatus.cs     # Stati avanzamento ODL/Phase (derivato)
│   ├── SessionStatus.cs      # Stati sessione (InProgress/Saved/Completed)
│   ├── CheckPhase.cs         # Fase controllo (Assembly/Testing)
│   ├── CheckType.cs          # Tipo controllo (Generic/Value/Boolean)
│   ├── CheckOutcome.cs       # Esito controllo + IsPositive() extension
│   └── UserRole.cs           # Ruolo utente (Assembler/Tester/Manager)
├── Models/
│   ├── WorkOrder.cs          # Ordine di Lavoro + GetStatus()
│   ├── Phase.cs              # Fase/Lotto di produzione + GetStatus()
│   ├── Device.cs             # Dispositivo + FirmwareVersion/BleMacAddress per collaudo
│   ├── FunctionalGroup.cs    # Componente interno tracciato (istanza con S/N)
│   ├── FunctionalGroupTemplate.cs # Template componente (senza S/N) + ToInstance()
│   ├── CheckDefinition.cs    # Definizione controllo + ReferenceValue/Tolerance/Unit
│   ├── CheckExecution.cs     # Esecuzione controllo + Operator (username)
│   ├── TestSheet.cs          # Scheda collaudo + FunctionalGroupTemplates
│   ├── AssemblySession.cs    # Sessione montaggio + Id/Restore() per tracking
│   ├── TestSession.cs        # Sessione collaudo + Id/Restore() per tracking
│   └── User.cs               # Utente del sistema (username, displayName, role)
└── Interfaces/
    ├── IRepository.cs        # Repository base generico
    ├── IWorkOrderRepository.cs
    ├── IPhaseRepository.cs   # + GetByAssemblerAsync(username)
    ├── IDeviceRepository.cs
    ├── IFunctionalGroupRepository.cs
    ├── ISessionRepository.cs
    ├── ICheckExecutionRepository.cs
    └── IUserRepository.cs    # GetByUsernameAsync, GetByRoleAsync
```

---

## API / Componenti

### Enums

| Enum | Valori | Uso |
|------|--------|-----|
| `ProductType` | EdenBs8, OptimusXp, EdenXp, R3lXp | Tipo dispositivo |
| `DeviceStatus` | Ordered, InProduction, InTesting, Completed | Stato device (bidirezionale InTesting↔InProduction) |
| `SessionStatus` | InProgress, Saved, Completed | Stato sessione montaggio/collaudo |
| `ProgressStatus` | New, InProcess, Completed | Stato ODL/Phase (derivato) |
| `CheckPhase` | Assembly (10), Testing (20), Undefined | Fase controllo |
| `CheckType` | Generic, Value, Boolean | Tipo controllo |
| `CheckOutcome` | Ok, No, Measured, Present, Absent | Esito controllo + `IsPositive()` |
| `UserRole` | Assembler, Tester, Manager | Ruolo utente nell'applicazione |

### Modelli Principali

| Modello | Identificatore | Note |
|---------|----------------|------|
| `WorkOrder` | `Number` | Generato da SAP |
| `Phase` | `{ODL}/{PhaseNumber}` | `AssignedAssembler` = **username** |
| `Device` | `{ODL}-{Suffix}` | + `FirmwareVersion`, `BleMacAddress` per collaudo |
| `FunctionalGroup` | `PartNumber` + `SerialNumber` | Componente installato |
| `CheckExecution` | - | `Operator` = **username** per tracciabilità |
| `AssemblySession` | DeviceId + StartedAt | `Id` e `Restore()` per tracking dopo persistenza |
| `TestSession` | DeviceId + StartedAt | `Id` e `Restore()`, legge `FirmwareVersion` dal device |
| `User` | `Username` | Username univoco (lowercase) |

### Tracciabilità con Username

Usiamo **username** (non DisplayName) per:
- `Phase.AssignedAssembler` - montatore assegnato
- `CheckExecution.Operator` - chi ha eseguito il controllo

Vantaggi: univocità, coerenza, ricerca efficiente.

### Interfacce Repository

| Interfaccia | Metodi Chiave |
|-------------|---------------|
| `IRepository<T>` | GetByIdAsync, GetAllAsync, AddAsync, UpdateAsync, SoftDeleteAsync |
| `IWorkOrderRepository<T>` | GetByNumberAsync |
| `IPhaseRepository<T>` | GetByWorkOrderIdAsync, GetByAssemblerAsync(**username**) |
| `IDeviceRepository<T>` | GetByFullIdAsync, GetByStatusAsync |
| `IFunctionalGroupRepository<T>` | GetByDeviceIdAsync, GetByDeviceAndPartNumberAsync |
| `ISessionRepository<T>` | GetByDeviceIdAsync, GetLatestByDeviceIdAsync |
| `IUserRepository<T>` | GetByUsernameAsync, GetByRoleAsync |

---

## Issue Correlate

→ [Core/ISSUES.md](./ISSUES.md) *(da creare)*

---

## Links

- [README Soluzione](../README.md)
- [Services](../Services/README.md)
- [Infrastructure.Persistence](../Infrastructure.Persistence/README.md)
- [Infrastructure.Protocol](../Infrastructure.Protocol/README.md)
- [Tests](../Tests/README.md)
# Services

> **Layer di logica di business per il sistema di tracciamento produzione STEM.**  
> **Ultimo aggiornamento:** 2026-03-10

---

## Panoramica

Il progetto **Services** implementa la logica di business dell'applicazione:
- **Orchestrazione** delle operazioni tra repository e domain model
- **Mapping** bidirezionale tra Entity (persistenza) e Domain Model (Core)
- **Validazioni di business** (es. unicità SerialSuffix per WorkOrder)
- **Transizioni di stato** dei device attraverso il ciclo produttivo

È il layer che coordina Core e Infrastructure.Persistence.

---

## Caratteristiche

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **WorkOrderService** | ✅ | CRUD per Ordini di Lavoro |
| **PhaseService** | ✅ | CRUD + GetByAssemblerAsync(**username**) |
| **DeviceService** | ✅ | CRUD + transizioni + SetFirmwareVersion/SetBleMacAddress |
| **AssemblySessionService** | ✅ | Sessioni montaggio + rework, ritorna Id per tracking |
| **TestSessionService** | ✅ | Sessioni collaudo, legge FirmwareVersion dal device |
| **UserService** | ✅ | CRUD utenti + validazione username univoco |
| **Mappers** | ✅ | Entity ↔ Domain con `Restore()` per sessioni |
| **DI Extension** | ✅ | AddServices() per registrazione |

---

## Requisiti

- **.NET 10.0** o superiore

### Dipendenze

| Package | Versione | Uso |
|---------|----------|-----|
| `Microsoft.Extensions.DependencyInjection.Abstractions` | 10.0.3 | DI extensions |
| `Core` | Project | Domain models, interfaces |
| `Infrastructure.Persistence` | Project | Repositories, entities |

---

## Quick Start

```csharp
// Registrare i servizi in DI
services.AddPersistence("Data Source=production.db");
services.AddServices();

// Usare un servizio
public class ProductionController
{
    private readonly IDeviceService _deviceService;
    
    public ProductionController(IDeviceService deviceService)
    {
        _deviceService = deviceService;
    }
    
    public async Task StartProduction(int deviceId)
    {
        // Transizione: Ordered → InProduction
        await _deviceService.StartProductionAsync(deviceId);
    }
    
    public async Task CompleteDevice(int deviceId, string finalSerial)
    {
        // Transizione: InTesting → Completed
        await _deviceService.CompleteAsync(deviceId, finalSerial);
    }
}
```

---

## Struttura

```
Services/
├── DependencyInjection.cs       # Extension method AddServices()
├── Interfaces/
│   ├── IWorkOrderService.cs     # Contratto per WorkOrder
│   ├── IPhaseService.cs         # Contratto per Phase
│   ├── IDeviceService.cs        # Contratto per Device
│   ├── IAssemblySessionService.cs # Contratto per sessioni montaggio
│   ├── ITestSessionService.cs   # Contratto per sessioni collaudo
│   └── IUserService.cs          # Contratto per utenti
├── Mapping/
│   ├── WorkOrderMapper.cs       # Entity ↔ Domain mapping
│   ├── PhaseMapper.cs           # Entity ↔ Domain mapping
│   ├── DeviceMapper.cs          # Entity ↔ Domain mapping
│   ├── FunctionalGroupMapper.cs # Entity ↔ Domain mapping (NEW)
│   ├── AssemblySessionMapper.cs # Entity ↔ Domain + reflection restore
│   ├── TestSessionMapper.cs     # Entity ↔ Domain + reflection restore
│   ├── CheckExecutionMapper.cs  # Entity ↔ Domain mapping
│   └── UserMapper.cs            # Entity ↔ Domain mapping
├── WorkOrderService.cs          # Implementazione WorkOrder
├── PhaseService.cs              # Implementazione Phase
├── DeviceService.cs             # Implementazione Device + FunctionalGroups
├── AssemblySessionService.cs    # Implementazione sessioni montaggio
├── TestSessionService.cs        # Implementazione sessioni collaudo
└── UserService.cs               # Implementazione utenti
```

---

## API / Componenti

### IWorkOrderService

| Metodo | Descrizione |
|--------|-------------|
| `GetByIdAsync(int id)` | Ottiene ODL per ID |
| `GetByNumberAsync(string number)` | Ottiene ODL per numero |
| `GetAllAsync()` | Lista tutti gli ODL |
| `CreateAsync(...)` | Crea nuovo ODL |
| `UpdateAsync(WorkOrder)` | Aggiorna ODL esistente |
| `DeleteAsync(int id)` | Soft delete |

### IPhaseService

| Metodo | Descrizione |
|--------|-------------|
| `GetByIdAsync(int id)` | Ottiene fase per ID |
| `GetByWorkOrderIdAsync(int workOrderId)` | Fasi di un ODL |
| `GetByAssemblerAsync(string username)` | Fasi assegnate a un montatore (cerca per **username**) |
| `CreateAsync(...)` | Crea nuova fase |
| `UpdateAsync(Phase)` | Aggiorna fase |
| `DeleteAsync(int id)` | Soft delete |

### IDeviceService

| Metodo | Descrizione |
|--------|-------------|
| `GetByIdAsync(int id)` | Ottiene device per ID |
| `GetByFullIdAsync(string fullId)` | Ottiene per "12345-001" |
| `GetByStatusAsync(DeviceStatus)` | Device per stato (es. InTesting per collaudatore) |
| `CreateAsync(...)` | Crea nuovo device |
| `StartProductionAsync(int id)` | Ordered → InProduction |
| `StartTestingAsync(int id)` | InProduction → InTesting |
| `ReturnToProductionAsync(int id)` | InTesting → InProduction (rilavorazione) |
| `CompleteAsync(int id, string finalSerial)` | InTesting → Completed |
| `SetFirmwareVersionAsync(int id, string version)` | Imposta firmware letto via BLE |
| `SetBleMacAddressAsync(int id, string mac)` | Imposta MAC address BLE |
| `SetFunctionalGroupAsync(...)` | Aggiunge/sostituisce componente (S/N) |

### IAssemblySessionService

| Metodo | Descrizione |
|--------|-------------|
| `GetByIdAsync(int id)` | Ottiene sessione per ID |
| `GetLatestByDeviceIdAsync(int deviceId)` | Ultima sessione (per ripresa) |
| `StartAsync(int deviceId, TestSheet)` | Avvia sessione, **ritorna con Id** |
| `StartReworkAsync(...)` | Rilavorazione con import check |
| `AddExecutionAsync(int sessionId, CheckExecution)` | Aggiunge controllo (operator = username) |
| `SaveAsync(int sessionId)` | InProgress → Saved |
| `CompleteAsync(int sessionId)` | Completa + Device → InTesting |

### ITestSessionService

| Metodo | Descrizione |
|--------|-------------|
| `GetByIdAsync(int id)` | Ottiene sessione per ID |
| `GetLatestByDeviceIdAsync(int deviceId)` | Ultima sessione (per ripresa) |
| `StartAsync(int deviceId, TestSheet)` | Avvia sessione, legge **FirmwareVersion dal device** |
| `AddExecutionAsync(int sessionId, CheckExecution)` | Aggiunge controllo (operator = username) |
| `SaveAsync(int sessionId)` | InProgress → Saved |
| `CompleteAsync(int sessionId, string finalSerial)` | Completa + Device → Completed |

### IUserService

| Metodo | Descrizione |
|--------|-------------|
| `GetByIdAsync(int id)` | Ottiene utente per ID |
| `GetByUsernameAsync(string username)` | Ottiene per username (case insensitive) |
| `GetAllAsync()` | Lista tutti gli utenti attivi |
| `GetByRoleAsync(UserRole role)` | Utenti per ruolo |
| `CreateAsync(username, displayName, role)` | Crea nuovo utente |
| `UpdateAsync(id, displayName, role)` | Aggiorna utente (username immutabile) |
| `DeleteAsync(int id)` | Soft delete |

### Mappers

Ogni mapper espone metodi statici:

```csharp
// Entity → Domain
WorkOrder domain = WorkOrderMapper.ToDomain(entity);

// Domain → Entity (per INSERT)
WorkOrderEntity entity = WorkOrderMapper.ToEntity(domain);

// Aggiorna Entity esistente (per UPDATE)
WorkOrderMapper.UpdateEntity(entity, domain);
```

---

## Validazioni di Business

| Validazione | Service | Eccezione |
|-------------|---------|-----------|
| SerialSuffix univoco per WorkOrder | DeviceService.CreateAsync | `InvalidOperationException` |
| Username univoco (case insensitive) | UserService.CreateAsync | `InvalidOperationException` |
| WorkOrder/Phase esistenti | Tutti i Create | `KeyNotFoundException` |
| Transizioni stato valide | Device state methods | `InvalidOperationException` |
| Device in stato corretto per sessione | Session Start methods | `InvalidOperationException` |
| Sessione non completata per modifiche | AddExecution, Save | `InvalidOperationException` |
| Tutti i check positivi per completamento | Session Complete methods | `InvalidOperationException` |

---

## Issue Correlate

→ [Services/ISSUES.md](./ISSUES.md) *(da creare)*

---

## Links

- [Core - Domain Models](../Core/README.md)
- [Infrastructure.Persistence - Data Access](../Infrastructure.Persistence/README.md)
- [Infrastructure.Protocol - Communication](../Infrastructure.Protocol/README.md)
- [Tests - Unit Tests](../Tests/README.md)
# Tests

> **Test unitari e di integrazione per il sistema di tracciamento produzione STEM.**  
> **Ultimo aggiornamento:** 2026-03-11

---

## Panoramica

Il progetto **Tests** contiene tutti i test automatizzati della soluzione:
- **Unit Tests** - Test isolati per modelli, enums, services, protocol, devices, GUI e componenti DI
- **Integration Tests** - Test con SQLite reale per repository, workflow E2E

Utilizza **xUnit** come framework di test e **NSubstitute** per mocking.

---

## Caratteristiche

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **Unit Tests - Core** | ✅ | Enums e models |
| **Unit Tests - Services** | ✅ | Mappers e services |
| **Unit Tests - GUI** | ✅ | Converters, ViewModels, FirmwareUpdateViewModel (Windows only) |
| **Unit Tests - Protocol** | ✅ | Connection e discovery |
| **Unit Tests - Devices** | ✅ | Plugin e builder |
| **Unit Tests - Firmware** | ✅ | StubFirmwareProvider, DI registration |
| **Integration Tests** | ✅ | SQLite reale + workflow E2E |
| **Tester Workflow E2E** | ✅ | Test completo workflow collaudo |
| **Totale** | ✅ | **643 CI / 951 Windows** |

---

## Requisiti

- **.NET 10.0** (CI - Linux/Windows)
- **.NET 10.0-windows** (per test GUI - Windows only)

### Dipendenze

| Package | Versione | Uso |
|---------|----------|-----|
| `xunit` | 2.9.3 | Framework di test |
| `xunit.runner.visualstudio` | 3.1.5 | Runner per VS |
| `Microsoft.NET.Test.Sdk` | 18.0.1 | SDK test |
| `Microsoft.EntityFrameworkCore.InMemory` | 10.0.3 | DB in-memory per test |
| `NSubstitute` | 5.3.0 | Mocking framework |
| `coverlet.collector` | 8.0.0 | Code coverage |
| `Core` | Project | Modelli e interfacce |
| `Infrastructure.Persistence` | Project | Repository e DeviceDefinitions |
| `Infrastructure.Protocol` | Project | Protocol da testare |
| `Services` | Project | Services da testare |
| `Devices` | Project | Plugin da testare |
| `GUI.Windows` | Project | Converters (Windows only) |

---

## Quick Start

```bash
# Eseguire tutti i test (CI - cross-platform)
dotnet test --framework net10.0

# Eseguire tutti i test inclusi GUI (Windows only)
dotnet test --framework net10.0-windows

# Eseguire solo unit test
dotnet test --filter "FullyQualifiedName~Unit"

# Eseguire solo integration test
dotnet test --filter "FullyQualifiedName~Integration"

# Con output dettagliato
dotnet test --verbosity normal

# Con coverage
dotnet test --collect:"XPlat Code Coverage"
```

---

## Struttura

```
Tests/
├── Unit/
│   ├── Enums/                        # Test enum (8 file)
│   │   ├── ProductTypeTests.cs
│   │   ├── DeviceStatusTests.cs
│   │   ├── SessionStatusTests.cs
│   │   ├── ProgressStatusTests.cs
│   │   ├── CheckPhaseTests.cs
│   │   ├── CheckTypeTests.cs
│   │   ├── CheckOutcomeTests.cs
│   │   └── UserRoleTests.cs
│   ├── Models/                       # Test modelli (11 file)
│   │   ├── WorkOrderTests.cs
│   │   ├── PhaseTests.cs
│   │   ├── DeviceTests.cs
│   │   ├── FunctionalGroupTests.cs
│   │   ├── FunctionalGroupTemplateTests.cs  # NEW
│   │   ├── CheckDefinitionTests.cs
│   │   ├── CheckExecutionTests.cs
│   │   ├── TestSheetTests.cs
│   │   ├── AssemblySessionTests.cs
│   │   ├── TestSessionTests.cs
│   │   └── UserTests.cs
│   ├── Services/                     # Test services (15 file)
│   │   ├── WorkOrderMapperTests.cs
│   │   ├── PhaseMapperTests.cs
│   │   ├── DeviceMapperTests.cs
│   │   ├── FunctionalGroupMapperTests.cs
│   │   ├── CheckExecutionMapperTests.cs
│   │   ├── AssemblySessionMapperTests.cs
│   │   ├── TestSessionMapperTests.cs
│   │   ├── UserMapperTests.cs
│   │   ├── WorkOrderServiceTests.cs
│   │   ├── PhaseServiceTests.cs
│   │   ├── DeviceServiceTests.cs
│   │   ├── AssemblySessionServiceTests.cs
│   │   ├── TestSessionServiceTests.cs
│   │   ├── UserServiceTests.cs
│   │   └── ServicesDependencyInjectionTests.cs
│   ├── Protocol/                     # Test protocol
│   │   └── ...
│   ├── Infrastructure/               # Test DI
│   │   └── DependencyInjectionTests.cs
│   ├── DeviceDefinitions/            # Test definizioni device
│   │   └── ...
│   ├── TestSheets/                   # Test schede collaudo
│   │   └── ...
│   ├── Devices/                      # Test plugin device
│   │   └── ...
│   └── GUI/                          # Test WPF (Windows only)
│       ├── ConvertersTests.cs
│       ├── LoginViewModelTests.cs
│       ├── MainViewModelTests.cs
│       ├── AssemblerDashboardViewModelTests.cs
│       ├── AssemblySessionPanelViewModelTests.cs
│       ├── TesterDashboardViewModelTests.cs
│       ├── TestSessionPanelViewModelTests.cs  # NEW
│       ├── CheckItemViewModelTests.cs
│       ├── FunctionalGroupItemViewModelTests.cs
│       ├── ManagerDashboardViewModelTests.cs
│       └── ViewModelHelpersTests.cs
└── Integration/
    ├── SqliteIntegrationTestBase.cs  # Fixture base SQLite
    ├── ProductionWorkflowIntegrationTests.cs # Test workflow E2E
    └── Persistence/                  # Test repository (8 file)
        ├── AppDbContextTests.cs
        ├── WorkOrderRepositoryTests.cs
        ├── PhaseRepositoryTests.cs
        ├── DeviceRepositoryTests.cs
        ├── FunctionalGroupRepositoryTests.cs
        ├── AssemblySessionRepositoryTests.cs
        ├── TestSessionRepositoryTests.cs
        └── CheckExecutionRepositoryTests.cs
```

---

## Test Summary

### Per framework

| Framework | Test | Note |
|-----------|:----:|------|
| `net10.0` | **611** | CI (Linux/Windows) |
| `net10.0-windows10.0.19041.0` | **896** | Locale (Windows only, include GUI) |

### Nuovi test branch `feature/workflow-collaudo`

| Test | Descrizione |
|------|-------------|
| `TestSessionPanelViewModelTests` | ~40 test per pannello collaudo |
| `TesterWorkflow_*` | 5 test E2E workflow collaudatore |

---

## Mocking con NSubstitute

Per i test che richiedono dipendenze esterne utilizziamo **NSubstitute**.

### Esempio di utilizzo

```csharp
using NSubstitute;

[Fact]
public async Task LoadUsersAsync_PopulatesAvailableUsers()
{
    // Arrange - crea mock
    var service = Substitute.For<IUserService>();

    // Configura comportamento
    service.GetAllAsync(Arg.Any<CancellationToken>())
        .Returns(Task.FromResult<IReadOnlyList<User>>(users));

    var vm = new LoginViewModel(service);

    // Act
    await vm.LoadUsersAsync();

    // Assert
    Assert.Equal(2, vm.AvailableUsers.Count);
}

// Simulare eccezioni
service.GetAllAsync(Arg.Any<CancellationToken>())
    .Returns<IReadOnlyList<User>>(x => throw new Exception("DB Error"));
```

### Pattern comuni

```csharp
// Mock semplice
var service = Substitute.For<IMyService>();
service.GetById(42).Returns(expectedObject);

// Con CancellationToken (ignora il valore)
service.GetAllAsync(Arg.Any<CancellationToken>()).Returns(list);

// Verifica chiamata
service.Received().DoSomething();
service.DidNotReceive().DoSomethingElse();
```

---

## Convenzioni

### Naming

```csharp
// Pattern: Method_Scenario_ExpectedResult
[Fact]
public void Constructor_WithValidParameters_CreatesInstance()

// Pattern: When_Condition_Then_Behavior
[Fact]
public void WhenDeviceCompleted_ThenFinalSerialRequired()
```

### Struttura Test (AAA)

```csharp
[Fact]
public void Method_Scenario_ExpectedResult()
{
    // Arrange
    var input = "test";

    // Act
    var result = _sut.DoSomething(input);

    // Assert
    Assert.Equal(expected, result);
}
```

### Integration Test Base

```csharp
// Eredita da SqliteIntegrationTestBase per test con SQLite reale
public class MyRepositoryTests : SqliteIntegrationTestBase
{
    [Fact]
    public async Task Test()
    {
        // Context è già inizializzato con SQLite in-memory
        var repo = new MyRepository(Context);
        // ...
    }
}
```

---

## Esecuzione / Testing

```bash
# Run tutti i test (CI)
dotnet test Tests/Tests.csproj --framework net10.0

# Run tutti i test (locale Windows)
dotnet test Tests/Tests.csproj --framework net10.0-windows

# Run con filtro
dotnet test --filter "ClassName=WorkOrderTests"

# Run singolo test
dotnet test --filter "FullyQualifiedName~Constructor_WithValidParameters"

# Output verboso
dotnet test --logger "console;verbosity=detailed"
```

---

## Links

- [README Soluzione](../README.md)
- [Core](../Core/README.md)
- [Services](../Services/README.md)
- [Infrastructure.Persistence](../Infrastructure.Persistence/README.md)
- [Infrastructure.Protocol](../Infrastructure.Protocol/README.md)
- [Devices](../Devices/README.md)


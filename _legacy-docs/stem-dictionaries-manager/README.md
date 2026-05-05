# STEM Dictionaries Manager

[![Version](https://img.shields.io/badge/version-0.6.0-blue)](./CHANGELOG.md)
[![.NET](https://img.shields.io/badge/.NET-10.0-512BD4)](https://dotnet.microsoft.com/)
[![Tests](https://img.shields.io/badge/tests-~2375%20passing-brightgreen)](./Tests/)
[![License](https://img.shields.io/badge/license-Proprietary-red)](#licenza)

> **Applicazione per la gestione centralizzata dei dizionari dispositivi STEM (comandi + variabili), con API REST per consumer esterni.**

> **Ultimo aggiornamento:** 2026-04-13

---

## Panoramica

**Stem.Dictionaries.Manager** è un'applicazione desktop WPF per centralizzare la gestione dei dizionari dei dispositivi STEM (medical equipment). 

### Problema

- Dizionari attualmente in file Excel (`Dizionari.xlsx`)
- Excel copiato/incollato tra progetti → rischio inconsistenze
- Modifiche da più punti → propagazione errori
- Consumer devono fare import manuale → perdita tempo
- Firmware in continua evoluzione → dizionari cambiano spesso

### Soluzione

- **Database centralizzato** su Azure SQL (single source of truth)
- **Applicativo desktop** per gestione CRUD
- **Versionamento modifiche** con audit trail completo
- **API REST** per consumer (Production.Tracker, Collaudo Pulsantiere, SW Comunicazione)

---

## Caratteristiche

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **Modelli dominio** | ✅ | 10 models + 5 enums (Variable, Dictionary, Board, Device, StandardVariableOverride, etc.) |
| **Domain v2** | ✅ | IsStandard flag, Board→Dictionary diretto, semantica derivata |
| **Domain v7** | ✅ | StandardVariableOverride per-dizionario, BitInterpretation.DictionaryId |
| **Persistenza** | ✅ | EF Core + SQLite (dev) / Azure SQL (prod), dual provider, User Secrets |
| **Audit Trail** | ✅ | Traccia ogni modifica con JSON completo, integrato in 5 service (16 punti) |
| **Repository Pattern** | ✅ | 10 repository con interfacce |
| **Services Layer** | ✅ | 7 services + 10 mappers + business rules (BR-009/010/011/018/020) |
| **GUI Desktop** | ✅ | WPF + MVVM con 14 ViewModels, 14 Views, dark theme STEM, custom dialogs, status bar |
| **Comandi per device** | ✅ | Stato attivo/disattivo comandi per Device con override persistente |
| **Override variabili standard** | ✅ | Override IsEnabled/Description/BitInterp per-dizionario via VariableEdit |
| **Variabili standard ereditate** | ✅ | DictionaryEdit con sezione variabili standard read-only + doppio-click per override |
| **Filtro abilitate** | ✅ | Checkbox "Mostra solo abilitate" filtra variabili specifiche e standard in DictionaryEdit |
| **API REST** | ✅ | 12 endpoint (10 business + health + version), API Key auth, Swagger UI, deploy Azure App Service |
| **Auto-fill parametri** | ✅ | MachineCode (Device) e FirmwareType (Board) pre-compilati con primo valore disponibile in creazione |
| **Test Suite** | ✅ | ~1455 metodi test / ~2375 test cases (unit + integration + E2E + API, 2 target framework) |

---

## Requisiti

- **.NET 10.0** o superiore
- **Visual Studio 2022/2026** (per sviluppo WPF)
- **SQLite** (sviluppo) / **Azure SQL** (produzione) — selezionabile via `appsettings.json`

---

## Quick Start

```bash
# Clone repository
git clone https://bitbucket.org/stem-fw/stem-dictionaries-manager.git
cd stem-dictionaries-manager

# Restore e build
dotnet restore
dotnet build

# Eseguire i test
dotnet test Tests/Tests.csproj --framework net10.0

# Applicare migrations SQL Server (produzione Azure SQL)
dotnet ef database update -p Infrastructure -s GUI.Windows

# SQLite (sviluppo): il DB viene creato automaticamente all'avvio (EnsureCreated)
```

---

## Struttura Soluzione

```
Stem.Dictionaries.Manager/
├── Core/                  # Modelli dominio, enums (10 models, 5 enum)
│   ├── Enums/             # AccessMode, DataTypeKind, AuditEntityType, etc.
│   └── Models/            # Variable, Dictionary, Board, Device, StandardVariableOverride, etc.
├── Services/              # Business logic, mapping Entity ↔ Domain
│   ├── Interfaces/        # Service interfaces (8)
│   └── Mapping/           # Mapper bidirezionali (10)
├── Infrastructure/        # EF Core, SQLite, Repositories
│   ├── Entities/          # Entity classes (10)
│   ├── Repositories/      # Repository implementations (10)
│   └── Migrations/        # Migration Domain v7
├── API/                   # ASP.NET Core Minimal API (12 endpoint REST, deploy Azure)
│   ├── Dtos/              # DTO record per risposte JSON (7)
│   ├── Endpoints/         # Endpoint groups (4 classi)
│   ├── Mapping/           # ApiMapper (domain → DTO)
│   └── Middleware/        # ApiKeyMiddleware
├── GUI.Windows/           # Applicazione WPF (MVVM, 14 ViewModels, 14 Views)
│   ├── Abstractions/      # Interfaces navigazione, dialoghi, messaggi, IEditableViewModel
│   ├── ViewModels/        # 14 ViewModels + helper classes
│   ├── Views/             # 14 Views XAML (incl. LoginView, DarkDialog, DeviceEditView, DeviceCommandsView)
│   ├── Converters/        # 7 converter (Bool, Inverse, Null, NullableInt/Double, SeverityToColor, BoolToErrorBrush)
│   └── Services/          # NavigationService, DialogService, MessageService
├── Tests/                 # Unit & integration tests (~1420 metodi / ~2330 cases)
│   ├── Unit/              # Core, Services/Mapping, Infrastructure/DI, GUI, API
│   ├── Integration/       # Infrastructure, Services, GUI, API, E2E (SQLite in-memory)
├── Docs/                  # Documentazione
│   ├── Dictionaries/      # CSV originali per riferimento
│   ├── Standards/         # Template documentazione
│   └── ER-schema.puml     # Schema database
├── .copilot/              # Copilot instructions e agents
├── README.md              # Questa documentazione
├── CHANGELOG.md           # Storico release (Keep a Changelog)
└── ISSUES_TRACKER.md      # Riepilogo globale issue
```

---

## Documentazione

| Documento | Descrizione |
|-----------|-------------|
| [Core/README.md](./Core/README.md) | Modelli dominio ed enumerazioni |
| [Services/README.md](./Services/README.md) | Business logic, mapping, services |
| [Infrastructure/README.md](./Infrastructure/README.md) | Persistenza, EF Core, Repositories |
| [API/README.md](./API/README.md) | API REST, endpoint, autenticazione |
| [GUI.Windows/README.md](./GUI.Windows/README.md) | Applicazione WPF, ViewModels, Navigation |
| [Tests/README.md](./Tests/README.md) | Suite di test, convenzioni |
| [ISSUES_TRACKER.md](./ISSUES_TRACKER.md) | Riepilogo globale issue e metriche qualità |
| [CHANGELOG.md](./CHANGELOG.md) | Storico delle release e modifiche |
| [Docs/ER-schema.puml](./Docs/ER-schema.puml) | Schema ER database |
| [.copilot/copilot-instructions.md](./.copilot/copilot-instructions.md) | Formalizzazione Lean 4, workflow |

---

## Issue Tracking

→ **[ISSUES_TRACKER.md](./ISSUES_TRACKER.md)** — Riepilogo globale issue

| Componente | Issue File | Aperte | Risolte | Priorità Max |
|------------|------------|:------:|:-------:|:------------:|
| Core | [Core/ISSUES.md](./Core/ISSUES.md) | 3 | 5 | Bassa |
| Infrastructure | [Infrastructure/ISSUES.md](./Infrastructure/ISSUES.md) | 2 | 7 | Bassa |
| Services | [Services/ISSUES.md](./Services/ISSUES.md) | 3 | 9 | Bassa |
| API | [API/ISSUES.md](./API/ISSUES.md) | 3 | 1 | Bassa |
| GUI.Windows | [GUI.Windows/ISSUES.md](./GUI.Windows/ISSUES.md) | 2 | 8 | Bassa |
| Tests | [Tests/ISSUES.md](./Tests/ISSUES.md) | 2 | 9 | Media |
| Trasversali | [ISSUES_TRACKER.md](./ISSUES_TRACKER.md#issue-trasversali-t-xxx) | 2 | 5 | Bassa |

⚠️ **0 alta priorità aperte, 1 media (TEST-011: riorganizzazione test suite)** — 17 aperte totali, tutte bassa tranne 1

---

## Palette Colori STEM

| Ruolo | Colore | Hex |
|-------|--------|-----|
| 🔵 Accent (base) | ![#004682](https://via.placeholder.com/12/004682/004682.png) | `#004682` |
| 🔵 Hover (scuro) | ![#003461](https://via.placeholder.com/12/003461/003461.png) | `#003461` |
| 🔵 Pressed (chiaro) | ![#2668A0](https://via.placeholder.com/12/2668A0/2668A0.png) | `#2668A0` |
| 🔵 Selezione inattiva | ![#1E3A54](https://via.placeholder.com/12/1E3A54/1E3A54.png) | `#1E3A54` |
| 🟢 Successo | ![#98D801](https://via.placeholder.com/12/98D801/98D801.png) | `#98D801` |
| 🔴 Errore | ![#E40032](https://via.placeholder.com/12/E40032/E40032.png) | `#E40032` |
| 🟡 Warning | ![#FFC04A](https://via.placeholder.com/12/FFC04A/FFC04A.png) | `#FFC04A` |

---

## CI/CD

Pipeline Bitbucket configurata:

```yaml
# Build & Test su ogni push
- dotnet build --configuration Release
- dotnet test --framework net10.0
```

Badge: [![Build](https://img.shields.io/badge/CI-Bitbucket%20Pipelines-blue)](./bitbucket-pipelines.yml)

---

## Relazione con Production.Tracker

**Stem.Production.Tracker** è un **consumer** di questo progetto:

| Attualmente | Con API (✅ live) |
|-------------|--------|
| Usa JSON files (`DeviceDefinitions/`) | `GET /api/boards/{id}/definition` |
| Import manuale | Chiamata API con API Key |
| Nessuna autenticazione | Header `X-Api-Key` |
| — | URL: `https://app-dictionaries-manager-prod.azurewebsites.net` |

---

## Architettura

```
┌─────────────────────────────────────────────────────────────┐
│                      GUI.Windows (WPF)                      │
│  MVVM, 14 ViewModels, 14 Views, Dark Theme STEM, Status Bar │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────┼────────────────────────────────┐
│                        API (REST)                           │
│  12 Endpoints, API Key Auth, Health Check, Deploy Azure F1  │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                         Services                            │
│        Business Logic, 10 Mappers, Audit Integration          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Infrastructure                         │
│    EF Core, SQLite/SQL Server, 10 Repositories, Migrations   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                           Core                              │
│            Domain Models (10), Enums (5)                    │
└─────────────────────────────────────────────────────────────┘
```

---

## Contribuire

1. Leggere la documentazione e seguire le convenzioni di codifica
2. Seguire il pattern **TDD**: Test → Implement → Refactor
3. Nomenclatura **inglese** per codice, **italiana** per documentazione
4. Ogni PR deve passare i test CI

---

## Licenza

- **Proprietario:** STEM E.m.s.
- **Autore:** Luca Veronelli (l.veronelli@stem.it)
- **Data di Creazione:** 2026-03-18
- **Licenza:** Proprietaria - Tutti i diritti riservati
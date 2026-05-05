# STEM Production Tracker

> **Applicazione WPF per il tracciamento della produzione e collaudo dei dispositivi STEM.**

[![.NET](https://img.shields.io/badge/.NET-10.0-512BD4)](https://dotnet.microsoft.com/)
[![Tests](https://img.shields.io/badge/tests-643%20CI%20%7C%20951%20Windows-brightgreen)](./Tests/)
[![License](https://img.shields.io/badge/license-Proprietary-red)](#licenza)

> **Ultimo aggiornamento:** 2026-03-11

---

## Panoramica

L'applicazione permette al reparto produzione di:
- **Tracciare gli Ordini di Lavoro (ODL)** e i dispositivi associati
- **Eseguire il montaggio** con registrazione dei controlli e gruppi funzionali
- **Eseguire il collaudo** con comunicazione diretta ai dispositivi via BLE
- **Sincronizzare lo stato** tra più postazioni di lavoro

---

## Caratteristiche

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **Domain Models** | ✅ | WorkOrder, Phase, Device, Sessions + FirmwareVersion/BleMacAddress |
| **Persistence Layer** | ✅ | EF Core + SQLite, Soft Delete, tracciabilità con username |
| **Services Layer** | ✅ | Logica di business, mapping con `Id` e `Restore()` |
| **Session Workflow** | ✅ | CanComplete, Save, Complete, Rilavorazione |
| **Device Definitions** | ✅ | Variabili JSON per device (runtime) |
| **Test Sheets** | ✅ | Schede collaudo JSON |
| **Firmware Provider** | ✅ | Download firmware da Azure (Stub per dev) |
| **Device Plugins** | ✅ | Plugin OPTIMUS XP |
| **BLE Protocol** | ✅ | Comunicazione con dispositivi STEM (v0.6.0) |
| **WPF GUI** | ✅ | Dashboard montatore e collaudatore con pannelli sessione |
| **Firmware Update UI** | ✅ | Dialog aggiornamento firmware (upload BLE: TODO) |

---

## Requisiti

- **.NET 10.0** o superiore
- **Visual Studio 2022+** con workload .NET Desktop
- **Azure Artifacts** per pacchetti NuGet privati

### Dipendenze Esterne

| Package | Versione | Uso |
|---------|----------|-----|
| `Stem.Communication.Protocol` | 0.6.0 | Comunicazione con dispositivi STEM |
| `Stem.Communication.Drivers.Ble` | 0.6.0 | Driver BLE per Windows |
| `Microsoft.EntityFrameworkCore.Sqlite` | 10.0.x | Database locale |

---

## Quick Start

```bash
# Build
dotnet build

# Test
dotnet test

# Creare migration (se necessario)
dotnet ef migrations add <NomeMigration> -p Infrastructure.Persistence -s GUI.Windows

# Applicare migration
dotnet ef database update -p Infrastructure.Persistence -s GUI.Windows
```

---

## Struttura Soluzione

```
Stem.Production.Tracker/
├── Core/                        # Modelli, interfacce, enums
├── Services/                    # Logica di business, mapping, validazioni
├── Infrastructure.Persistence/  # EF Core, SQLite, Repositories, Definitions
│   ├── DeviceDefinitions/       # Provider e JSON per variabili device
│   ├── TestSheets/              # Provider e JSON per schede collaudo
│   └── Firmware/                # Provider firmware (Stub/Azure)
├── Infrastructure.Protocol/     # Comunicazione BLE (v0.6.0)
├── Devices/                     # Plugin per dispositivi STEM
│   ├── Common/                  # Logica condivisa tra plugin
│   └── OptimusXp/               # Plugin OPTIMUS XP
├── GUI.Windows/                 # Applicazione WPF
│   ├── ViewModels/              # MVVM ViewModels
│   └── Views/                   # Pagine, pannelli e dialog
├── Tests/                       # Unit & integration tests (643 CI, 951 Windows)
│   ├── Unit/                    # Test unitari
│   └── Integration/             # Test con SQLite reale + workflow E2E
└── Docs/                        # Documentazione
```

---

## Concetti Chiave del Dominio

### Ordine di Lavoro (ODL)
Ogni ODL ha un numero identificativo, un tipo prodotto e un totale dispositivi. Generato da SAP.

### Fase
Lotto di produzione assegnato a un montatore (**username**, non DisplayName). Numerata a decine (/10, /20, /30...).

### Device
Un dispositivo è identificato da `{numero_ODL}-{suffisso_seriale}` (es. "12345-001").
- **FirmwareVersion**: versione firmware letta via BLE (obbligatoria per collaudo)
- **BleMacAddress**: MAC address BLE per identificazione dispositivo
- **Seriale finale**: assegnato al completamento del collaudo

**Stati del device:** `Ordered → InProduction → InTesting → Completed`

**Rilavorazione:** Un device può tornare da `InTesting` a `InProduction` per rilavorazione. In questo caso viene creata una nuova AssemblySession che importa i check OK dalla precedente.

### Gruppi Funzionali
Ogni device traccia i componenti interni (scheda elettronica, martinetti, potenziometri, etc.) con i relativi numeri seriali.

### Tipi Prodotto Supportati
- **OPTIMUS XP** ✅ (plugin implementato)
- EDEN BS8 (prossimo)
- EDEN XP
- R3L XP

### Sistema di Collaudo

Ogni tipo prodotto ha una **Scheda Collaudo** con controlli specifici.

| Tipo | Descrizione | Esito |
|------|-------------|-------|
| Generico | Controllo visivo/funzionale | OK / NO |
| Valore | Misurazione con riferimento ± tolleranza | Numero |
| Booleano | Presenza/assenza feature | Sì / No |

**Fasi:** Montaggio (Assembly = 10) | Collaudo (Testing = 20)

> **Nota:** Da ottobre 2025, tutti i device devono registrare la **versione firmware** al completamento del collaudo.

---

## Device Definitions

Le definizioni delle variabili dei dispositivi sono caricate da file JSON a runtime:

```
Infrastructure.Persistence/DeviceDefinitions/Data/
├── common/
│   └── standard-variables.json    # Variabili comuni (24)
└── devices/
    └── optimus-xp.json            # Variabili OPTIMUS XP (48)
```

Questo permette di **modificare le variabili senza ricompilare** l'applicazione.

→ Vedi [DeviceDefinitions/README.md](./Infrastructure.Persistence/DeviceDefinitions/README.md) per dettagli.

---

## Test Sheets

Le schede collaudo dei prodotti sono caricate da file JSON a runtime:

```
Infrastructure.Persistence/TestSheets/Data/
└── optimus-xp.json    # Scheda OPTIMUS XP (27 controlli: 13 Assembly + 14 Testing)
```

I controlli di tipo **Value** supportano:
- `referenceValue`: Valore di riferimento (es. 220mm)
- `tolerance`: Tolleranza ammessa (±5mm)
- `unit`: Unità di misura per display

Questo permette di **modificare i controlli senza ricompilare** l'applicazione.

→ Vedi [TestSheets/README.md](./Infrastructure.Persistence/TestSheets/README.md) per dettagli.

---

## Database

### Schema ER

→ [docs/ER_Schema.puml](./docs/ER_Schema.puml)

### Entità

| Entità | Descrizione |
|--------|-------------|
| `WorkOrders` | Ordini di lavoro |
| `Phases` | Fasi/lotti, `AssignedAssembler` = username |
| `Devices` | + `FirmwareVersion`, `BleMacAddress` |
| `FunctionalGroups` | Componenti interni tracciati |
| `AssemblySessions` | Sessioni di montaggio (storico) |
| `TestSessions` | Sessioni di collaudo (storico) |
| `CheckExecutions` | `Operator` = username |
| `Users` | Utenti del sistema |

### Soft Delete

Tutti i record usano **soft delete** (`IsDeleted` + `DeletedAt`). Nessuna cancellazione fisica.

---

## Test

| Framework | Test |
|-----------|:----:|
| **CI (net10.0)** | **643** |
| **Windows (net10.0-windows)** | **951** |

```bash
# Esegui tutti i test (CI - Linux)
dotnet test --framework net10.0

# Esegui tutti i test inclusi GUI (Windows)
dotnet test --framework net10.0-windows10.0.19041.0
```

---

## Metodologia di Sviluppo

Il progetto utilizza **TDD** con formalizzazione Lean 4:

```
Formalizzare (Lean 4) → Test (xUnit) → Implementare (C#) → Refactor
```

---

## Documentazione

- [DeviceDefinitions README](./Infrastructure.Persistence/DeviceDefinitions/README.md) - Variabili device
- [TestSheets README](./Infrastructure.Persistence/TestSheets/README.md) - Schede collaudo
- [Firmware README](./Infrastructure.Persistence/Firmware/README.md) - Provider firmware
- [Devices README](./Devices/README.md) - Plugin device
- [ER Schema](./docs/ER_Schema.puml) - Diagramma entità-relazioni
- [Standards](./Docs/Standards/) - Template e standard documentazione

---

## Issue Correlate

→ [ISSUES_TRACKER.md](./ISSUES_TRACKER.md) - Riepilogo di **53 issue** aperte + 9 issue trasversali

---

## Licenza

- **Proprietario:** STEM E.m.s.
- **Autore:** Luca Veronelli (l.veronelli@stem.it)
- **Data di Creazione:** 2026-02-23
- **Licenza:** Proprietaria - Tutti i diritti riservati

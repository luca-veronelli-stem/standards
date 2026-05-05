# STEM Communication Protocol

> **Implementazione .NET 10 dello stack protocollare STEM per la comunicazione tra dispositivi dell'ecosistema STEM.**  

> **Ultimo aggiornamento:** 2026-02-26

[![.NET](https://img.shields.io/badge/.NET-10.0-512BD4)](https://dotnet.microsoft.com/)
[![Tests](https://img.shields.io/badge/tests-~2602%20passing-brightgreen)](./Tests/)
[![Coverage](https://img.shields.io/badge/coverage-96%25-brightgreen)](./Tests/)
[![License](https://img.shields.io/badge/license-Proprietary-red)](./LICENSE)

---

## Panoramica

**STEM Communication Protocol** e una riscrittura moderna in C#/.NET 10 del protocollo di comunicazione STEM originariamente sviluppato in C. Il progetto fornisce uno stack protocollare completo a 7 layer (modello OSI) per la comunicazione affidabile tra dispositivi embedded STEM e applicazioni .NET.

---

## Caratteristiche

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **Compatibilita C** | ✅ | Binario compatibile con firmware STEM |
| **Architettura OSI** | ✅ | 7 layer indipendenti + Stack container |
| **Async-First** | ✅ | Tutte le operazioni I/O asincrone |
| **Thread-Safe** | ✅ | Pattern T-005 standardizzato |
| **Multi-Canale** | ✅ | UART, CAN, BLE, Cloud |
| **Connection Events** | ✅ | Eventi cambio stato connessione (STK-012) |
| **CancellationToken** | ✅ NEW | Cancellation su tutti i layer (T-024) |
| **BLE Device Discovery** | ✅ | Scansione dispositivi BLE (F-001) |
| **Crittografia** | ✅ | AES-128 ECB |
| **Osservabilita** | ✅ | Logging strutturato + statistiche |
| **Testabilita** | ✅ | ~2602 test, 96% coverage |

---

## Requisiti

- **.NET 10.0** o superiore
- Visual Studio 2022 17.12+ oppure VS Code con C# Dev Kit
- Windows 10/11 (per driver PCAN)

### Dipendenze

| Package | Versione | Uso |
|---------|----------|-----|
| Microsoft.Extensions.Logging | 10.0.2 | Logging strutturato |
| Peak.PCANBasic.NET | 4.10.1 | Driver CAN (Drivers.Can) |
| Plugin.BLE | 3.2.0 | Driver BLE (Drivers.Ble) |
| xUnit | 2.9.3 | Framework test |
| Moq | 4.20.72 | Mocking |

---

## Quick Start

```bash
# Clona il repository
git clone https://bitbucket.org/stem-fw/stem-communication-protocol.git
cd stem-communication-protocol

# Compila
dotnet build

# Test
dotnet test
```

### Esempio con ProtocolStackBuilder

```csharp
using Protocol.Layers.Stack;
using Protocol.Layers.Base.Enums;

// 1. Crea il driver del canale
var canDriver = new CanChannelDriver(hardware);

// 2. Costruisci lo stack con il builder fluent
var stack = new ProtocolStackBuilder()
    .WithLocalDeviceId(0x00030141)
    .WithChannelDriver(canDriver)
    .WithEncryption(CryptType.AES128, aesKey)
    .Build();

// 3. Inizializza
await stack.InitializeAsync();

// 4. Gestisci eventi connessione (STK-012)
stack.ConnectionStateChanged += (s, e) =>
{
    Console.WriteLine($"Connection: {e.PreviousState} -> {e.CurrentState}");
    if (!e.IsConnected && !e.WasExpected)
        Console.WriteLine($"Connection lost: {e.Reason}");
};

// 5. Invia/Ricevi (con CancellationToken - T-024)
using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
await stack.SendAsync(data, destinationId, cts.Token);
var received = await stack.ReceiveAsync(cts.Token);

// 6. Cleanup
await stack.DisposeAsync();
```

---

## Struttura

```
StemCommunicationProtocol/
+-- Protocol/                    # Libreria principale stack protocollare
|   +-- Infrastructure/          # Contratti driver (IChannelDriver, ChannelType)
|   +-- Layers/                  # Implementazione 7 layer OSI
|   |   +-- Base/                # Interfacce base (IProtocolLayer)
|   |   +-- PhysicalLayer/       # L1 - Buffer, I/O canale
|   |   +-- DataLinkLayer/       # L2 - Framing, CRC16
|   |   +-- NetworkLayer/        # L3 - Routing, discovery
|   |   +-- TransportLayer/      # L4 - Chunking, riassemblaggio
|   |   +-- SessionLayer/        # L5 - Gestione sessioni, SRID
|   |   +-- PresentationLayer/   # L6 - Crittografia AES-128
|   |   +-- ApplicationLayer/    # L7 - Comandi, variabili
|   |   +-- Stack/               # Orchestratore e builder
|   +-- Docs/                    # Documentazione tecnica
+-- Drivers.Can/                 # Driver CAN (Peak PCAN)
+-- Drivers.Ble/                 # Driver BLE (Plugin.BLE)
+-- Client/                      # Applicazione console esempio
+-- Tests/                       # Test xUnit (2473 test)
```

### Progetti

| Progetto | Tipo | Descrizione |
|----------|------|-------------|
| **Protocol** | Class Library | Stack protocollare STEM, 7 layer OSI |
| **Drivers.Can** | Class Library | Driver CAN per Peak PCAN-USB/PCI |
| **Drivers.Ble** | Class Library | Driver BLE multi-platform + Device Discovery (F-001) |
| **Client** | Console App | Applicazione esempio |
| **Tests** | xUnit | ~2602 test (96% unit, 4% integration) |

---

## Pacchetti NuGet

I seguenti pacchetti NuGet sono disponibili per l'integrazione nei progetti .NET:

| Pacchetto | Descrizione | Versione |
|-----------|-------------|---------|
| `Stem.Protocol` | Stack protocollare 7 layer OSI | 0.5.0 |
| `Stem.Drivers.Can` | Driver CAN (PEAK PCAN) | 0.5.0 |
| `Stem.Drivers.Ble` | Driver BLE (Plugin.BLE) | 0.5.0 |

Per detagli sulla pubblicazione e utilizzo dei pacchetti, consultare il file [CONTRIBUTING.md](./Docs/CONTRIBUTING.md).

---

## Issue Correlate

| Componente | Aperte | Risolte | Totale |
|------------|--------|---------|--------|
| Protocol (tutti i layer) | 74 | 58 | 132 |
| Drivers.Can | 10 | 7 | 17 |
| Drivers.Ble | 3 | 17 | 20 |
| Client | 13 | 0 | 13 |
| **Totale** | **99** | **83** | **182** |

Dettaglio: [Protocol/ISSUES.md](./Protocol/ISSUES.md)

> **Feature completate:** [FEATURES.md](./Protocol/FEATURES.md) - F-001 BLE Device Discovery ✅  
> **Issue risolte di recente:** T-024 (CancellationToken), T-019 (ConfigureAwait), T-021 (EventArgs Standard), STK-012 (Connection Events)

---

## Links

### Documentazione Progetti

| Progetto | README | ISSUES |
|----------|--------|--------|
| Protocol | [README](./Protocol/README.md) | [ISSUES](./Protocol/ISSUES.md) |
| Drivers.Can | [README](./Drivers.Can/README.md) | [ISSUES](./Drivers.Can/ISSUES.md) |
| Drivers.Ble | [README](./Drivers.Ble/README.md) | [ISSUES](./Drivers.Ble/ISSUES.md) |
| Client | [README](./Client/README.md) | [ISSUES](./Client/ISSUES.md) |
| Tests | [README](./Tests/README.md) | - |

### Documentazione Layer

| Layer | README | ISSUES |
|-------|--------|--------|
| Application (L7) | [README](./Protocol/Layers/ApplicationLayer/README.md) | [ISSUES](./Protocol/Layers/ApplicationLayer/ISSUES.md) |
| Presentation (L6) | [README](./Protocol/Layers/PresentationLayer/README.md) | [ISSUES](./Protocol/Layers/PresentationLayer/ISSUES.md) |
| Session (L5) | [README](./Protocol/Layers/SessionLayer/README.md) | [ISSUES](./Protocol/Layers/SessionLayer/ISSUES.md) |
| Transport (L4) | [README](./Protocol/Layers/TransportLayer/README.md) | [ISSUES](./Protocol/Layers/TransportLayer/ISSUES.md) |
| Network (L3) | [README](./Protocol/Layers/NetworkLayer/README.md) | [ISSUES](./Protocol/Layers/NetworkLayer/ISSUES.md) |
| DataLink (L2) | [README](./Protocol/Layers/DataLinkLayer/README.md) | [ISSUES](./Protocol/Layers/DataLinkLayer/ISSUES.md) |
| Physical (L1) | [README](./Protocol/Layers/PhysicalLayer/README.md) | [ISSUES](./Protocol/Layers/PhysicalLayer/ISSUES.md) |
| Base | [README](./Protocol/Layers/Base/README.md) | [ISSUES](./Protocol/Layers/Base/ISSUES.md) |
| Stack | [README](./Protocol/Layers/Stack/README.md) | [ISSUES](./Protocol/Layers/Stack/ISSUES.md) |

### Documentazione Tecnica

```
Docs/
├── CONTRIBUTING.md                          # Guida per contribuire al progetto
├── Diagrams/                                # Diagrammi PlantUML
│   ├── activity-diagram.puml
│   ├── class-diagram.puml
│   ├── sequence-diagram.puml
│   ├── state-machine-diagram.puml
│   └── use-case-diagram.puml
└── Standards/                               # Standard di sviluppo
    ├── COMMENTS_STANDARD.md                 # T-018: Commenti XML
    ├── CONFIGURATION_STANDARD.md            # T-011: Costanti/Configurazione
    ├── ERROR_HANDLING_STANDARD.md           # T-012: Gestione Errori
    ├── EVENTARGS_STANDARD.md                # T-021: EventArgs Tipizzati
    ├── INTERFACE_STANDARD.md                # Criteri per interfacce
    ├── LIFECYCLE_STANDARD.md                # T-013: Lifecycle Helper
    ├── LOGGING_STANDARD.md                  # T-002: Logging Strutturato
    ├── STATISTICS_STANDARD.md               # T-004: Sistema Statistiche
    ├── TEMPLATE_STANDARD.md                 # Standard per template
    ├── THREAD_SAFETY_STANDARD.md            # T-005: Thread Safety
    ├── VISIBILITY_STANDARD.md               # T-017: Visibilita Componenti
    ├── CANCELLATION_STANDARD.md             # T-024: CancellationToken Propagation
    └── Templates/                           # Template documenti
        ├── ISSUES_TEMPLATE.md               # Template per ISSUES.md
        ├── README_TEMPLATE.md               # Template per README.md
        └── STANDARD_TEMPLATE.md             # Template per standard
```

| Standard | Issue | Descrizione |
|----------|-------|-------------|
| [ERROR_HANDLING_STANDARD.md](./Docs/Standards/ERROR_HANDLING_STANDARD.md) | T-012 | Gestione errori tipizzati, `ProtocolError`, factory `*Errors` |
| [EVENTARGS_STANDARD.md](./Docs/Standards/EVENTARGS_STANDARD.md) | T-021 | EventArgs tipizzati, immutabilita, invarianti |
| [INTERFACE_STANDARD.md](./Docs/Standards/INTERFACE_STANDARD.md) | - | Criteri per definizione interfacce (YAGNI) |
| [THREAD_SAFETY_STANDARD.md](./Docs/Standards/THREAD_SAFETY_STANDARD.md) | T-005 | Pattern `Lock`, `Volatile.Read/Write`, `Interlocked` |
| [COMMENTS_STANDARD.md](./Docs/Standards/COMMENTS_STANDARD.md) | T-018 | XML docs, lingua italiana, tag obbligatori |
| [VISIBILITY_STANDARD.md](./Docs/Standards/VISIBILITY_STANDARD.md) | T-017 | `internal sealed` per helper, `public sealed` per API |
| [CONFIGURATION_STANDARD.md](./Docs/Standards/CONFIGURATION_STANDARD.md) | T-011 | Pattern Constants - Configuration - Layer |
| [LIFECYCLE_STANDARD.md](./Docs/Standards/LIFECYCLE_STANDARD.md) | T-013 | Costruttore vs `InitializeAsync()` |
| [LOGGING_STANDARD.md](./Docs/Standards/LOGGING_STANDARD.md) | T-002 | `ILogger<T>`, logging strutturato |
| [STATISTICS_STANDARD.md](./Docs/Standards/STATISTICS_STANDARD.md) | T-004 | `ILayerStatistics`, metriche thread-safe |
| [CANCELLATION_STANDARD.md](./Docs/Standards/CANCELLATION_STANDARD.md) | T-024 | `CancellationToken` propagation, `ConfigureAwait(false)` |

---

## Licenza

- **Proprietario:** STEM E.m.s.
- **Autore:** Luca Veronelli (l.veronelli@stem.it)
- **Data di Creazione:** 2026-01-27
- **Licenza:** Proprietaria - Tutti i diritti riservati

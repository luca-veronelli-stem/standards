# README Template - Struttura Standard per README

> **Versione:** 1.1  
> **Data:** 2026-02-24  
> **Stato:** Active

---

## Scopo

Questo template definisce la struttura standard per tutti i file `README.md` del progetto **Stem.Production.Tracker**:

- **README Progetto** - Per i progetti della soluzione (`Core/`, `Services/`, `Infrastructure.*/`, `Windows.GUI/`, `Devices.*/`)
- **README Root** - Per il README principale della soluzione

L'obiettivo è garantire **consistenza**, **completezza** e **navigabilità** in tutta la documentazione.

---

## Convenzioni

| Elemento | Formato | Esempio |
|----------|---------|---------|
| **Data** | ISO 8601 | `2026-02-24` |
| **Encoding** | UTF-8 | - |
| **Link** | Relativi | `./ISSUES.md`, `../Core/README.md` |
| **Diagrammi** | Box-drawing Unicode | `┌─┐ │ └─┘` |
| **Alberi directory** | Unicode | `├── └── │` |

---

## Tipo di README

### Identificazione

| Tipo | Applicabile a | Sezioni Specifiche |
|------|---------------|-------------------|
| **Progetto** | `Core/`, `Services/`, `Infrastructure.*/`, `Windows.GUI/`, `Devices.*/`, `Tests/` | Caratteristiche, API/Componenti |
| **Root** | `README.md` (root soluzione) | Badge, Quick Start globale |

---

## Template Completo - Progetto

Per i README dei progetti della soluzione:

```markdown
# {NomeProgetto}

> **{Descrizione breve in 1-2 righe}**  
> **Ultimo aggiornamento:** YYYY-MM-DD

---

## Panoramica                              [OBBLIGATORIA]

{Descrizione del progetto: cosa fa, perché esiste, ruolo nella soluzione}

---

## Caratteristiche                         [Opzionale - per librerie]

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **Feature 1** | ✅ | Descrizione breve |
| **Feature 2** | ⚠️ | In sviluppo |

---

## Requisiti                               [OBBLIGATORIA]

- **.NET 10.0** o superiore
- {Altri requisiti specifici}

### Dipendenze

| Package | Versione | Uso |
|---------|----------|-----|
| {Package} | {Version} | {Descrizione} |

---

## Quick Start                             [OBBLIGATORIA]

```csharp
// Esempio minimale di utilizzo
``

---

## Struttura                               [Opzionale - se complessa]

``
{NomeProgetto}/
├── {Cartella1}/
├── {Cartella2}/
└── {File.cs}
``

---

## API / Componenti                        [Opzionale - per librerie]

{Descrizione API principali, interfacce, classi chiave}

---

## Configurazione                          [Opzionale - per applicazioni]

{Parametri di configurazione, file config, variabili ambiente}

---

## Esecuzione / Testing                    [Opzionale - per test/app]

```bash
# Comandi per eseguire
dotnet test
``

---

## Issue Correlate                         [OBBLIGATORIA]

→ [{NomeProgetto}/ISSUES.md](./ISSUES.md)

---

## Links                                   [OBBLIGATORIA - sempre ultima per README progetto]

- [Documento correlato](./path/to/doc.md)

---

## Template Completo - Root

Per il README principale della soluzione:

```markdown
# {NomeSoluzione}

> **{Descrizione breve}**

[![.NET](https://img.shields.io/badge/.NET-10.0-512BD4)](https://dotnet.microsoft.com/)
[![Tests](https://img.shields.io/badge/tests-{N}%20passing-brightgreen)](./Tests/)
[![License](https://img.shields.io/badge/license-Proprietary-red)](#licenza)

> **Ultimo aggiornamento:** YYYY-MM-DD

---

## Panoramica                              [OBBLIGATORIA]

{Descrizione della soluzione}

---

## Caratteristiche                         [OBBLIGATORIA]

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **Feature 1** | ✅ | Descrizione |

---

## Requisiti                               [OBBLIGATORIA]

- **.NET 10.0** o superiore

---

## Quick Start                             [OBBLIGATORIA]

```csharp
// Esempio minimale
``

---

## Struttura Soluzione                     [OBBLIGATORIA]

``
Stem.Production.Tracker/
├── Core/                        # Modelli, interfacce, enums
├── Services/                    # Logica di business
├── Infrastructure.Persistence/  # EF Core, SQLite, repositories
├── Infrastructure.Protocol/     # Comunicazione BLE con dispositivi
├── Windows.GUI/                 # Applicazione WPF
├── Devices.EdenBs8/            # Plugin per EDEN BS8
└── Tests/                       # Unit & integration tests
``

---

## Documentazione                          [OBBLIGATORIA]

- [ER Schema](./docs/ER_Schema.puml)
- [Standards](./Docs/Standards/)

---

## Issue Correlate                         [OBBLIGATORIA]

→ [ISSUES.md](./ISSUES.md)

---

## Licenza                                 [OBBLIGATORIA - SOLO README ROOT]

- **Proprietario:** STEM E.m.s.
- **Autore:** Luca Veronelli (l.veronelli@stem.it)
- **Data di Creazione:** yyyy-mm-dd
- **Licenza:** Proprietaria - Tutti i diritti riservati
```

---

## Sezioni Obbligatorie vs Opzionali

### README Progetto

| # | Sezione | Obbl. | Condizione |
|---|---------|:-----:|------------|
| 1 | Panoramica | ✅ | Sempre |
| 2 | Caratteristiche | ⚪ | Per librerie |
| 3 | Requisiti | ✅ | Sempre |
| 4 | Quick Start | ✅ | Sempre |
| 5 | Struttura | ⚪ | Se complessa |
| 6 | API / Componenti | ⚪ | Per librerie |
| 7 | Configurazione | ⚪ | Per applicazioni |
| 8 | Esecuzione / Testing | ⚪ | Per test/app |
| 9 | Issue Correlate | ✅ | Sempre |
| 10 | Links | ✅ | Sempre (ultima per README progetto) |

### README Root

| # | Sezione | Obbl. |
|---|---------|:-----:|
| 1 | Titolo + Badge | ✅ |
| 2 | Panoramica | ✅ |
| 3 | Caratteristiche | ✅ |
| 4 | Requisiti | ✅ |
| 5 | Quick Start | ✅ |
| 6 | Struttura Soluzione | ✅ |
| 7 | Documentazione | ✅ |
| 8 | Issue Correlate | ✅ |
| 9 | Licenza | ✅ (ultima, SOLO qui) |

---

## Note Specifiche per Progetto

| Progetto | Note |
|----------|------|
| **Core** | Modelli di dominio, enums, interfacce repository |
| **Services** | Logica di business, orchestrazione |
| **Infrastructure.Persistence** | EF Core, DbContext, Repositories, Migrations |
| **Infrastructure.Protocol** | Comunicazione BLE con dispositivi STEM |
| **Windows.GUI** | Applicazione WPF, MVVM, DI setup |
| **Devices.EdenBs8** | Plugin specifico per dispositivo EDEN BS8 |
| **Tests** | xUnit, test unitari e integrazione |

---

## Checklist Validazione

### README Progetto

- [ ] Template corretto usato
- [ ] Data aggiornata
- [ ] Sezioni obbligatorie presenti
- [ ] Link funzionanti
- [ ] Links come ultima sezione

### README Root

- [ ] Badge presenti e aggiornati
- [ ] Quick Start funzionante
- [ ] Struttura soluzione aggiornata
- [ ] Licenza come ultima sezione (formato completo)

---

## Changelog

| Data | Versione | Descrizione |
|------|----------|-------------|
| 2026-02-24 | 1.0 | Versione iniziale per Stem.Production.Tracker |
| 2026-02-25 | 1.1 | Licenza solo in README root, formato standardizzato |
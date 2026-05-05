# README Template - Struttura Standard

> **Versione:** 1.0  
> **Data:** 2026-03-09
> **Stato:** Active

---

## Scopo

Questo template definisce la struttura standard per i file `README.md` del progetto Spark Log Analyzer:

- **README Progetto** - Per i progetti della soluzione (`Windows.GUI/`, `Core/`, `Services/`, `Tests/`)
- **README Root** - Per il README principale della soluzione

---

## Convenzioni

| Elemento | Formato | Esempio |
|----------|---------|---------|
| **Data** | ISO 8601 | `2025-03-09` |
| **Encoding** | UTF-8 | - |
| **Link** | Relativi | `./ISSUES.md`, `../Core/README.md` |
| **Alberi directory** | Unicode | `├── └── │` |

---

## Template - README Root

Per il README principale della soluzione (`README.md`):

```markdown
# {NomeSoluzione}

> **{Descrizione breve in 1-2 righe}**

> **Ultimo aggiornamento:** YYYY-MM-DD

---

## Panoramica                              [OBBLIGATORIA]

{Descrizione della soluzione: cosa fa, perché esiste, a chi serve}

### Funzionalità principali

- Funzionalità 1
- Funzionalità 2

---

## Struttura della Soluzione               [OBBLIGATORIA]

| Progetto | Descrizione |
|----------|-------------|
| Windows.GUI | Applicazione WPF - interfaccia utente |
| Core | Modelli, interfacce e mapper condivisi |
| Services | Client Azure, conversione XLSX, statistiche |
| Tests | Unit/Integration tests (xUnit) |
| Docs | Documentazione tecnica |

---

## Requisiti                               [OBBLIGATORIA]

- **.NET 10** o superiore
- {Altri requisiti}

---

## Per Iniziare                            [OBBLIGATORIA]

```sh
dotnet restore
dotnet build
dotnet test
dotnet run --project Windows.GUI
``

---

## Configurazione                          [OBBLIGATORIA se presente]

{Variabili ambiente, file di configurazione}

---

## Funzionalità Dettagliate                [Opzionale]

{Descrizione delle feature principali}

---

## Documentazione                          [OBBLIGATORIA]

- [Documento tecnico](./Docs/DOCUMENTO.md)
- [Changelog](./CHANGELOG.md)

---

## Stato Sviluppo                          [Opzionale]

- [x] Feature completata
- [ ] Feature da fare

---

## Licenza                                 [OBBLIGATORIA - sempre ultima]

- **Proprietario:** STEM E.m.s.
- **Autore:** {Nome} ({email})
- **Licenza:** Proprietaria - Tutti i diritti riservati
``

---

## Template - README Progetto

Per i README dei singoli progetti (`Windows.GUI/`, `Core/`, `Services/`, `Tests/`):

```markdown
# {NomeProgetto}

> **{Descrizione breve in 1 riga}**  
> **Ultimo aggiornamento:** YYYY-MM-DD

---

## Panoramica                              [OBBLIGATORIA]

{Descrizione del progetto: cosa fa, ruolo nella soluzione}

---

## Struttura                               [OBBLIGATORIA]

``
{NomeProgetto}/
├── {Cartella}/
│   ├── File1.cs              # Descrizione
│   └── File2.cs              # Descrizione
└── {File.cs}                 # Descrizione
``

---

## Componenti Principali                   [OBBLIGATORIA]

### {NomeClasse}

{Descrizione breve - 1-2 frasi}

**Metodi principali:**
- `Metodo1()` - descrizione
- `Metodo2()` - descrizione

---

## Dipendenze                              [OBBLIGATORIA]

| Package | Versione | Uso |
|---------|----------|-----|
| {Package} | {Version} | {Descrizione} |

---

## Esempi di Utilizzo                      [Opzionale]

```csharp
// Esempio di codice
``

---

## Links                                   [OBBLIGATORIA]

- [README principale](../README.md)
- [Progetto correlato](../Core/README.md)
```

---

## Sezioni Obbligatorie vs Opzionali

### README Root

| # | Sezione | Obbl. | Note |
|---|---------|:-----:|------|
| 1 | Panoramica | ✅ | Max 5 righe |
| 2 | Struttura Soluzione | ✅ | Tabella progetti |
| 3 | Requisiti | ✅ | .NET version, dipendenze sistema |
| 4 | Per Iniziare | ✅ | Comandi build/run |
| 5 | Configurazione | ⚪ | Se ha config/env vars |
| 6 | Funzionalità Dettagliate | ⚪ | Per feature complesse |
| 7 | Documentazione | ✅ | Link a docs |
| 8 | Stato Sviluppo | ⚪ | Checklist feature |
| 9 | Licenza | ✅ | Sempre ultima |

### README Progetto

| # | Sezione | Obbl. | Note |
|---|---------|:-----:|------|
| 1 | Panoramica | ✅ | Max 3 righe |
| 2 | Struttura | ✅ | Tree directory |
| 3 | Componenti Principali | ✅ | Classi/servizi chiave |
| 4 | Dipendenze | ✅ | NuGet packages |
| 5 | Esempi di Utilizzo | ⚪ | Per librerie |
| 6 | Links | ✅ | Riferimenti correlati |

---

## Checklist Validazione

### README Root

- [ ] Data aggiornata nell'header
- [ ] Panoramica ≤5 righe
- [ ] Tabella struttura completa
- [ ] Comandi build/run funzionanti
- [ ] Link documentazione validi
- [ ] Licenza presente come ultima sezione

### README Progetto

- [ ] Data aggiornata nell'header
- [ ] Tree directory aggiornato
- [ ] Componenti principali documentati
- [ ] Dipendenze elencate con versioni
- [ ] Link a README root presente

---

## Note per questo Progetto

| Progetto | Note Specifiche |
|----------|-----------------|
| **Windows.GUI** | Documentare controlli XAML principali, ViewModels |
| **Core** | Documentare modelli (SparkLogEntry, FaultInfo, ecc.) |
| **Services** | Documentare servizi (XlsxExporter, FaultDecoder, ecc.) |
| **Tests** | Documentare organizzazione test, coverage |

---

## Changelog Template

| Data | Versione | Descrizione |
|------|----------|-------------|
| 2025-03-09 | 1.0 | Versione iniziale |

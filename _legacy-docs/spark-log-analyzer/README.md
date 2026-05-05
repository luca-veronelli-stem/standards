# Spark Log Analyzer

> **Applicazione desktop per l'analisi dei log delle macchine SPARK**

[![.NET](https://img.shields.io/badge/.NET-10.0-512BD4?logo=dotnet)](https://dotnet.microsoft.com/)
[![Tests](https://img.shields.io/badge/tests-259%20passing-brightgreen)](#tests)
[![Platform](https://img.shields.io/badge/platform-Windows-0078D6?logo=windows)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/license-Proprietary-red)](#licenza)

> **Ultimo aggiornamento:** 2026-04-17

---

## Panoramica

Applicazione WPF per l'analisi dei log delle macchine SPARK. Si connette automaticamente ad **Azure Table Storage** per scaricare i log più recenti, oppure permette di caricare file XLSX esportati manualmente.

### Funzionalità principali

- 📊 **Dashboard KPI** con statistiche fault in tempo reale
- 📅 **Selettore periodo**: settimana, mese, da Gen 2025, tutto
- 🔄 **Sincronizzazione automatica** ogni 5 minuti
- 📁 **Caricamento manuale** da file XLSX (fallback offline)
- 📥 **Tre modalità di esportazione**: Completa, Semplice, Riepilogo
- 🔍 **Filtro multi-selezione** per Serial Number
- 📈 **Statistiche avanzate** per S/N (fault certi/stimati, range)

---

## Struttura della Soluzione

| Progetto | Descrizione | README |
|----------|-------------|--------|
| **GUI.Windows** | Applicazione WPF - interfaccia utente | [→ README](./GUI.Windows/README.md) |
| **Core** | Modelli, interfacce e mapper condivisi | [→ README](./Core/README.md) |
| **Services** | Client Azure, export XLSX, statistiche | [→ README](./Services/README.md) |
| **Tests** | Unit/Integration tests (xUnit - **240 test CI, 259 in locale**) | [→ README](./Tests/README.md) |
| **Docs** | Documentazione tecnica | [→ Docs](./Docs/) |

---

## Requisiti

- **.NET 10** Desktop Runtime
- Windows 10/11

---

## Per Iniziare

```bash
# Clone e build
git clone https://bitbucket.org/stem-fw/spark-logs-viewer.git
cd spark-logs-viewer
dotnet restore
dotnet build

# Esegui test
dotnet test

# Avvia applicazione
dotnet run --project Windows.GUI
```

---

## Configurazione

### Variabili d'ambiente per Azure

```
# Log delle macchine (obbligatoria per sync automatico)
SPARK_LOGS_TABLE_SAS_URL=https://account.table.core.windows.net/sparkdecodedevents?sv=...

# Dati utilizzatori (opzionale, per export Summary)
SPARK_CUSTOMERS_TABLE_SAS_URL=https://account.table.core.windows.net/sparkcustomers?sv=...
```

Se non configurate, l'app funziona in **modalità offline** (solo caricamento file locale).

---

## Funzionalità Export XLSX

Il bottone **"Esporta"** offre tre opzioni:

| Modalità | File | Descrizione |
|----------|------|-------------|
| 📊 **Completa** | Nuovo | Multi-sheet: Log completi (41 col), Log faults (23 col), Statistiche |
| 📋 **Semplice** | Nuovo | Singolo sheet, solo colonne essenziali (6 col) |
| 📈 **Riepilogo** | Storico fleet (append) | File persistente con un foglio per ogni export, per confrontare KPI delle macchine nel tempo |

### Export Riepilogo — file storico fleet

L'export Riepilogo non crea un nuovo file ad ogni click: **appende un nuovo foglio a un file `.xlsx` persistente** scelto dall'utente. Struttura del file:

- Un foglio per ogni export, nome = `YYYY-MM-DD` (il più recente in prima posizione).
- Stesso layout riga in tutti i fogli: un seriale per riga, ordinati alfabeticamente. La riga `N` in ogni foglio corrisponde sempre alla stessa macchina, così si può sfogliare avanti/indietro per confrontare i KPI nel tempo.
- Foglio **"Note"** statico in coda: creato al primo export, contiene le limitazioni del calcolo fault e la nota sulla data di installazione.
- Se un seriale appare per la prima volta in un nuovo export, viene inserito anche nei fogli precedenti (colonna 1 con il seriale, colonne 2-8 vuote) per mantenere l'allineamento.
- Se due export cadono nella stessa data, il secondo foglio riceve suffisso `_2`, `_3`, ...

**Colonne di ogni foglio data:**

| Colonna | Descrizione |
|---------|-------------|
| Numero seriale | Una riga per ogni seriale |
| Data installazione | Data di installazione (da Azure) |
| Utilizzatore | Nome utilizzatore (da Azure) |
| Città utilizzatore | Città utilizzatore (da Azure) |
| Carichi completati totali | Dal log più recente |
| Carichi nel periodo | Differenza tra log più recente e più datato |
| Fault avvenuti | Codici errore DIVERSI con status ATTIVO |
| Risolto | Sì/No/N/A - fault passati a confermato |

> ⚠️ **Limitazione offline**: Le colonne "Data installazione", "Utilizzatore" e "Città utilizzatore" mostrano "N/A" se la variabile `SPARK_CUSTOMERS_TABLE_SAS_URL` non è configurata o se si lavora in modalità offline.

---

## Statistiche Calcolate

| Metrica | Descrizione |
|---------|-------------|
| Op. Riuscite | Log senza fault ATTIVO (bit 0 = 1) |
| Op. Fallite | Log con almeno un fault ATTIVO |
| Fault Certi | Fault visti con status attivo |
| Fault Stimati | Basati su incremento FaultNumber |
| Range | Stima min-max fault reali |
| % Successo | Op. Riuscite / Totale |

> ⚠️ Le statistiche sono **INDICATIVE** a causa del buffer limitato (5 log) e dell'aging automatico (40 cicli).

---

## Documentazione

| Documento | Contenuto |
|-----------|-----------|
| [REPORT_SISTEMA_LOG_SPARK.md](./Docs/REPORT_SISTEMA_LOG_SPARK.md) | Protocollo log, fault status, catalogo errori |
| [CHANGELOG.md](./CHANGELOG.md) | Storico versioni |
| [README_TEMPLATE.md](./Docs/Standards/README_TEMPLATE.md) | Template standard per README |

---

## Stato Sviluppo

- [x] Struttura soluzione
- [x] CI/CD Pipeline (Bitbucket)
- [x] Modelli Core (SparkLogEntry, FaultInfo, FaultStatistics)
- [x] Implementazione FaultDecoder (supporto status 0x48, 0x4D)
- [x] Implementazione StatisticsService (statistiche avanzate per S/N)
- [x] Implementazione XlsxExporter (Completa + Semplice + Riepilogo)
- [x] **CustomerService** (dati utilizzatori da Azure Table)
- [x] **Export Summary con dati utilizzatore** (Data, Nome, Città)
- [x] **Export Riepilogo come file storico fleet** (append-on-existing, un foglio per export)
- [x] **Timestamp in ora italiana** (`ItalianTime` helper, gestione CET/CEST)
- [x] Test suite (**259 test** totali, 240 cross-platform)
- [x] GUI con KPI Dashboard
- [x] Filtro multi-selezione per Serial Number
- [x] Sincronizzazione automatica da Azure Table Storage
- [x] Documentazione tecnica completa

---

## Licenza

- **Proprietario:** STEM E.m.s.
- **Autore:** Luca Veronelli (l.veronelli@stem.it)
- **Data di Creazione:** 2026-02-17
- **Licenza:** Proprietaria - Tutti i diritti riservati


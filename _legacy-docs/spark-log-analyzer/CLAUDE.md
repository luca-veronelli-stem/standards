# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Comandi principali

```bash
# Build
dotnet build Spark.Log.Analyzer.slnx --configuration Release

# Tutti i test
dotnet test Tests/Tests.csproj

# Test singolo (per nome classe o metodo)
dotnet test Tests/Tests.csproj --filter "FullyQualifiedName~FaultDecoder"

# Solo test cross-platform (come fa la CI)
dotnet test Tests/Tests.csproj --framework net10.0

# Avviare l'applicazione
dotnet run --project GUI.Windows
```

**Variabili d'ambiente richieste a runtime:**
- `SPARK_LOGS_TABLE_SAS_URL` — URL SAS Azure Table Storage per i log (obbligatoria)
- `SPARK_CUSTOMERS_TABLE_SAS_URL` — URL SAS per i dati clienti (opzionale, serve per l'export Summary)

---

## Architettura

Il progetto è una WPF desktop app che legge log da Azure Table Storage, li decodifica e li esporta in Excel. La soluzione è divisa in 4 progetti con separazione netta:

```
Core       ← domain models + interfacce, zero dipendenze applicative
Services   ← implementazioni concrete, dipende solo da Core
GUI.Windows ← WPF, dipende da Core + Services
Tests      ← multi-target net10.0 + net10.0-windows, dipende da tutto
```

### Core
Contiene modelli (`SparkLogEntry`, `FaultInfo`, `FaultStatus`, `FaultStatistics`, `CustomerInfo`) e le interfacce dei servizi (`IFaultDecoder`, `IStatisticsService`, `IAzureTableLogClient`, `ILogSyncService`, ecc.). Non ha logica applicativa — solo contratti e strutture dati. Unica dipendenza: `Azure.Data.Tables` (per i tipi entità).

### Services
Implementa tutte le interfacce di Core:
- `AzureTableLogClient` — legge log da Azure Table Storage via SAS token
- `LogSyncService` — polling ogni 5 minuti, espone eventi `NewLogsAvailable` / `ConnectionStatusChanged` / `SyncError`
- `FaultDecoder` — decodifica i campi raw dei log SPARK in `FaultInfo`
- `StatisticsService` — calcola KPI aggregati (`FaultStatistics`)
- `CustomerService` — risolve numero seriale → nome cliente da Azure Table
- `XlsxExporter` — export Complete e Simple (nuovo file). Per Summary delega a `SummarySheetManager` (via `ExportSummaryAppend` o via ramo `ExportType.Summary` di `Export`, che passa `DateTime.Today`)
- `SummarySheetManager` — ciclo di vita del file storico fleet Riepilogo: apre/crea il file, appende un foglio `YYYY-MM-DD` in prima posizione, patcha i fogli vecchi con i nuovi seriali (inserimento bottom-up per non spostare righe), crea una volta sola il foglio statico "Note"
- `XlsxToJsonConverter` — importa Excel → JSON per bulk upload

### GUI.Windows
La Dependency Injection è manuale nel costruttore di `MainWindow`: le istanze dei servizi vengono create lì e passate come dipendenze. Non c'è un DI container. I ViewModel (`LogEntryViewModel`, `SerialNumberFilterItem`) wrappano i modelli per il binding WPF. I converter XAML (`NegateConverter`, `SumConverter`) stanno in `Converters/`. Il DataGrid dei log usa un `ControlTemplate` custom per ottenere header a due livelli (riga parent raggruppata + child header), con scroll orizzontale sincronizzato via `Canvas.Left` e larghezze gruppo calcolate da `MultiBinding` su `Columns[i].ActualWidth`.

### Tests
Usa xUnit. I test Windows-specifici (es. ViewModel WPF) sono compilati condizionalmente con il simbolo `WINDOWS`, definito solo nel target `net10.0-windows`. La CI esegue solo `--framework net10.0` su container Linux.

---

## Pattern e convenzioni chiave

- **Nessun DI container** — le dipendenze vengono passate via costruttore, cablate a mano in `MainWindow`
- **Interfacce solo dove servono** — ogni interfaccia ha esattamente un'implementazione concreta (le interfacce esistono per i test, non per l'extensibility)
- **Mock manuali nei test** — nessuna libreria di mocking; i fake sono classi scritte a mano
- **`Nullable=enable`** — nullable reference types attivi ovunque; non usare `null` come valore di ritorno per errori
- **Conditional compilation per i test Windows** — il simbolo `WINDOWS` è definito solo nel target `net10.0-windows` in `Tests.csproj`

---

## CI (Bitbucket Pipelines)

```yaml
image: mcr.microsoft.com/dotnet/sdk:10.0
script:
  - dotnet build Spark.Log.Analyzer.slnx --configuration Release -p:EnableWindowsTargeting=true
  - dotnet test Tests/Tests.csproj --framework net10.0 --no-build --configuration Release
```

Il flag `-p:EnableWindowsTargeting=true` permette di compilare il progetto WPF su runner Linux senza errori. I test WPF (net10.0-windows) non girano in CI.

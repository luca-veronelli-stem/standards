# Services

> **Implementazioni dei servizi per Spark Log Analyzer**  
> **Ultimo aggiornamento:** 2026-04-17

---

## Panoramica

Il progetto **Services** contiene le implementazioni concrete delle interfacce definite in Core. Gestisce la connessione ad Azure, l'import/export dei dati e il calcolo delle statistiche.

---

## Struttura

```
Services/
├── AzureTableLogClient.cs    # Client Azure Table Storage
├── LogSyncService.cs         # Sincronizzazione periodica
├── FaultDecoder.cs           # Decodifica fault code 16-bit
├── StatisticsService.cs      # Calcolo statistiche per S/N
├── CustomerService.cs        # Recupero dati utilizzatori
├── XlsxExporter.cs           # Export Excel (Complete/Simple) + delega Summary
├── SummarySheetManager.cs    # File storico fleet (append-on-existing)
└── XlsxToJsonConverter.cs    # Import da file XLSX locale
```

---

## Componenti Principali

### AzureTableLogClient

Client per accesso alla tabella Azure contenente i log SPARK. Usa SAS Token per l'autenticazione.

**Configurazione:**
```csharp
// Variabile d'ambiente richiesta
SPARK_LOGS_TABLE_SAS_URL=https://account.table.core.windows.net/tablename?sv=...
```

**Metodi principali:**
- `GetLogsLastDaysAsync(int days)` - Log degli ultimi N giorni
- `GetAllLogsAsync()` - Tutti i log disponibili
- `GetLogsSinceAsync(DateTime from)` - Log da una data specifica

---

### FaultDecoder

Decodifica i fault code 16-bit in oggetti `FaultInfo` leggibili.

```csharp
// Esempio: 3956 = 0x0F74 → Status 15, Error 116
var decoder = new FaultDecoder();
var fault = decoder.Decode(3956);
// fault.IsActive = true
// fault.ErrorCode = 116
// fault.ErrorDescription = "Incongruenza posizione ruote"
```

**Metodi principali:**
- `Decode(int faultCode)` - Decodifica singolo fault
- `DecodeAll(SparkLogEntry entry)` - Decodifica tutti i fault di un log
- `HasActiveFaults(SparkLogEntry entry)` - Verifica presenza fault attivi

---

### CustomerService

Recupera informazioni sugli utilizzatori delle macchine SPARK da Azure Table Storage.

**Configurazione:**
```csharp
// Variabile d'ambiente richiesta
SPARK_CUSTOMERS_TABLE_SAS_URL=https://account.table.core.windows.net/sparkcustomers?sv=...
```

**Tabella Azure `sparkcustomers`:**
| Colonna | Descrizione |
|---------|-------------|
| PartitionKey | `legacy_serial` (anni 12-23) o `current_serial` |
| RowKey | Numero seriale (senza prefisso) |
| OperatingCompanyName | Nome utilizzatore |
| OperatingCompanyCity | Città utilizzatore |
| InstallationDate | Data installazione |

**Metodi principali:**
- `GetCustomerAsync(serial)` - Singolo cliente per seriale
- `GetCustomersAsync(serials)` - Batch per più seriali
- `IsAvailable` - Verifica se il servizio è configurato

---

### XlsxExporter

Export dei log in formato Excel.

| Modalità | File | Contenuto |
|----------|------|-----------|
| **Complete** | Nuovo | Log completi (41 col), Log faults (23 col), Statistiche |
| **Simple** | Nuovo | Solo colonne essenziali (6 col) |
| **Summary** | Storico fleet (append) | Delega a `SummarySheetManager` — vedi sezione dedicata |

```csharp
var exporter = new XlsxExporter(faultDecoder);

// Complete / Simple: creano un nuovo file
exporter.Export("output.xlsx", logs, ExportType.Complete);

// Summary: appende al file storico (crea se non esiste)
exporter.ExportSummaryAppend("fleet_history.xlsx", logs, customers, DateTime.Today);
```

I timestamp nei fogli Excel sono convertiti in ora locale italiana tramite `Core.Utils.ItalianTime`.

---

### SummarySheetManager

Gestisce il ciclo di vita del **file storico fleet** per l'export Riepilogo: ogni chiamata a `AppendExport` aggiunge un nuovo foglio data al file `.xlsx` persistente, mantenendo allineati i seriali tra i fogli così da permettere il confronto dei KPI di una macchina nel tempo.

**Flusso `AppendExport(filePath, logs, customers, exportDate)`:**

1. Apre il file esistente o ne crea uno nuovo.
2. Legge la master list dei seriali dai fogli esistenti (ignorando il foglio "Note").
3. Calcola la nuova master list = `union(master, seriali del nuovo export)` ordinata alfabeticamente.
4. Per i seriali nuovi, inserisce righe nei fogli esistenti dal basso verso l'alto (per non spostare righe già inserite). La nuova riga eredita bordi e allineamento dalla riga sottostante, sfondo sempre bianco.
5. Risolve il nome del nuovo foglio: `YYYY-MM-DD`, con suffisso `_2`, `_3`, ... se la data è già usata.
6. Crea il nuovo foglio in posizione 1 (più recente a sinistra) e lo popola. Macchine presenti nella master list ma senza dati nel periodo ricevono solo il seriale in colonna 1.
7. Al primo export crea il foglio statico "Note" in coda, con il disclaimer sulle limitazioni del calcolo fault e sulla data di installazione. Sui export successivi non viene mai modificato.
8. Salva.

```csharp
var manager = new SummarySheetManager(faultDecoder);
manager.AppendExport("fleet_history.xlsx", logs, customers, new DateTime(2026, 4, 17));
```

Il calcolo dei KPI per riga (carichi totali/nel periodo, fault distinti attivi, colonna "Risolto") è interno al manager.

---

### StatisticsService

Calcola statistiche aggregate per Serial Number.

**Metriche calcolate:**
- Operazioni riuscite/fallite (basate su fault ATTIVI)
- Fault certi (visti attivi)
- Fault stimati (da delta FaultNumber)
- Range min-max fault reali
- Percentuale successo

```csharp
var stats = statisticsService.CalculateFaultStatistics(logs);
// stats.TotalLogs = 150
// stats.LogsWithActiveFault = 8
// stats.SuccessRate = 94.7%
```

---

### LogSyncService

Gestisce la sincronizzazione periodica dei log da Azure.

**Funzionalità:**
- Download incrementale (solo nuovi log)
- Timer automatico configurabile
- Fallback in caso di errori di rete

---

### XlsxToJsonConverter

Converte file XLSX (esportati manualmente) in lista di `SparkLogEntry`.

```csharp
var converter = new XlsxToJsonConverter();
var logs = converter.Convert("logs_export.xlsx");
```

---

## Dipendenze

| Package | Versione | Uso |
|---------|----------|-----|
| Azure.Data.Tables | 12.11.0 | Connessione Azure Table Storage |
| ClosedXML | 0.105.0 | Lettura/scrittura file Excel |

| Progetto | Uso |
|----------|-----|
| Core | Interfacce e modelli |

---

## Links

- [README principale](../README.md)
- [Core (interfacce)](../Core/README.md)
- [Documentazione tecnica](../Docs/REPORT_SISTEMA_LOG_SPARK.md)

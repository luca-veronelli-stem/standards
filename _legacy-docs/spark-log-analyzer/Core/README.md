# Core

> **Modelli, interfacce e definizioni condivise per Spark Log Analyzer**  
> **Ultimo aggiornamento:** 2026-04-17

---

## Panoramica

Il progetto **Core** contiene tutti i modelli di dominio, le interfacce dei servizi e le definizioni condivise utilizzate dagli altri progetti della soluzione. Non ha dipendenze da UI o implementazioni concrete.

---

## Struttura

```
Core/
├── Interfaces/
│   ├── IAzureTableLogClient.cs    # Client per Azure Table Storage
│   ├── IFaultDecoder.cs           # Decodifica fault code 16-bit
│   ├── ILogSyncService.cs         # Sincronizzazione log da Azure
│   ├── IStatisticsService.cs      # Calcolo statistiche fault
│   ├── IXlsxExporter.cs           # Export dati in Excel (Complete/Simple/Summary-append)
│   ├── IXlsxToJsonConverter.cs    # Conversione XLSX → JSON
│   └── ICustomerService.cs        # Recupero dati utilizzatori
│
├── Models/
│   ├── SparkLogEntry.cs           # Modello principale log SPARK
│   ├── FaultInfo.cs               # Fault code decodificato
│   ├── FaultStatus.cs             # Status bits del fault (8 bit)
│   ├── FaultStatistics.cs         # Statistiche aggregate
│   ├── SparkLogReport.cs          # Report con lista log
│   ├── ExportType.cs              # Enum tipi export (Complete/Simple/Summary)
│   ├── ErrorCodeDefinitions.cs    # Catalogo codici errore DTC
│   ├── AzureTableMapper.cs        # Mapping Azure → SparkLogEntry
│   ├── CustomerInfo.cs            # Info utilizzatore + SerialFormatHelper
│   ├── EquipmentTypeHelper.cs     # Helper tipi equipaggiamento
│   ├── OperationTypeHelper.cs     # Helper tipi operazione
│   └── RawMessageParser.cs        # Parser messaggio binario
│
└── Utils/
    └── ItalianTime.cs             # Conversione UTC → ora locale italiana (CET/CEST)
```

---

## Componenti Principali

### SparkLogEntry

Modello principale che rappresenta un singolo log della macchina SPARK.

**Proprietà principali:**
- `SerialNumber` - Numero seriale macchina
- `Timestamp` - Data/ora operazione
- `WriteWorkInfo` - Tipo operazione (LOAD, UNLOAD, FREE_WORK)
- `FaultCode1..5` - Fino a 5 fault simultanei (formato 16-bit)
- `CompleteLoadCycleNumber` / `CompleteUnloadCycleNumber` - Contatori cicli
- Sensori: pressione, corrente, temperatura, accelerazione

### FaultInfo

Rappresenta un fault code decodificato con tutte le informazioni leggibili.

**Proprietà:**
- `RawCode` - Valore originale (es. 3956)
- `StatusByte` - MSB: stato del fault (0-255)
- `ErrorCode` - LSB: codice errore DTC (0-255)
- `IsActive` - `true` se bit 0 = 1 (testFailed)
- `IsConfirmed` - `true` se bit 3 = 1 (confirmedDTC)
- `ErrorName` / `ErrorDescription` / `Category` - Info dal catalogo

### FaultStatus

Decodifica degli 8 bit di status di un fault.

| Bit | Nome | Significato |
|-----|------|-------------|
| 0 | `TestFailed` | Fault attivo ORA |
| 1 | `TestFailedThisMonitoringCycle` | Fault nel ciclo corrente |
| 2 | `PendingDTC` | Fault in attesa |
| 3 | `ConfirmedDTC` | Fault confermato |
| 4-6 | Test flags | Stato test diagnostici |

### ExportType

Enum per i tipi di esportazione disponibili.

```csharp
public enum ExportType
{
    Complete,  // Multi-sheet con tutti i dati
    Simple,    // Singolo sheet essenziale
    Summary    // Riepilogo per seriale
}
```

### CustomerInfo

Informazioni sull'utilizzatore di una macchina SPARK.

**Proprietà:**
- `SerialNumber` - Numero seriale (senza prefisso sn-spark-)
- `Cliente` - Nome dell'utilizzatore
- `Citta` - Città dell'utilizzatore
- `DataInizioServizio` - Data di installazione

### SerialFormatHelper

Helper per gestire i formati dei numeri seriali SPARK.

| Metodo | Descrizione |
|--------|-------------|
| `IsLegacyFormat(serial)` | Verifica se è formato legacy (7 cifre, anni 12-23) |
| `ExtractSerialNumber(logSerial)` | Rimuove prefisso `sn-spark-` |
| `GetPartitionKey(serial)` | Ritorna `legacy_serial` o `current_serial` |

### ItalianTime (`Core.Utils`)

Converte timestamp UTC nell'ora locale italiana (`Europe/Rome`). Gestisce automaticamente CET (UTC+1) in inverno e CEST (UTC+2) in estate. I valori con `DateTimeKind.Unspecified` vengono trattati come UTC (caso tipico dei timestamp ricavati da `DateTimeOffset.DateTime` tornati da Azure Table Storage).

```csharp
DateTime? italian = ItalianTime.Convert(utcTimestamp);
```

Usato dalla GUI (DataGrid) e dagli export Excel per presentare timestamp leggibili all'utente italiano.

---

## Interfacce

| Interfaccia | Responsabilità |
|-------------|----------------|
| `IFaultDecoder` | Decodifica fault code 16-bit → `FaultInfo` |
| `IAzureTableLogClient` | Query su Azure Table Storage |
| `ILogSyncService` | Sincronizzazione periodica log |
| `IStatisticsService` | Calcolo statistiche per S/N |
| `IXlsxExporter` | Export in formato Excel (include `ExportSummaryAppend` per il file storico fleet) |
| `IXlsxToJsonConverter` | Import da file XLSX locale |
| `ICustomerService` | Recupero dati utilizzatori da Azure Table |

---

## Dipendenze

| Package | Versione | Uso |
|---------|----------|-----|
| Azure.Data.Tables | 12.11.0 | Modelli per Azure Table Storage |

---

## Links

- [README principale](../README.md)
- [Documentazione tecnica](../Docs/REPORT_SISTEMA_LOG_SPARK.md)
- [Services (implementazioni)](../Services/README.md)

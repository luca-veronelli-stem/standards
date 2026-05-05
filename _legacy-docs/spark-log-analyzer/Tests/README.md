# Tests

> **Test suite per Spark Log Analyzer (xUnit)**  
> **Ultimo aggiornamento:** 2026-04-17

---

## Panoramica

Il progetto **Tests** contiene tutti i test unitari e di integrazione per la soluzione. Utilizza **xUnit** come framework di test e **Coverlet** per la code coverage.

**Totale test: 259 (in locale) / 240 (in CI)** ✅

Multi-target: `net10.0` (CI, solo test cross-platform) e `net10.0-windows` (in locale, include anche i ViewModel WPF). I test Windows-specifici sono protetti dal simbolo di compilazione `WINDOWS` definito solo nel target `net10.0-windows`.

---

## Struttura

```
Tests/
├── Models/
│   ├── AzureTableMapperTests.cs       # Test mapping Azure → SparkLogEntry
│   └── SerialFormatHelperTests.cs     # Test helper formato seriali
│
├── Services/
│   ├── AzureTableLogClientTests.cs    # Test client Azure
│   ├── CustomerServiceTests.cs        # Test servizio dati utilizzatori
│   ├── FaultDecoderTests.cs           # Test decodifica fault 16-bit
│   ├── LogSyncServiceTests.cs         # Test sincronizzazione
│   ├── StatisticsServiceTests.cs      # Test calcolo statistiche
│   ├── XlsxExporterTests.cs           # Test export Excel (Complete/Simple + delega Summary)
│   ├── SummarySheetManagerTests.cs    # Test file storico fleet (append/patch/note)
│   └── XlsxToJsonConverterTests.cs    # Test import XLSX
│
├── ViewModels/
│   └── SerialNumberFilterItemTests.cs # Test ViewModel filtro S/N
│
├── Windows.GUI/
│   └── LogEntryViewModelTests.cs      # Test ViewModel log entry
│
├── Integration/
│   └── EndToEndTests.cs               # Test end-to-end pipeline
│
└── Data/                              # File di test (XLSX, JSON)
```

---

## Distribuzione Test

| Categoria | File | Test |
|-----------|------|------|
| **Services** | 8 file | ~185 |
| **Models** | 2 file | ~50 |
| **ViewModels** | 2 file | ~15 (Windows-only) |
| **Integration** | 1 file | ~17 |

---

## Test Principali

### FaultDecoderTests

Test per la decodifica dei fault code 16-bit.

```csharp
[Fact]
public void Decode_ActiveFault_ReturnsCorrectStatus()
{
    // 0x0F74 = Status 15 (ATTIVO) + Error 116
    var fault = _decoder.Decode(0x0F74);
    Assert.True(fault.IsActive);
    Assert.Equal(116, fault.ErrorCode);
}
```

---

### XlsxExporterTests

Test per Complete e Simple + verifica che il ramo Summary deleghi a `SummarySheetManager`.

| Test | Verifica |
|------|----------|
| `Export_Complete_Creates3Sheets` | Multi-sheet con tutti i dati |
| `Export_Simple_CreatesSingleSheet` | Singolo sheet 6 colonne |
| `Export_Summary_DelegatesToSummarySheetManager` | Summary passa dal manager (file con foglio data + "Note") |
| `ExportSummaryAppend_DelegatesToSummarySheetManager` | Entry point dedicato funziona |

### SummarySheetManagerTests

Copertura completa del ciclo di vita del file storico fleet (append/patch/note).

| Test | Verifica |
|------|----------|
| `AppendExport_FirstExport_CreatesFileWithDateSheetAndNoteSheet` | Primo export crea foglio data + "Note" |
| `AppendExport_DateSheetIsAtPositionOne` | Il foglio più recente è sempre in prima posizione |
| `AppendExport_SecondExportNoNewSerials_ExistingSheetRowsUnchanged` | I fogli vecchi non vengono modificati |
| `AppendExport_SecondExportWithNewSerials_InsertsRowsAlphabetically` | Nuovi seriali inseriti nella posizione alfabetica corretta anche nei fogli vecchi |
| `AppendExport_SameDateTwice_SecondSheetGetsSuffix` | Gestione dei duplicati con suffisso `_2` |
| `AppendExport_SerialPresentInOldSheetAbsentFromNew_RowIsEmptyExceptSerial` | Allineamento righe: macchina senza attività resta nella master list |
| `AppendExport_NoteSheetCreatedOnlyOnce` | Il foglio "Note" non viene più modificato dopo il primo export |
| `AppendExport_RisoltoIsSi_WhenFaultConfirmedLater` | Logica colonna "Risolto" (passaggio ATTIVO → CONFERMATO) |
| `AppendExport_NewSerialInsertedInOldSheet_HasWhiteBackground` | Stile righe inserite: sfondo sempre bianco anche se la riga sotto è evidenziata |

---

### StatisticsServiceTests

Test per il calcolo delle statistiche.

| Test | Verifica |
|------|----------|
| `CalculateStats_CountsActiveFaults` | Solo fault con bit 0 = 1 |
| `CalculateStats_ComputesSuccessRate` | Percentuale successo |
| `CalculateDetailedStats_RangeEstimate` | Range min-max fault |

---

### EndToEndTests

Test di integrazione della pipeline completa.

```csharp
[Fact]
public void FullPipeline_LoadExportReload_DataIntegrity()
{
    // 1. Carica da XLSX
    // 2. Calcola statistiche
    // 3. Esporta
    // 4. Ricarica e verifica integrità
}
```

---

## Esecuzione

```sh
# Tutti i test
dotnet test

# Con verbosità
dotnet test --verbosity normal

# Filtro per categoria
dotnet test --filter "FullyQualifiedName~FaultDecoder"

# Con coverage
dotnet test --collect:"XPlat Code Coverage"
```

---

## Dipendenze

| Package | Versione | Uso |
|---------|----------|-----|
| xunit | 2.9.3 | Framework test |
| xunit.runner.visualstudio | 3.1.4 | Runner VS |
| Microsoft.NET.Test.Sdk | 17.14.1 | SDK test |
| coverlet.collector | 6.0.4 | Code coverage |

| Progetto | Uso |
|----------|-----|
| Core | Modelli da testare |
| Services | Servizi da testare |
| Windows.GUI | ViewModels da testare |

---

## Convenzioni

- **Naming**: `{Metodo}_{Scenario}_{Risultato}` 
  - Es: `Decode_ZeroCode_ReturnsNull`
- **Arrange-Act-Assert**: Struttura standard per ogni test
- **File di test**: Cartella `Data/` con file XLSX/JSON per test

---

## CI/CD

I test vengono eseguiti automaticamente nella pipeline Bitbucket:

```yaml
- step:
    name: Test
    script:
      - dotnet test --configuration Release
```

---

## Links

- [README principale](../README.md)
- [Core (modelli)](../Core/README.md)
- [Services (servizi)](../Services/README.md)

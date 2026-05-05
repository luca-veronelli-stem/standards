# Changelog

Tutte le modifiche rilevanti a questo progetto sono documentate in questo file.

Il formato si basa su [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
e questo progetto aderisce a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

### Legenda

- **Added**: Nuove funzionalità
- **Changed**: Modifiche a funzionalità  esistenti
- **Deprecated**: Funzionalità che verranno rimosse
- **Removed**: Funzionalità rimosse
- **Fixed**: Bug corretti
- **Security**: Vulnerabilità corrette

---

## [Unreleased]

### Added

- **Header raggruppati nel DataGrid log**: riga parent con categorie (Info Generali, Pressione [Bar], Corrente Motori Gambe [A], Temperatura [°C], Corrente Motori Ruote [A], Pitch [°], Accelerazione Max [g], Accelerazione Media [g], Fault) con colore di sfondo dedicato per gruppo
- **8 nuove colonne nel DataGrid**: Pitch Max/Min, Accelerazione Max X/Y/Z, Accelerazione Media X/Y/Z (le proprietà erano già nel ViewModel ma non visualizzate)
- **Converters**: `NegateConverter` (IValueConverter) e `SumConverter` (IMultiValueConverter) in `GUI.Windows/Converters/`, usati dal template del DataGrid per scroll sync e larghezze gruppo dinamiche
- **ItalianTime helper** (`Core/Utils/ItalianTime.cs`): converte timestamp UTC → ora locale italiana (Europe/Rome), con gestione automatica CET/CEST. I valori `Unspecified` vengono trattati come UTC
- **Export Riepilogo come file storico fleet**: ogni export appende un nuovo foglio (nome `YYYY-MM-DD`) a un file `.xlsx` persistente invece di crearne uno nuovo. Ogni foglio condivide lo stesso layout righe (un seriale per riga, ordinate alfabeticamente) così l'utente può confrontare KPI della stessa macchina nel tempo sfogliando i fogli
- **Foglio "Note" statico** nel file storico: contiene le limitazioni sul calcolo fault e la nota sulla data di installazione, creato al primo export e mai più modificato
- **`SummarySheetManager`** (`Services/`): nuova classe che gestisce il ciclo di vita del file storico (lettura master list, patch bottom-up per nuovi seriali, risoluzione nomi duplicati con suffisso `_2/_3/...`)
- **`IXlsxExporter.ExportSummaryAppend`**: nuovo entry point per il Summary che accetta `exportDate` esplicita (facilita i test e dà controllo sul nome del foglio)

### Changed

- **Header figli del DataGrid log**: label descrittive al posto delle abbreviazioni (es. "Testa Max" al posto di "P.Testa", "Stato/Codice/Descrizione" al posto di "St1/E1/Desc1"), grassetto, centrati, colore `#444444` uniforme con i parent header
- **Larghezze colonne adattive**: tutte le colonne usano `Width="Auto"` e si ridimensionano al contenuto; `MinWidth` su Pitch e Accelerazione per garantire che la somma dei child copra il testo del parent header
- **Bordi griglia completi**: linee verticali e orizzontali visibili in tutte le celle (`GridLinesVisibility="All"`), bordo inferiore sui child header
- **Padding interno**: 6px orizzontali su celle e header per separare il contenuto dalle linee
- **DataGrid ControlTemplate**: override completo per integrare la riga group header sopra il `DataGridColumnHeadersPresenter` nello stesso `ScrollViewer` (scroll orizzontale automaticamente sincronizzato)
- **CanUserResizeColumns="False"**: il ridimensionamento manuale è disabilitato — le larghezze sono guidate dal contenuto via `Width="Auto"`
- **Timestamp in ora italiana**: le entry nel DataGrid e i timestamp negli export Excel (Complete, Simple, Log faults) passano attraverso `ItalianTime.Convert` — prima venivano mostrati in UTC
- **Pulsante "Esporta → Riepilogo" usa `OpenFileDialog`**: l'utente seleziona un file esistente (per appendere) oppure digita un nuovo nome (per crearlo). Prima apriva `SaveFileDialog` che creava sempre un file nuovo con timestamp

### Removed

- **`XlsxExporter.CreateSummarySheet`**: logica inline del Summary (258 righe, footer "NOTE SULLE LIMITAZIONI" incluso) spostata interamente in `SummarySheetManager`. Il ramo `ExportType.Summary` di `Export` ora delega al manager con `DateTime.Today`

### Fixed

- **Ordine log nel DataGrid**: i log vengono ordinati per timestamp decrescente al caricamento iniziale; i nuovi log ricevuti dal sync vengono inseriti in cima alla lista invece di essere accodati in fondo

---

## [0.6.0] - 2025-03-17

### Added

- **CustomerService**: Nuovo servizio per recuperare dati utilizzatori da Azure Table Storage
- **ICustomerService**: Interfaccia per il servizio dati clienti
- **CustomerInfo**: Modello per informazioni utilizzatore (Nome, Città, Data installazione)
- **SerialFormatHelper**: Helper per gestione formati seriali (legacy vs current)
- **Export Summary con dati utilizzatore**: Nuove colonne "Data installazione", "Utilizzatore", "Città utilizzatore"
- **Variabile SPARK_CUSTOMERS_TABLE_SAS_URL**: Configurazione opzionale per dati clienti
- **15 nuovi test**: CustomerServiceTests, SerialFormatHelperTests, test export con clienti

### Changed

- Export Riepilogo ora mostra 8 colonne (prima 5)
- Ordine colonne: Seriale, Data, Utilizzatore, Città, Carichi totali, Carichi periodo, Fault, Risolto
- Celle senza dati mostrano "N/A" con stile grigio corsivo
- AutoFilter applicato solo sulla colonna "Numero seriale"
- Allineamento contenuto celle a sinistra

### Note

- In modalità offline le colonne utilizzatore mostrano "N/A"
- Richiede nuova variabile `SPARK_CUSTOMERS_TABLE_SAS_URL` per dati clienti (opzionale)
- Test totali: 247 (da 232)

---

## [0.5.0] - 2025-03-09

Prima release interna per test.

### Added

- **Azure Sync**: Connessione automatica ad Azure Table Storage per download log
- **Dashboard KPI**: Statistiche fault in tempo reale (totali, attivi, percentuale)
- **Selettore periodo**: Ultima settimana, ultimo mese, da Gen 2025, tutto
- **Filtro multi-selezione**: Checkbox per selezionare più Serial Number
- **Export Completa**: 3 fogli Excel (Log completi 41 col, Log faults 23 col, Statistiche)
- **Export Semplice**: 1 foglio Excel con 6 colonne essenziali
- **Export Riepilogo**: Statistiche aggregate per seriale (carichi, fault avvenuti, risolto)
- **Caricamento manuale**: Fallback offline da file XLSX locale
- **FaultDecoder**: Decodifica fault code 16-bit (status + DTC) con catalogo errori
- **StatisticsService**: Calcolo statistiche avanzate per Serial Number
- **Tests**: 202 test unitari e di integrazione

### Note

- Richiede .NET 10 Desktop Runtime
- Variabile ambiente `SPARK_LOGS_TABLE_SAS_URL` per connessione Azure

---

## Storico URL versioni

[Unreleased]: https://bitbucket.org/stem-fw/spark-logs-analyzer/branches/compare/HEAD..v0.6.0
[0.6.0]: https://bitbucket.org/stem-fw/spark-logs-analyzer/src/v0.6.0/
[0.5.0]: https://bitbucket.org/stem-fw/spark-logs-analyzer/src/v0.5.0/
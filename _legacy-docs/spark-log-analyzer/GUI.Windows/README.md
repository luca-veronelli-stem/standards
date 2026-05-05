# Windows.GUI

> **Interfaccia utente WPF per Spark Log Analyzer**  
> **Ultimo aggiornamento:** 2026-04-17

---

## Panoramica

Il progetto **GUI.Windows** è l'applicazione WPF che fornisce l'interfaccia utente per visualizzare e analizzare i log delle macchine SPARK. Si connette ad Azure Table Storage per scaricare i log e offre funzionalità di export in Excel.

---

## Struttura

```
GUI.Windows/
├── App.xaml                  # Configurazione applicazione
├── App.xaml.cs               # Entry point
├── MainWindow.xaml           # Finestra principale (UI)
├── MainWindow.xaml.cs        # Code-behind (logica UI)
├── AssemblyInfo.cs           # Metadata assembly
├── Converters/
│   ├── NegateConverter.cs          # IValueConverter: nega un double (scroll sync group header)
│   └── SumConverter.cs             # IMultiValueConverter: somma di double (larghezze gruppo)
└── ViewModels/
    ├── LogEntryViewModel.cs         # ViewModel per riga DataGrid
    └── SerialNumberFilterItem.cs    # ViewModel per filtro S/N
```

---

## Funzionalità UI

### Dashboard KPI

5 card con statistiche in tempo reale:

| KPI | Descrizione |
|-----|-------------|
| 📊 Log Totali | Numero totale di log caricati |
| ⚠️ Con Fault | Log con almeno un fault (qualsiasi status) |
| 🔴 Fault Attivi | Log con fault ATTIVO (bit 0 = 1) |
| 📈 % Fault | Percentuale log con fault attivi |
| 🔄 Ultimo Sync | Timestamp ultima sincronizzazione |

---

### Toolbar

| Controllo | Funzione |
|-----------|----------|
| 🟢 Indicatore | Stato connessione Azure (verde/grigio/rosso) |
| 📅 Periodo | Selettore: Settimana / Mese / Da Gen 2025 / Tutto |
| 🔍 Filtro S/N | Multi-selezione Serial Number con checkbox |
| 🔄 Sync | Forza sincronizzazione manuale |
| 📥 Esporta | Menu dropdown con 3 modalità export |
| 📁 File | Carica log da file XLSX locale |

---

### Filtro Serial Number

Dropdown con checkbox per selezione multipla:

```
┌─────────────────────┐
│ ☑ Seleziona tutti   │  ← Toggle all
│ ───────────────────│
│ ☑ 34469             │
│ ☑ 34470             │
│ ☐ 34471             │
│ ☑ 34472             │
└─────────────────────┘
```

**Testo bottone dinamico:**
- "Tutti" - tutti selezionati
- "Nessuno" - nessuno selezionato
- "3 selezionati" - selezione parziale
- "34469" - singolo seriale

---

### DataGrid

Visualizza i log con evidenziazione fault attivi:

| Stile | Condizione |
|-------|------------|
| Sfondo rosa `#FFEBEE` | `HasActiveFault = true` |
| Font bold | Riga con fault attivo |
| Alternating rows | Righe alternate grigio chiaro |

**Ordinamento di default:** timestamp decrescente (log più recenti in cima). I nuovi log ricevuti via sync appaiono in cima senza richiedere riordinamento manuale.

**Header a due livelli:** riga parent con il nome del gruppo (sfondo colorato) sopra i child header con le label delle singole colonne. Gruppi:

| Gruppo parent | Colonne child | Sfondo |
|---------------|---------------|--------|
| Info Generali | Seriale, Equipaggiamento, Operazione, Durata, Timestamp, N° Scarico, N° Carico | `#F5F5F5` |
| Pressione [Bar] | Testa Max/Media, Piedi Max/Media | `#E3F2FD` |
| Corrente Motori Gambe [A] | Testa Max/Media, Piedi Max/Media | `#E8F5E9` |
| Temperatura [°C] | Testa Max, Piedi Max | `#FFF3E0` |
| Corrente Motori Ruote [A] | Testa/Piedi Dx/Sx Max/Media | `#F3E5F5` |
| Pitch [°] | Max, Min | `#FFF9C4` |
| Accelerazione Max [g] | X, Y, Z | `#FCE4EC` |
| Accelerazione Media [g] | X, Y, Z | `#F8BBD0` |
| Fault | N° Fault + 5×(Stato, Codice, Descrizione) | `#FFEBEE` |

**Implementazione:** `DataGrid.Template` override che inserisce un `Canvas` (riga group header) dentro lo `ScrollViewer` template, sopra al `DataGridColumnHeadersPresenter`. La posizione orizzontale del Canvas è legata a `ScrollViewer.HorizontalOffset` via `Canvas.Left` + `NegateConverter`, così la riga parent scorre in sincronia con le colonne senza bisogno di codice-behind. Le larghezze dei Border parent sono calcolate dinamicamente sommando `Columns[i].ActualWidth` via `SumConverter` (MultiBinding).

**Larghezze:** tutte le colonne usano `Width="Auto"` (si adattano al contenuto); `MinWidth` su Pitch e Accelerazione per garantire copertura del testo del parent header. `CanUserResizeColumns="False"`.

---

### Export Menu

```
📥 Esporta ▾
├── 📊 Completa (multi-sheet, nuovo file)
├── 📋 Semplice (singolo sheet, nuovo file)
└── 📈 Riepilogo (append a file storico fleet)
```

**Riepilogo — scelta file:** il menu apre un `OpenFileDialog` con `CheckFileExists = false` così l'utente può selezionare un file storico esistente (per appendere un nuovo foglio data) **oppure** digitare un nuovo nome per crearne uno. Il file storico è persistente: ogni foglio rappresenta un export datato, allineati per seriale così da permettere il confronto dei KPI nel tempo. Vedi `Services/SummarySheetManager` per i dettagli del formato.

**Complete / Simple:** restano su `SaveFileDialog` (creano sempre un nuovo file con timestamp nel nome).

**Timestamp italiani:** i valori `Timestamp` scritti nel DataGrid e negli export Excel passano per `Core.Utils.ItalianTime.Convert` — l'utente vede ora locale italiana (CET/CEST), non UTC.

---

## ViewModels

### LogEntryViewModel

Wrapper di `SparkLogEntry` con proprietà aggiuntive per la UI.

**Proprietà UI:**
- `HasActiveFault` - Per evidenziazione righe
- `FaultSummary` - Descrizione fault formattata
- `StatusColor` - Colore indicatore status

### SerialNumberFilterItem

Item per il filtro multi-selezione con `INotifyPropertyChanged`.

**Proprietà:**
- `SerialNumber` - Numero seriale
- `IsSelected` - Stato checkbox
- `IsSelectAll` - `true` per item "Seleziona tutti"

---

## Configurazione

### Variabile d'ambiente

```
SPARK_LOGS_TABLE_SAS_URL=https://account.table.core.windows.net/tablename?sv=...
```

Se non configurata, l'app funziona in **modalità offline** (solo caricamento file locale).

### Sincronizzazione automatica

- Intervallo: **5 minuti**
- Indicatore: verde = connesso, grigio = offline, rosso = errore

---

## Dipendenze

| Progetto | Uso |
|----------|-----|
| Core | Modelli e interfacce |
| Services | Implementazioni servizi |

---

## Esecuzione

```sh
# Da Visual Studio
F5 (Debug) o Ctrl+F5 (Release)

# Da terminale
dotnet run --project Windows.GUI
```

---

## Links

- [README principale](../README.md)
- [Core (modelli)](../Core/README.md)
- [Services (servizi)](../Services/README.md)

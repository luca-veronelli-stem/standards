# GUI.Windows

> **Applicazione WPF per il tracciamento della produzione e collaudo dei dispositivi STEM.**  
> **Ultimo aggiornamento:** 2026-03-11

---

## Panoramica

Il progetto **GUI.Windows** è l'interfaccia utente dell'applicazione di tracciamento produzione.

> **Nota:** Il namespace è `GUI.Windows` (non `Windows.GUI`) per evitare conflitti con WinRT APIs.

Utilizza il pattern **MVVM** con **CommunityToolkit.Mvvm** per:
- Navigazione tra pagine
- Binding reattivo
- Comandi asincroni
- Dependency Injection

---

## Caratteristiche

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **Login Page** | ✅ | Selezione utente da DB |
| **Shell + Navigazione** | ✅ | MainWindow con sidebar dinamica per ruolo |
| **AssemblerDashboard** | ✅ | Fasi assegnate + pannello sessione montaggio |
| **TesterDashboard** | ✅ | Device InTesting + pannello sessione collaudo |
| **ManagerDashboard** | ✅ | Panoramica ODL con statistiche |
| **AssemblySessionPanel** | ✅ | Pannello check montaggio + gruppi funzionali + aggiorna firmware |
| **TestSessionPanel** | ✅ | Pannello check collaudo + completamento device + aggiorna firmware |
| **FirmwareUpdateDialog** | ✅ | Dialog selezione e aggiornamento firmware (upload BLE: TODO) |
| **ScanView** | ✅ | Scansione dispositivi BLE |
| **WorkOrdersView** | ✅ | Lista ODL, crea, elimina |
| **Dark Theme** | ✅ | Sidebar e DataGrid scuri |
| **SettingsPage** | 🔲 | Configurazione applicazione |

---

## Requisiti

- **.NET 10.0-windows10.0.19041.0**
- **Windows 10 19041+** per WPF e BLE

### Dipendenze

| Package | Versione | Uso |
|---------|----------|-----|
| `CommunityToolkit.Mvvm` | 8.4.0 | Framework MVVM |
| `Microsoft.Extensions.Hosting` | 10.0.3 | DI Container e lifecycle |
| `Microsoft.EntityFrameworkCore.Design` | 10.0.3 | EF Core migrations |
| `Services` | Project | Logica di business |
| `Infrastructure.Persistence` | Project | Database SQLite |
| `Infrastructure.Protocol` | Project | Comunicazione BLE |

---

## Quick Start

### Avviare l'applicazione

```bash
dotnet run --project GUI.Windows
```

### Database

Il database SQLite viene creato automaticamente al primo avvio in:
```
%APPDATA%\STEM\ProductionTracker\data.db
```

### Registrazione DI

```csharp
// In App.xaml.cs
services.AddPersistence(connectionString);
services.AddFirmwareProvider(configuration);
services.AddServices();
services.AddProtocol();

// ViewModels
services.AddSingleton<MainViewModel>();
services.AddTransient<LoginViewModel>();
services.AddTransient<WorkOrdersViewModel>();
services.AddTransient<ScanViewModel>();
services.AddTransient<FirmwareUpdateViewModel>();

// Views
services.AddTransient<MainWindow>();
services.AddTransient<LoginView>();
services.AddTransient<WorkOrdersView>();
services.AddTransient<ScanView>();
services.AddTransient<FirmwareUpdateDialog>();
```

---

## Struttura

```
GUI.Windows/
├── Converters/
│   ├── BoolToVisibilityConverter.cs  # Supporta parametro "invert"
│   ├── NullToBoolConverter.cs
│   ├── NullToVisibilityConverter.cs
│   ├── RssiToQualityConverter.cs
│   ├── StringToBrushConverter.cs
│   ├── UserRoleToDisplayNameConverter.cs
│   └── ZeroToVisibilityConverter.cs  # Supporta parametro "invert"
├── ViewModels/
│   ├── MainViewModel.cs              # Navigazione + CurrentUser
│   ├── LoginViewModel.cs             # Selezione utente
│   ├── AssemblerDashboardViewModel.cs # Dashboard + pannello montaggio
│   ├── AssemblySessionPanelViewModel.cs # Check + FunctionalGroups + Firmware
│   ├── TesterDashboardViewModel.cs   # Dashboard + pannello collaudo
│   ├── TestSessionPanelViewModel.cs  # Check collaudo + completamento + Firmware
│   ├── FirmwareUpdateViewModel.cs    # Dialog aggiornamento firmware
│   ├── CheckItemViewModel.cs         # Singolo check con Notes + IsDisabled
│   ├── FunctionalGroupItemViewModel.cs # Componente con S/N
│   ├── ManagerDashboardViewModel.cs  # Dashboard manager
│   ├── WorkOrdersViewModel.cs        # CRUD ODL
│   └── ScanViewModel.cs              # Scansione BLE
├── Views/
│   ├── LoginView.xaml                # Selezione utente
│   ├── AssemblerDashboardView.xaml   # Fasi e device montatore
│   ├── AssemblySessionPanel.xaml     # Pannello montaggio
│   ├── TesterDashboardView.xaml      # Device da collaudare
│   ├── TestSessionPanel.xaml         # Pannello collaudo
│   ├── FirmwareUpdateDialog.xaml     # Dialog aggiornamento firmware
│   ├── ManagerDashboardView.xaml     # Panoramica ODL
│   ├── WorkOrdersView.xaml           # Lista ODL
│   ├── ScanView.xaml                 # Scansione BLE
│   └── *.xaml.cs
├── App.xaml                    # Stili globali + converters
├── App.xaml.cs                 # DI container, startup, login flow
├── DatabaseSeeder.cs           # Seed dati sviluppo
├── MainWindow.xaml             # Shell con sidebar dinamica per ruolo
└── GUI.Windows.csproj
```

---

## Architettura

### Pattern MVVM

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│    View     │────▶│  ViewModel  │────▶│   Service   │
│   (XAML)    │     │   (C#)      │     │   (C#)      │
└─────────────┘     └─────────────┘     └─────────────┘
      │                   │                   │
      │    DataBinding    │    Dependency     │
      │    Commands       │    Injection      │
```

### Navigazione

```csharp
// MainViewModel gestisce la navigazione
[RelayCommand]
private void NavigateToWorkOrders()
{
    CurrentPageTitle = "Ordini di Lavoro";
    CurrentPage = _serviceProvider.GetRequiredService<WorkOrdersPage>();
}
```

### CommunityToolkit.Mvvm

```csharp
// Proprietà osservabile
[ObservableProperty]
private string _currentPageTitle = "Home";

// Comando asincrono
[RelayCommand]
private async Task LoadWorkOrdersAsync()
{
    var orders = await _workOrderService.GetAllAsync();
    // ...
}

// Comando con CanExecute
[RelayCommand(CanExecute = nameof(CanDeleteWorkOrder))]
private async Task DeleteWorkOrderAsync() { }
```

---

## Componenti

### MainWindow

Shell principale con:
- **Sidebar** (200px) - Menu navigazione dinamico per ruolo, visibile solo dopo login
- **Header** (50px) - Titolo pagina corrente + nome utente
- **ContentControl** - Area per le pagine

### Pannelli Sessione

Entrambi i pannelli (Assembly e Test) condividono la stessa struttura:
- **Header** - Titolo dinamico + info device + FirmwareVersion
- **Progress bar** - Controlli passati / totale
- **Lista check** - Toggle OK/NO, input valore, note 📝
- **Footer** - Pulsanti Salva/Completa (o Chiudi in readonly)

### TestSessionPanel (NEW)

Pannello collaudo con:
- **Info firmware** - Mostra FirmwareVersion letto dal device
- **Check BLE** - Check che richiedono connessione BLE (IsDisabled se non connesso)
- **Input seriale finale** - Richiesto per completamento
- **Completamento** - Passa device a Completed + assegna seriale finale

### AssemblySessionPanel

Pannello montaggio con:
- **Sezione Gruppi Funzionali** - Input S/N per componenti
- **Completamento** - Richiede tutti i S/N + tutti i check Assembly passati

**Modalità Readonly:**
- Si attiva automaticamente per device InTesting o Completed
- Titolo: "Sessione (Sola Lettura)"
- Pulsanti toggle/input disabilitati
- Solo pulsante "Chiudi" nel footer
- Utile per consultare check e note senza modificare

### FunctionalGroupItemViewModel

ViewModel per singolo componente nel pannello:
- **PartNumber** - Identificativo componente
- **Description** - Descrizione opzionale
- **SerialNumber** - Input S/N (binding TwoWay)
- **IsCompleted** - True se S/N inserito
- **StatusColor** - Verde se completo, grigio se vuoto

### WorkOrdersPage

Lista ODL con:
- **Toolbar** - Aggiorna, Nuovo, Elimina
- **DataGrid** - Lista ODL con selezione
- **Placeholder** - Messaggio quando lista vuota
- **Error Banner** - Messaggi di errore

### Converters

| Converter | Input | Output |
|-----------|-------|--------|
| `NullToVisibilityConverter` | `null` / `non-null` | `Collapsed` / `Visible` |
| `NullToBoolConverter` | `null` / `non-null` | `false` / `true` |
| `ZeroToVisibilityConverter` | `0` / `>0` | `Visible` / `Collapsed` |
| `BoolToVisibilityConverter` | `true` / `false` | `Visible` / `Collapsed` |
| `RssiToQualityConverter` | RSSI (int) | Qualità segnale (string) |
| `UserRoleToDisplayNameConverter` | `UserRole` | Nome italiano |
| `StringToBrushConverter` | Stringa colore (es. "#FF0000") | `SolidColorBrush` |

---

## Configurazione

### Database Path

```csharp
// In App.xaml.cs
private static string GetDatabasePath()
{
    var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
    var folder = Path.Combine(appData, "STEM", "ProductionTracker");
    Directory.CreateDirectory(folder);
    return Path.Combine(folder, "data.db");
}
```

### Stili

Gli stili globali sono definiti in `App.xaml`:
- `SidebarButtonStyle` - Pulsanti sidebar con hover/pressed states

---

## Issue Correlate

→ [GUI.Windows/ISSUES.md](./ISSUES.md)

---

## Links

- [README principale](../README.md)
- [Services](../Services/README.md)
- [Infrastructure.Persistence](../Infrastructure.Persistence/README.md)
- [Infrastructure.Protocol](../Infrastructure.Protocol/README.md)
- [CommunityToolkit.Mvvm Docs](https://learn.microsoft.com/en-us/dotnet/communitytoolkit/mvvm/)

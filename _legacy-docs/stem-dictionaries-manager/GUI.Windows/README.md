# GUI.Windows

> **Applicazione WPF desktop per la gestione dei dizionari STEM.**  
> **Ultimo aggiornamento:** 2026-04-13

---

## Panoramica

Il progetto **GUI.Windows** è l'interfaccia utente desktop per Stem.Dictionaries.Manager. Implementa:

- **WPF + MVVM** - Pattern Model-View-ViewModel con CommunityToolkit.Mvvm
- **Dependency Injection** - Microsoft.Extensions.Hosting per DI/configurazione
- **Navigation Service** - Navigazione tra view con history, parametri e ViewModel caching
- **Clean Architecture** - UI disaccoppiata da business logic e persistence
- **Stili Riutilizzabili** - Dark theme STEM con stili globali e palette colori corporate
- **Input Validation** - Filtri hex/numerico con converter nullable
- **Ricerca Client-Side** - Filtro istantaneo in tutte le liste (case-insensitive)
- **Status Bar Globale** - Feedback visivo colorato per ogni operazione (salvataggio, errori, etc.)
- **Unsaved Changes Guard** - Warning su navigazione indietro con modifiche non salvate
- **Override Variabili Standard** - Override IsEnabled/Description per-dizionario via VariableEdit

L'applicazione si avvia con login integrato nella MainWindow, poi applica migrations e popola dati demo se DB vuoto.

---

## Caratteristiche

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **Login Integrato** | ✅ | LoginView nella MainWindow, eventi LoginConfirmed/LoggedOut |
| **Dark Theme STEM** | ✅ | Palette corporate (#004682 accent, #98D801 success, #E40032 error) |
| **MVVM Pattern** | ✅ | 14 ViewModels con CommunityToolkit.Mvvm |
| **Views** | ✅ | 14 Views XAML complete (incl. LoginView, DarkDialog, DeviceEditView) |
| **Converters** | ✅ | 7 converter (Bool, Inverse, Null, NullableInt, NullableDouble, SeverityToColor, BoolToErrorBrush) |
| **Stili Globali** | ✅ | Sidebar, Toolbar, Watermark, DataGrid, Accent, HexAddress |
| **Navigation Service** | ✅ | History, parametri, ViewModel caching, eventi |
| **Dialog Service** | ✅ | Conferme, messaggi, errori (DarkDialog custom) |
| **Message Service** | ✅ | Status bar globale con colori per severity e auto-hide |
| **IEditableViewModel** | ✅ | Guard per unsaved changes su Indietro e Annulla |
| **DI Container** | ✅ | Generic Host pattern |
| **Auto-Migration** | ✅ | SQL Server: MigrateAsync / SQLite: EnsureCreatedAsync |
| **Database Seeder** | ✅ | Dati iniziali (auto-skip se DB già popolato) |
| **BitInterpretations** | ✅ | Gestione bit per variabili Bitmapped (WordGroups, WordSize 8/16/32) |
| **CRUD Dispositivi** | ✅ | DeviceEditView per creazione/modifica dispositivi (nome, MachineCode, descrizione) |
| **Standard Variables** | ✅ | Sezione variabili standard ereditate in DictionaryEdit (read-only) |
| **Override Mode** | ✅ | VariableEdit in modalità override: IsEnabled + Description + BitInterp editabili |
| **Comandi per Device** | ✅ | DeviceCommandsView per stato attivo/disattivo comandi per device |
| **Filtro Abilitate** | ✅ | Checkbox "Mostra solo abilitate" filtra variabili specifiche e standard in DictionaryEdit |
| **Audit User Provider** | ✅ | MainViewModel setta ICurrentUserProvider dopo login/logout per audit trail |
| **DB Error Handling** | ✅ | Retry loop all'avvio con DarkDialog se DB non raggiungibile (Riprova/Esci) |
| **Auto-fill parametri** | ✅ | MachineCode e FirmwareType pre-compilati con primo valore disponibile in creazione |

---

## Requisiti

- **.NET 10.0** o superiore
- **Windows 10/11** (WPF)

### Dipendenze

| Package | Versione | Uso |
|---------|----------|-----|
| CommunityToolkit.Mvvm | 8.4.0 | MVVM + Source Generators |
| Microsoft.Extensions.Hosting | 10.0.0-preview | DI container + hosting |

### Dipendenze Progetto

| Progetto | Uso |
|----------|-----|
| Infrastructure | DbContext, Repositories |
| Services | Business logic, DTOs |

---

## Quick Start

```bash
# Avviare l'applicazione (da solution root)
dotnet run --project GUI.Windows

# Oppure da Visual Studio: Set as Startup Project → F5
```

### Primo Avvio

1. L'app legge `DatabaseProvider` da `appsettings.json` (o User Secrets)
2. **SQLite** (default): crea il DB in `%AppData%\STEM\DictionariesManager\` con `EnsureCreated`
3. **SQL Server** (Azure): applica le migrations versionati con `MigrateAsync`
4. Se il DB non è raggiungibile → DarkDialog con **Riprova/Esci** (retry loop)
5. Il `DatabaseSeeder` popola dati iniziali se il DB è vuoto (skip automatico se dati presenti)
6. Mostra la LoginView integrata — selezionare un utente e premere ACCEDI
7. Sidebar e header diventano visibili, naviga alla lista dizionari

---

## Struttura

```
GUI.Windows/
├── Abstractions/
│   ├── INavigationService.cs      # Interfaccia navigazione + ViewType enum + ViewModel caching
│   ├── IDialogService.cs          # Interfaccia dialoghi (conferme, errori)
│   ├── IMessageService.cs         # Interfaccia messaggi (status bar)
│   └── IEditableViewModel.cs      # Interfaccia per guard modifiche non salvate
├── Services/
│   ├── NavigationService.cs       # History stack + ViewModel caching per GoBack
│   ├── DialogService.cs           # MessageBox wrapper
│   └── MessageService.cs          # Status bar con auto-hide timer
├── ViewModels/
│   ├── MainViewModel.cs           # Shell, navigazione, status bar, unsaved changes guard
│   ├── LoginViewModel.cs          # Login: carica utenti, conferma login
│   ├── DeviceListViewModel.cs     # Lista dispositivi con ricerca
│   ├── DeviceEditViewModel.cs     # Crea/modifica/elimina dispositivo (MachineCode auto-fill + hint)
│   ├── DeviceDetailViewModel.cs   # Dettaglio device: dizionari + schede associate
│   ├── DictionaryListViewModel.cs # Lista dizionari (double-click per edit)
│   ├── DictionaryEditViewModel.cs # Form dizionario + variabili + StandardVariableItem (record)
│   ├── VariableEditViewModel.cs   # Crea/modifica variabile o override standard
│   ├── DeviceCommandsViewModel.cs # Stato comandi per device (checkbox Attivo, salvataggio bulk)
│   ├── CommandListViewModel.cs    # Lista comandi protocollo (double-click per edit)
│   ├── CommandEditViewModel.cs    # Crea/modifica comando + delete (CodeHigh computed)
│   ├── BoardEditViewModel.cs      # Crea/modifica/elimina scheda (IDeviceService per MachineCode, FirmwareType auto-fill + hint)
│   ├── UserListViewModel.cs       # Lista utenti con add inline
│   ├── SettingsViewModel.cs       # Impostazioni app (stub, non in sidebar v1)
│   ├── WordBitGroup.cs            # Gruppo bit per word (max WordSize bit, Bitmapped)
│   ├── BitInterpretationItem.cs   # Item singolo bit (WordIndex, BitIndex, Meaning)
│   ├── CommandParameterItem.cs    # Item parametro comando (Size, Description)
│   └── CommandDeviceItem.cs       # Item stato comando per device
├── Views/
│   ├── LoginView.xaml             # Login integrato nella MainWindow
│   ├── DeviceListView.xaml        # UI lista dispositivi con ricerca
│   ├── DeviceDetailView.xaml      # UI dettaglio device: dizionari + schede
│   ├── DeviceEditView.xaml        # UI form dispositivo (nuovo/modifica/elimina)
│   ├── DeviceCommandsView.xaml    # UI stato comandi per device
│   ├── DictionaryListView.xaml    # UI lista dizionari (double-click → edit)
│   ├── DictionaryEditView.xaml    # UI form dizionario + 2 sezioni variabili (standard + specifiche)
│   ├── VariableEditView.xaml      # UI edit variabile o override standard (IsEnabled+Description+Bit)
│   ├── CommandListView.xaml       # UI lista comandi (double-click → edit)
│   ├── CommandEditView.xaml       # UI edit comando + delete
│   ├── BoardEditView.xaml         # UI edit scheda (FirmwareType, Dizionario, IsPrimary, elimina)
│   ├── UserListView.xaml          # UI lista utenti (non in sidebar v1)
│   ├── SettingsView.xaml          # UI impostazioni (non in sidebar v1)
│   └── DarkDialog.xaml            # Dialog modale dark theme custom
├── Converters/
│   ├── Converters.cs              # BoolToVisibility, InverseBool, NullToVisibility, BoolToErrorBrush
│   ├── NullableNumericConverter.cs # NullableInt, NullableDouble converters
│   └── SeverityToColorConverter.cs # MessageSeverity → colore status bar
├── App.xaml                       # Application resources + dark theme styles
├── App.xaml.cs                    # Startup, DI, dual provider config, ShowLoginView
├── appsettings.json               # DatabaseProvider + ConnectionStrings
├── MainWindow.xaml                # Shell: sidebar + header + content + status bar
├── MainWindow.xaml.cs             # Window code-behind + shutdown
├── DependencyInjection.cs         # AddGUI() extension method
├── README.md
└── ISSUES.md
```

---

## Architettura

### Pattern MVVM

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│    View     │────▶│  ViewModel   │────▶│   Service    │
│   (XAML)    │     │ (Observable) │     │  (Business)  │
└─────────────┘     └──────────────┘     └──────────────┘
      │                    │                    │
      │ DataBinding        │ Commands           │ Async
      ▼                    ▼                    ▼
   UI Updates         User Actions         Domain Logic
```

### Navigation Flow

```csharp
// Navigare alla lista dizionari
_navigationService.NavigateTo(ViewType.DictionaryList);

// Navigare all'edit con parametro
_navigationService.NavigateTo(ViewType.DictionaryEdit, 
    new NavigationParameter { EntityId = 42 });

// Tornare indietro
_navigationService.GoBack();
```

### ViewType Enum

| ViewType | ViewModel | Descrizione |
|----------|-----------|-------------|
| `DeviceList` | DeviceListViewModel | Lista dispositivi STEM |
| `DeviceEdit` | DeviceEditViewModel | Crea/modifica dispositivo |
| `DeviceDetail` | DeviceDetailViewModel | Dettaglio device: dizionari associati |
| `DeviceCommands` | DeviceCommandsViewModel | Stato comandi per device |
| `DictionaryList` | DictionaryListViewModel | Lista dizionari |
| `DictionaryEdit` | DictionaryEditViewModel | Form dizionario + lista variabili integrata + filtro abilitate |
| `VariableEdit` | VariableEditViewModel | Crea/modifica variabile |
| `CommandList` | CommandListViewModel | Lista comandi |
| `CommandEdit` | CommandEditViewModel | Crea/modifica comando + delete |
| `BoardEdit` | BoardEditViewModel | Crea/modifica scheda |
| `UserList` | UserListViewModel | Lista utenti |
| `Settings` | SettingsViewModel | Impostazioni app (stub) |

---

## API / Componenti

### INavigationService

```csharp
public interface INavigationService
{
    ViewType CurrentView { get; }
    NavigationParameter? CurrentParameter { get; }
    bool CanGoBack { get; }
    object? CachedViewModel { get; }  // ViewModel restored on GoBack

    void SetCurrentViewModel(object? viewModel);  // Register VM for caching
    void NavigateTo(ViewType viewType, NavigationParameter? parameter = null);
    bool GoBack();

    event EventHandler<ViewType>? CurrentViewChanged;
}
```

### IDialogService

```csharp
public enum DialogResult { Ok, Cancel, Yes, No }

public interface IDialogService
{
    Task<DialogResult> ShowConfirmAsync(string title, string message);
    Task<DialogResult> ShowOkCancelAsync(string title, string message);
    Task ShowErrorAsync(string title, string message);
    Task ShowInfoAsync(string title, string message);
    Task ShowWarningAsync(string title, string message);
}
```

### IMessageService

```csharp
public enum MessageSeverity { Info, Success, Warning, Error }

public interface IMessageService
{
    string? CurrentMessage { get; }
    MessageSeverity CurrentSeverity { get; }

    void Show(string message, MessageSeverity severity = MessageSeverity.Info, int autoHideSeconds = 5);
    void Clear();

    event EventHandler? MessageChanged;
}
```

### DI Registration

```csharp
// In App.xaml.cs
services.AddInfrastructure(connectionString, useSqlServer);  // DbContext + Repos
services.AddServices();                                       // Business logic
services.AddGUI();                                            // ViewModels + UI Services
```

---

## Configurazione

### Database Provider

Configurato in `appsettings.json`:

```json
{
  "DatabaseProvider": "SqlServer",
  "ConnectionStrings": {
    "SqlServer": "",
    "Sqlite": ""
  }
}
```

| Provider | Comportamento |
|----------|---------------|
| `SqlServer` | Usa Azure SQL, `MigrateAsync()`, connection string da config/User Secrets |
| `Sqlite` (default) | Usa SQLite locale, `EnsureCreatedAsync()`, fallback `%AppData%` |

> **Connection string SQL Server:** usare **User Secrets** per non committare credenziali nel repo.  
> `dotnet user-secrets set "ConnectionStrings:SqlServer" "Server=...;Database=...;"`

### Database Location (SQLite)

Se non configurato in `appsettings.json`, il database SQLite è creato in:
```
%AppData%\STEM\DictionariesManager\sqldb-dictionaries-manager-test.db
```

### Logging

Il Generic Host configura automaticamente il logging. Per debug verbose:
```csharp
.ConfigureLogging(logging =>
{
    logging.SetMinimumLevel(LogLevel.Debug);
})
```

---

## Issue Correlate

→ [GUI.Windows/ISSUES.md](./ISSUES.md) — 2 issue aperte, 8 risolte

---

## Links

- [Services/README.md](../Services/README.md) - Business logic layer
- [Infrastructure/README.md](../Infrastructure/README.md) - Data persistence
- [Tests/README.md](../Tests/README.md) - Test suite (include GUI tests)
- [.copilot/copilot-instructions.md](../.copilot/copilot-instructions.md) - Architettura e decisioni

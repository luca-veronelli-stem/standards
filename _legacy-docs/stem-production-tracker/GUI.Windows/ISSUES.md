# GUI.Windows - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunità di refactoring e violazioni di best practice per il componente **GUI.Windows**.

> **Ultimo aggiornamento:** 2026-03-11

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 1 | 1 |
| **Media** | 4 | 0 |
| **Bassa** | 6 | 0 |

**Totale aperte:** 11  
**Totale risolte:** 1

---

## Issue Trasversali Correlate

| ID | Titolo | Status | Impatto su GUI.Windows |
|----|--------|--------|------------------------|
| **PERS-002** | Manca Concurrency Token | Aperto | GUI non vedrà conflitti se 2 operatori editano stesso device |
| **SVC-001** | Reflection in TestSessionMapper | Aperto | Ricostruzione sessioni in readonly potrebbe essere lenta |

→ Vedi [Infrastructure.Persistence/ISSUES.md](../Infrastructure.Persistence/ISSUES.md) e [Services/ISSUES.md](../Services/ISSUES.md)

---

## Indice Issue Aperte

- [GUI-002 - Errori silenziosi catch vuoti in CloseAsync](#gui-002--errori-silenziosi-catch-vuoti-in-closeasync)
- [GUI-003 - Async void in SetUserAndNavigate e OnSessionCompleted](#gui-003--async-void-in-setuserandnavigate-e-onsessioncompleted)
- [GUI-004 - Duplicazione codice tra AssemblySessionPanelViewModel e TestSessionPanelViewModel](#gui-004--duplicazione-codice-tra-assemblysessionpanelviewmodel-e-testsessionpanelviewmodel)
- [GUI-005 - SessionPanel eventi non de-registrati (memory leak)](#gui-005--sessionpanel-eventi-non-de-registrati-memory-leak)
- [GUI-006 - DatabaseSeeder hardcoda TestSheetPartNumber](#gui-006--databaseseeder-hardcoda-testsheetpartnumber)
- [GUI-007 - LoginViewModel non de-registra LoginConfirmed](#gui-007--loginviewmodel-non-de-registra-loginconfirmed)
- [GUI-008 - Converters NotImplementedException in ConvertBack](#gui-008--converters-notimplementedexception-in-convertback)
- [GUI-009 - Manca SettingsView (TODO in codice)](#gui-009--manca-settingsview-todo-in-codice)
- [GUI-010 - FirmwareUpdateViewModel upload simulato (TODO)](#gui-010--firmwareupdateviewmodel-upload-simulato-todo)
- [GUI-011 - FirmwareUpdateDialog non annulla operazione in corso](#gui-011--firmwareupdatedialog-non-annulla-operazione-in-corso)
- [GUI-012 - FirmwareUpdateRequested event chain complessa](#gui-012--firmwareupdaterequested-event-chain-complessa)

---

## Indice Issue Risolte

- [GUI-001 - App.xaml.cs ShowLoginView crea sottoscrizioni duplicate](#gui-001--appxamlcs-showloginview-crea-sottoscrizioni-duplicate) ✅

---

## Priorità Media

### GUI-002 - Errori silenziosi catch vuoti in CloseAsync

**Categoria:** Observability  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

In `AssemblySessionPanelViewModel.CloseAsync()` gli errori di salvataggio vengono catturati e ignorati silenziosamente. Se il salvataggio fallisce, l'utente non lo sa.

#### File Coinvolti

- `GUI.Windows\ViewModels\AssemblySessionPanelViewModel.cs` (righe 206-211)
- `GUI.Windows\ViewModels\AssemblerDashboardViewModel.cs` (righe 144-147)

#### Codice Problematico

```csharp
catch
{
    // Ignora errori di salvataggio alla chiusura
}

// E anche:
catch
{
    // Ignora errori di refresh
}
```

#### Soluzione Proposta

Almeno loggare l'errore o mostrare una notifica non bloccante:

```csharp
catch (Exception ex)
{
    // Mostra warning non bloccante (toast o status bar)
    System.Diagnostics.Debug.WriteLine($"Salvataggio fallito: {ex.Message}");
    
    // Oppure imposta warning message (non bloccante)
    WarningMessage = "Alcune modifiche potrebbero non essere state salvate";
}
```

#### Benefici Attesi

- Errori visibili per debug
- Utente informato se qualcosa non viene salvato

---

### GUI-003 - Async void in SetUserAndNavigate e OnSessionCompleted

**Categoria:** Anti-Pattern  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

I metodi `SetUserAndNavigate()` e `OnSessionCompleted()` sono `async void`. Le eccezioni in `async void` non possono essere catturate e crashano l'applicazione.

#### File Coinvolti

- `GUI.Windows\ViewModels\MainViewModel.cs` (riga 61)
- `GUI.Windows\ViewModels\TesterDashboardViewModel.cs` (riga 74)
- `GUI.Windows\ViewModels\AssemblerDashboardViewModel.cs` (analogo)

#### Codice Problematico

```csharp
// async void - eccezioni non catturabili!
public async void SetUserAndNavigate(User user)
{
    CurrentUser = user;
    await NavigateToDashboardAsync();  // Se lancia, crash!
}

// async void event handler
private async void OnSessionCompleted()
{
    await LoadDevicesAsync();  // Se lancia, crash!
}
```

#### Soluzione Proposta

**Per event handler:** Wrap in try-catch

```csharp
private async void OnSessionCompleted()
{
    try
    {
        await LoadDevicesAsync();
    }
    catch (Exception ex)
    {
        ErrorMessage = $"Errore: {ex.Message}";
    }
}
```

**Per metodi pubblici:** Evitare async void, usare Task

```csharp
// Cambia firma
public async Task SetUserAndNavigateAsync(User user)
{
    CurrentUser = user;
    await NavigateToDashboardAsync();
}

// In App.xaml.cs
loginViewModel.LoginConfirmed += async user =>
{
    try
    {
        await mainViewModel.SetUserAndNavigateAsync(user);
    }
    catch (Exception ex)
    {
        // Handle error
    }
};
```

#### Benefici Attesi

- Nessun crash silenzioso
- Errori gestiti correttamente
- Pattern standard async

---

### GUI-004 - Duplicazione codice tra AssemblySessionPanelViewModel e TestSessionPanelViewModel

**Categoria:** Code Smell  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

`AssemblySessionPanelViewModel` e `TestSessionPanelViewModel` hanno struttura quasi identica:
- Stesse proprietà: `IsOpen`, `IsLoading`, `ErrorMessage`, `Checks`, `CanComplete`
- Stessi metodi: `OpenAsync`, `CloseAsync`, `RecordCheckOutcomeAsync`, `LoadChecksFromSession`
- Stessi eventi: `Closed`, `SessionCompleted`

~200 righe duplicate.

#### File Coinvolti

- `GUI.Windows\ViewModels\AssemblySessionPanelViewModel.cs` (~400 righe)
- `GUI.Windows\ViewModels\TestSessionPanelViewModel.cs` (~350 righe)

#### Soluzione Proposta

**Estrarre classe base:**

```csharp
public abstract class SessionPanelViewModelBase : ObservableObject
{
    [ObservableProperty] protected bool _isOpen;
    [ObservableProperty] protected bool _isLoading;
    [ObservableProperty] protected string? _errorMessage;
    [ObservableProperty] protected ObservableCollection<CheckItemViewModel> _checks = [];

    public event Action? Closed;
    public event Action? SessionCompleted;

    // Template method
    public async Task OpenAsync(Device device, string operatorName, bool readOnly = false)
    {
        // Logica comune...
        await LoadSessionAsync(device, operatorName, readOnly);  // Abstract
    }

    protected abstract Task LoadSessionAsync(Device device, string operatorName, bool readOnly);
}
```

#### Benefici Attesi

- Eliminazione ~200 righe duplicate
- Singolo punto di manutenzione per logica comune
- Facile aggiunta di nuovi tipi di sessione

---

### GUI-005 - SessionPanel eventi non de-registrati (memory leak)

**Categoria:** Resource Management  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

In `SetSessionPanel()`, i dashboard si sottoscrivono a `Closed` e `SessionCompleted` ma non si de-registrano mai. Se il ViewModel viene risolto più volte (es. navigazione ripetuta), si accumulano handler.

#### File Coinvolti

- `GUI.Windows\ViewModels\AssemblerDashboardViewModel.cs` (righe 61-71)
- `GUI.Windows\ViewModels\TesterDashboardViewModel.cs` (righe 56-66)

#### Codice Problematico

```csharp
public void SetSessionPanel(AssemblySessionPanelViewModel panel, User currentUser)
{
    SessionPanel = panel;
    _currentUser = currentUser;

    if (SessionPanel is not null)
    {
        // Mai de-registrati!
        SessionPanel.Closed += OnSessionPanelClosed;
        SessionPanel.SessionCompleted += OnSessionCompleted;
    }
}
```

#### Soluzione Proposta

```csharp
public void SetSessionPanel(AssemblySessionPanelViewModel panel, User currentUser)
{
    // De-registra dal pannello precedente
    if (SessionPanel is not null)
    {
        SessionPanel.Closed -= OnSessionPanelClosed;
        SessionPanel.SessionCompleted -= OnSessionCompleted;
    }

    SessionPanel = panel;
    _currentUser = currentUser;

    if (SessionPanel is not null)
    {
        SessionPanel.Closed += OnSessionPanelClosed;
        SessionPanel.SessionCompleted += OnSessionCompleted;
    }
}
```

#### Benefici Attesi

- Nessun memory leak
- Handler singoli per evento
- Pattern corretto per event subscription

---

## Priorità Bassa

### GUI-006 - DatabaseSeeder hardcoda TestSheetPartNumber

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

`DatabaseSeeder` hardcoda `"OPTIMUS-XP"` come TestSheetPartNumber. Se si aggiungono altri prodotti, il seeder creerà solo device OPTIMUS XP.

#### File Coinvolti

- `GUI.Windows\DatabaseSeeder.cs` (riga 24)

#### Codice Problematico

```csharp
private const string TestSheetPartNumber = "OPTIMUS-XP";
```

#### Soluzione Proposta

Parametrizzare o caricare dinamicamente i part number disponibili.

---

### GUI-007 - LoginViewModel non de-registra LoginConfirmed

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

`LoginViewModel` espone `LoginConfirmed` come event pubblico senza modo di pulire i subscriber. Correlato a GUI-001.

#### File Coinvolti

- `GUI.Windows\ViewModels\LoginViewModel.cs` (riga 31)

#### Soluzione Proposta

Aggiungere metodo per reset:

```csharp
public void ResetSubscriptions() => LoginConfirmed = null;
```

---

### GUI-008 - Converters NotImplementedException in ConvertBack

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Tutti i converter hanno `ConvertBack` che lancia `NotImplementedException`. Se usati in TwoWay binding, l'app crasha.

#### File Coinvolti

- `GUI.Windows\Converters\*.cs` (tutti i 7 converter)

#### Codice Problematico

```csharp
public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
{
    throw new NotImplementedException();
}
```

#### Soluzione Proposta

Usare `Binding.DoNothing` o `DependencyProperty.UnsetValue`:

```csharp
public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
{
    return Binding.DoNothing;  // Ignora silenziosamente
}
```

---

### GUI-009 - Manca SettingsView (TODO in codice)

**Categoria:** Documentation  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Il metodo `NavigateToSettings()` ha un TODO e non fa nulla.

#### File Coinvolti

- `GUI.Windows\ViewModels\MainViewModel.cs` (righe 144-149)

#### Codice Problematico

```csharp
[RelayCommand]
private void NavigateToSettings()
{
    CurrentPageTitle = "Impostazioni";
    // TODO: CurrentPage = _serviceProvider.GetRequiredService<SettingsPage>();
}
```

#### Soluzione Proposta

Implementare `SettingsView` o rimuovere il pulsante dalla sidebar fino a implementazione.

---

## Priorità Alta

### GUI-010 - FirmwareUpdateViewModel upload simulato (TODO)

**Categoria:** Incomplete Feature  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Aperto  
**Data Apertura:** 2026-03-11

#### Descrizione

L'upload firmware via BLE non è implementato. Il codice attuale simula il progresso con `Task.Delay`.

#### File Coinvolti

- `GUI.Windows\ViewModels\FirmwareUpdateViewModel.cs` (righe 120-126)

#### Codice Problematico

```csharp
// 2. TODO: Upload via BLE (Fase 3)
// Per ora simuliamo il progresso
for (int i = 30; i <= 90; i += 10)
{
    await Task.Delay(200, cancellationToken);
    UpdateProgress = i;
}
```

#### Soluzione Proposta

1. Creare `IFirmwareUploader` in Infrastructure.Protocol
2. Implementare `BleFirmwareUploader` con comandi Protocol:
   - CommandId 5: START_BOOTLOADER
   - CommandId 7: UPDATE_BOOTLOADER_PAGE (loop)
   - CommandId 6: STOP_BOOTLOADER
3. Iniettare `IFirmwareUploader` in `FirmwareUpdateViewModel`

#### Note

Questa issue è documentata anche nel TODO del codice. Fase 3 del sistema firmware.

---

## Priorità Bassa

### GUI-011 - FirmwareUpdateDialog non annulla operazione in corso

**Categoria:** UX  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-11

#### Descrizione

Se l'utente chiude il dialog durante l'upload, l'operazione continua in background. Il `CancellationToken` del comando non viene cancellato dalla chiusura del dialog.

#### File Coinvolti

- `GUI.Windows\Views\FirmwareUpdateDialog.xaml.cs`
- `GUI.Windows\ViewModels\FirmwareUpdateViewModel.cs`

#### Soluzione Proposta

1. Creare un `CancellationTokenSource` nel dialog
2. Passarlo al ViewModel in `InitializeAsync` e `UpdateAsync`
3. Cancellarlo quando il dialog viene chiuso
4. Mostrare conferma se upload in corso

```csharp
private readonly CancellationTokenSource _cts = new();

protected override void OnClosing(CancelEventArgs e)
{
    if (ViewModel?.IsUpdating == true)
    {
        var result = MessageBox.Show("Upload in corso. Annullare?", ...);
        if (result == MessageBoxResult.No)
        {
            e.Cancel = true;
            return;
        }
    }
    _cts.Cancel();
    base.OnClosing(e);
}
```

---

### GUI-012 - FirmwareUpdateRequested event chain complessa

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-11

#### Descrizione

L'evento `FirmwareUpdateRequested` attraversa 4 livelli: Panel → Dashboard → View → Dialog. Questo rende difficile il debugging e aumenta l'accoppiamento.

#### File Coinvolti

- `GUI.Windows\ViewModels\AssemblySessionPanelViewModel.cs`
- `GUI.Windows\ViewModels\AssemblerDashboardViewModel.cs`
- `GUI.Windows\Views\AssemblerDashboardView.xaml.cs`
- `GUI.Windows\Views\FirmwareUpdateDialog.xaml.cs`

#### Soluzione Proposta

**Opzione A: Messaging/EventAggregator**

Usare `WeakReferenceMessenger` di CommunityToolkit.Mvvm:

```csharp
// In Panel
WeakReferenceMessenger.Default.Send(new FirmwareUpdateRequestedMessage(Device));

// In View (registrato in Loaded)
WeakReferenceMessenger.Default.Register<FirmwareUpdateRequestedMessage>(this, (r, m) => {
    ShowFirmwareDialog(m.Device);
});
```

**Opzione B: Service per dialog**

Creare `IDialogService` che apre dialog modali:

```csharp
// In Panel
await _dialogService.ShowFirmwareUpdateDialogAsync(Device);
```

#### Benefici

- Meno accoppiamento tra componenti
- Più facile testare (mock del messenger/service)
- Debugging più semplice

---

## Issue Risolte

### GUI-001 - App.xaml.cs ShowLoginView crea sottoscrizioni duplicate

**Categoria:** Bug  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** ✅ Risolto  
**Data Apertura:** 2026-03-10  
**Data Risoluzione:** 2026-03-10  
**Branch:** `fix/gui-001`

#### Descrizione

Ogni chiamata a `ShowLoginView()` crea una nuova istanza di `LoginViewModel` e si sottoscrive all'evento `LoginConfirmed` senza rimuovere le sottoscrizioni precedenti. Dopo un logout e re-login, l'evento viene invocato più volte.

#### Soluzione Implementata

1. Aggiunto metodo `ClearSubscriptions()` in `LoginViewModel.cs`:
```csharp
/// <summary>
/// Rimuove tutte le sottoscrizioni all'evento LoginConfirmed.
/// </summary>
public void ClearSubscriptions() => LoginConfirmed = null;
```

2. Chiamato in `App.xaml.cs` prima di sottoscrivere:
```csharp
loginViewModel.ClearSubscriptions();
loginViewModel.LoginConfirmed += user => mainViewModel.SetUserAndNavigate(user);
```

#### File Modificati

- `GUI.Windows\ViewModels\LoginViewModel.cs` - aggiunto `ClearSubscriptions()`
- `GUI.Windows\App.xaml.cs` - chiamata a `ClearSubscriptions()` in `ShowLoginView()`

---

## Wontfix

(Nessuna issue wontfix al momento)

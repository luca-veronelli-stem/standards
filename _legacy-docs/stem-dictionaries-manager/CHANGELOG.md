# Changelog

Tutte le modifiche rilevanti a questo progetto sono documentate in questo file.

Il formato si basa su [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
e questo progetto aderisce a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

### Legenda

- **Added**: Nuove funzionalità
- **Changed**: Modifiche a funzionalità esistenti
- **Deprecated**: Funzionalità che verranno rimosse
- **Removed**: Funzionalità rimosse
- **Fixed**: Bug corretti
- **Security**: Vulnerabilità corrette

---

## [Unreleased]

---

## [0.6.0] - 2026-04-13

API REST, DB constraints, auto-fill parametri schede, gestione errori DB.

### Added

- **Services**: `IDeviceService.GetNextAvailableMachineCodeAsync()` — calcola primo MachineCode disponibile (max+1, salta 6 riservato BLE BR-015)
- **Services**: `IBoardService.GetNextAvailableFirmwareTypeAsync()` — calcola primo FirmwareType disponibile (max globale+1)
- **GUI**: DeviceEditView pre-compila MachineCode con primo valore disponibile in creazione + nota informativa
- **GUI**: BoardEditView pre-compila FirmwareType con primo valore disponibile in creazione + nota informativa
- **GUI**: Colonna "Machine Type" nella DataGrid schede di DeviceDetailView
- **GUI**: BoardEditView mostra nome dispositivo invece di DeviceId nel campo "Dispositivo"
- **Tests**: 14 nuovi test (3 DeviceService + 2 BoardService + 4 DeviceEditViewModel + 5 BoardEditViewModel)
- **Infrastructure**: 6 DB constraints per regole di business
- **Infrastructure**: Migration `AddBusinessRuleConstraints` per Azure SQL
- **API**: Progetto ASP.NET Core Minimal API con 12 endpoint (10 business + health check + version)
- **API**: Autenticazione via API Key header `X-Api-Key` con chiavi multiple per consumer (BR-API-001)
- **API**: Endpoint variabili risolte con merge standard + specifiche + override per-dizionario (BR-API-002)
- **API**: Endpoint comandi per device con stato attivo/disattivo e default enabled (BR-API-003)
- **API**: JSON camelCase con null omessi per payload leggeri (BR-API-004)
- **API**: Board definition endpoint in formato compatibile Production.Tracker (BR-API-005)
- **API**: Health check `GET /health` con verifica connessione DB (no auth)
- **API**: Version endpoint `GET /api/version` con versione assembly e environment (no auth)
- **API**: 7 DTO record, ApiMapper, ApiKeyMiddleware
- **API**: Swagger UI in Development, file `.http` per test da Visual Studio
- **API**: Dual DB provider SQLite/SQL Server con logica centralizzata
- **API**: Deploy su Azure App Service (F1 Free, Linux, Italy North)
- **API**: 4 consumer configurati (Production.Tracker, ButtonPanel.Tester, Global Service, Stem.Device.Manager)
- **Tests**: 49 nuovi test API (13 unit ApiMapper, 8 unit ApiKeyMiddleware, 28 integration endpoint)
- **Tests**: ApiIntegrationTestBase con scenario completo (Device+Board+Standard+Override)

### Fixed

- **GUI**: Gestione errore connessione DB all'avvio — retry loop con DarkDialog Riprova/Esci invece di crash (GUI-010)
- **GUI**: DarkDialog Owner null-safe durante startup — WPF assegnava MainWindow alla prima Window istanziata, causando `Owner = self` crash
- **GUI**: Assegnamento esplicito `MainWindow` dopo creazione per evitare che un DarkDialog di startup resti come MainWindow dell'applicazione
- **API**: Endpoint restituiscono 503 Service Unavailable con JSON strutturato se DB non raggiungibile, invece di 500 con stacktrace (API-004)

### Changed

- **Core**: `Board.machineCode` reso parametro obbligatorio in constructor e `Restore` — era `= 0` (illegale per BR-014), ora il compilatore forza il chiamante a dichiarare il valore (T-005)
- **Services**: `BoardMapper.ToDomain` lancia `InvalidOperationException` se `Device` non è caricato nel query, invece di usare silenziosamente `MachineCode = 0` (T-005)
- **GUI.Windows**: `BoardEditViewModel` inietta `IDeviceService` per caricare `MachineCode` dal Device — fix bug pre-esistente dove `ProtocolAddress` veniva salvato come `0x00000000` per board create dalla GUI (T-005)
- **Infrastructure**: Centralizzata logica risoluzione connection string in `DependencyInjection.ResolveConnectionString()`
- **Infrastructure**: Centralizzato path default SQLite in `DependencyInjection.GetDefaultSqlitePath()`
- **Infrastructure**: Rimosso parametro inutilizzato `provider` da `ResolveConnectionString()`
- **GUI.Windows**: Rimosso `GetDatabasePath()` duplicato, usa metodo centralizzato di Infrastructure
- **API**: `appsettings.json` escluso dal publish (`CopyToPublishDirectory=Never`), Azure usa env var
- **API**: `DatabaseProvider` default `Sqlite` in appsettings (dev), `SqlServer` via env var (prod)
- **GUI.Windows**: `DeviceDetailViewModel` — rimossa duplicazione mappatura board con metodo `PopulateBoards`

### Removed

- **API**: Rimosso `UseHttpsRedirection()` (non necessario in dev, Azure gestisce HTTPS in prod)
- **API**: Rimosso `appsettings.Development.json` (override identico a base, nessun effetto)

---

## [0.5.0] - 2026-04-09

Prima release interna per test.

### Added

- **Core**: 10 domain models (Variable, Dictionary, Board, Device, Command, User, AuditEntry, BitInterpretation, CommandDeviceState, StandardVariableOverride) + 5 enums
- **Domain v7**: StandardVariableOverride per-dizionario, BitInterpretation.DictionaryId, eredità automatica variabili standard
- **Infrastructure**: EF Core con dual provider SQLite (dev) / Azure SQL (prod), selezionabile via `appsettings.json`
- **Infrastructure**: 10 repository con interfacce + RepositoryBase generico
- **Infrastructure**: Audit automatico CreatedAt/UpdatedAt in SaveChanges
- **Infrastructure**: Migration InitialCreate per SQL Server (Azure SQL)
- **Infrastructure**: DatabaseSeeder con 14 dizionari + Standard, 5 utenti, dati completi per tutti i device STEM
- **Services**: 7 service + 10 mapper bidirezionali Entity ↔ Domain
- **Services**: AuditService con log automatico Create/Update/Delete integrato in 5 service (16 punti)
- **Services**: ICurrentUserProvider (Singleton) per tracciare utente corrente
- **Services**: Business rules BR-001..BR-023 (unicità indirizzi, Standard unico, override coerenza, cascade delete, auto-assign FW)
- **GUI**: Applicazione WPF desktop con dark theme STEM (#004682 accent, #98D801 success, #E40032 error)
- **GUI**: 14 ViewModels + 14 Views XAML con CommunityToolkit.Mvvm
- **GUI**: LoginView integrata nella MainWindow con selezione utente
- **GUI**: NavigationService con history stack, parametri e ViewModel caching
- **GUI**: DialogService con DarkDialog custom modale
- **GUI**: MessageService con status bar globale, colori per severity e auto-hide
- **GUI**: IEditableViewModel con guard per unsaved changes su navigazione indietro
- **GUI**: DeviceListView, DeviceEditView, DeviceDetailView per CRUD dispositivi
- **GUI**: DictionaryListView, DictionaryEditView con 2 sezioni (variabili standard ereditate + specifiche)
- **GUI**: VariableEditView con supporto Bitmapped (WordGroups, WordSize 8/16/32) e modalità override standard
- **GUI**: CommandListView, CommandEditView con parametri e CodeHigh computed da IsResponse
- **GUI**: DeviceCommandsView per stato attivo/disattivo comandi per device (checkbox, salvataggio bulk)
- **GUI**: BoardEditView con FirmwareType, DictionaryId opzionale, IsPrimary
- **GUI**: Filtro `Mostra solo abilitate` per variabili specifiche e standard in DictionaryEdit
- **GUI**: Ricerca client-side case-insensitive in tutte le liste
- **GUI**: 7 converter (BoolToVisibility, InverseBool, NullToVisibility, BoolToErrorBrush, NullableInt, NullableDouble, SeverityToColor)
- **Tests**: ~1370 metodi test / ~2230 test cases (unit + integration + E2E)
- **Tests**: Multi-target net10.0 (CI/Linux) + net10.0-windows (GUI)
- **Tests**: 170 E2E test per DatabaseSeeder (verifica dati seed completi)
- **Docs**: README per ogni componente (Core, Infrastructure, Services, GUI.Windows, Tests)
- **Docs**: ISSUES_TRACKER.md con riepilogo globale e metriche qualità
- **Docs**: Schema ER database (PlantUML)
- **Docs**: Formalizzazione Lean 4 del dominio in copilot-instructions.md

### Note

- Richiede .NET 10.0 Desktop Runtime
- SQLite: il DB viene creato automaticamente all'avvio (EnsureCreated)
- Azure SQL: richiede connection string via User Secrets (`ConnectionStrings:SqlServer`)
- 14 issue bassa priorità aperte, 0 alta/media — tutte le feature pianificate per v0.5.0 completate

---

## Storico URL versioni

[Unreleased]: https://bitbucket.org/stem-fw/stem-dictionaries-manager/branches/compare/HEAD..v0.6.0
[0.6.0]: https://bitbucket.org/stem-fw/stem-dictionaries-manager/src/v0.6.0/
[0.5.0]: https://bitbucket.org/stem-fw/stem-dictionaries-manager/src/v0.5.0/

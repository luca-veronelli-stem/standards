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

---

## [0.6.0] - 2026-02-26

### Added

- **Protocol**: CancellationToken propagation su tutti i layer e interfacce (T-024)
- **Protocol.ApplicationLayer**: `IVariableMap.ReadAsync/WriteAsync` con CancellationToken (T-024)
- **Protocol.ApplicationLayer**: `ICommandHandler.HandleAsync` con CancellationToken (T-024)
- **Protocol.ApplicationLayer**: `IAckHandler.HandleAckAsync` con CancellationToken (T-024)
- **Protocol.Stack**: `ProtocolStack` Send/Receive/Initialize/Uninitialize con CancellationToken (T-024)
- **Tests**: 22 nuovi test per CancellationToken propagation

### Changed

- **Protocol**: Applicato `ConfigureAwait(false)` su tutte le chiamate async nei layer (T-019)
- **Drivers**: Applicato `ConfigureAwait(false)` su chiamate async critiche (T-019)

### Fixed

- **Protocol.NetworkLayer**: Rinominato `_shutdownCts` in `_operationsCts` per conformita CT-080
- **Protocol.ApplicationLayer**: Corretto XML doc per parametro `cancellationToken` in `IAckHandler`

---

## [0.5.4] - 2026-02-25

### Added

- **Docs**: `EVENTARGS_STANDARD.md` v1.1 - Applicazione standard EventArgs tipizzati (T-021)
- **Protocol.SessionLayer**: `SessionExpiredEventArgs` con invarianti RemoteDeviceId e Duration (T-021)
- **Protocol.SessionLayer**: `SessionHijackAttemptedEventArgs` con invarianti (T-021)
- **Protocol.TransportLayer**: `BuffersTimedOutEventArgs` con invarianti e TotalBytesLost (T-021)
- **Protocol.SessionLayer**: Aggiunto `Timestamp` a `SessionTerminatedEventArgs` (T-021)
- **Protocol.ApplicationLayer**: Aggiunto `Timestamp` a `MessageReceivedEventArgs` e `AckReceivedEventArgs` (T-021)
- **Protocol.NetworkLayer**: Aggiunto `Timestamp` a DeviceDiscovered, DeviceLost, RouteAdded, LinkQualityAlert EventArgs (T-021)
- **Drivers.Ble**: Aggiunto `Timestamp` a `BleDisconnectedEventArgs` (T-021)
- **Docs**: `API_SURFACE_TEMPLATE.md` - Template standard per documentazione API
- **Docs**: Aggiornato `API_SURFACE.md` con sezione Protocol Events (T-021)
- **Tests**: ~20 nuovi test per invarianti EventArgs e Timestamp
- **CI/CD**: Pipeline release automatizzata su merge in main
- **CI/CD**: Creazione tag automatica
- **CI/CD**: Push automatico su Azure DevOps Artifacts

### Changed

- **Directory.Build.props**: `PackageOutputPath` ora usa `./nupkg` invece di path hardcoded

---

## [0.5.3] - 2026-02-25

### Added

- **Protocol.Infrastructure**: `ConnectionState` enum (Disconnected, Connecting, Connected, Reconnecting) (STK-012)
- **Protocol.Infrastructure**: `ConnectionStateChangedEventArgs` con invarianti validati (STK-012)
- **Protocol.Infrastructure**: `IChannelDriver.ConnectionStateChanged` evento per notifiche cambio stato (STK-012) ⚠️ **BREAKING**
- **Protocol.PhysicalLayer**: Propagazione evento `ConnectionStateChanged` dal driver (STK-012)
- **Protocol.Stack**: `ProtocolStack.ConnectionStateChanged` evento pubblico (STK-012)
- **Drivers.Ble**: Eventi `ConnectionStateChanged` su connect, disconnect, auto-reconnect (STK-012)
- **Drivers.Can**: Eventi `ConnectionStateChanged` su connect, disconnect (STK-012)
- **Docs**: `EVENTARGS_STANDARD.md` v1.0 - Standard per EventArgs tipizzati (T-021)
- **Tests**: 44 nuovi test per ConnectionState, EventArgs e propagazione eventi
- **Protocol.Base**: `UninitializeAsync()` per de-inizializzazione senza dispose (T-006)
- **Protocol.Base**: `ResetStateAsync()` in tutti i 7 layer per reset stato interno (T-006)
- **Protocol.Base**: `DisposeResources()` metodo virtuale per cleanup risorse nelle subclass (T-006)
- **Docs**: `LIFECYCLE_STANDARD.md` v2.0 con regole HL-030..HL-043

### Changed

- **Protocol.Infrastructure**: `IChannelDriver` ora richiede implementazione evento `ConnectionStateChanged` (STK-012) ⚠️ **BREAKING**
- **Protocol.Base**: `IProtocolLayer` ora eredita da `IDisposable, IAsyncDisposable` (T-006) ⚠️ **BREAKING**
- **Protocol.Base**: Pattern Dispose semplificato - `DisposeCore()` ora privato (T-006)
- **Protocol.NetworkLayer**: Rimosso costruttore con DI (poco usato) (T-006) ⚠️ **BREAKING**

### Removed

- **Protocol.Base**: `Shutdown()` rimosso da `IProtocolLayer` e `ProtocolLayerBase` (T-006) ⚠️ **BREAKING**
  - Usare `DisposeAsync()` per cleanup completo
  - Usare `UninitializeAsync()` per de-init senza dispose

### Fixed

- **Issues**: BLE-020 già  implementato ma non marcato come risolto - aggiornato tracking
- **Issues**: T-006 già  implementato ma riferimento non aggiornato in Stack/ISSUES.md

---

## [0.5.2] - 2026-02-17

### Added

- **Drivers.Ble**: BLE Device Discovery API (F-001)
  - `IBleScanner`: interfaccia per scansione dispositivi BLE nelle vicinanze
  - `BleScannerFactory`: factory con selezione automatica piattaforma (Windows/Mobile)
  - `BleScanConfiguration`: configurazione scansione (timeout, filtri RSSI, filtro STEM)
  - `BleDeviceInfo`: DTO dispositivo scoperto (nome, MAC, RSSI, compatibilità  STEM)
  - `WindowsBleScanner`: implementazione Windows con `BluetoothLEAdvertisementWatcher`
  - `BleChannelDriverFactory.Create(BleDeviceInfo)`: nuovo overload per creare driver da scan result
- **Tests**: 89 nuovi test per scanner, configurazioni e factory

### Changed

- **Drivers.Ble**: Visibility cleanup secondo VISIBILITY_STANDARD v2.1
  - `WindowsBleHardware`, `WindowsBleScanner`, `PluginBleHardware` ora `internal`
  - `IBleHardware` e relativi EventArgs ora `internal`
  - `BleChannelDriver` costruttore ora `internal` (usare factory)
- **Drivers.Ble**: `BleChannelConfiguration.DeviceMacAddress` ora **required**
- **Client**: Scansione BLE integrata nel menu di selezione dispositivo

### Removed

- **Drivers.Ble**: `BleChannelConfiguration.DeviceNameFilter` (usare scan + selezione)

### Fixed

- **Client**: Bug selezione dispositivo BLE (liste separate causavano selezione errata)

---

## [0.5.1] - 2026-02-16

### Added

- **Drivers.Ble**: Supporto Windows Desktop nativo (BLE-020)
  - Nuovo target `net10.0-windows10.0.19041.0` per applicazioni WPF, WinUI 3, Console
  - `WindowsBleHardware`: implementazione `IBleHardware` con API native `Windows.Devices.Bluetooth`
  - Multi-targeting automatico: un singolo pacchetto NuGet supporta Windows Desktop + Mobile
  - `BleChannelDriverFactory` seleziona automaticamente l'hardware corretto per la piattaforma
- **Tests**: 16 nuovi test per `IBleHardware` contract e `BleChannelDriverFactory`

### Changed

- **Client**: `StemClient` usa `BleChannelDriverFactory` invece di creare hardware direttamente
- **Drivers.Ble**: Thread safety migliorata in `WindowsBleHardware` (Volatile.Read/Write per TS-003, TS-070)

### Fixed

- **Drivers.Ble**: Compilazione condizionale corretta per escludere `PluginBle` su Windows e `Windows` su mobile

## [0.5.0] - 2026-02-11 <- Prima release pubblica

### Added

- **Protocol**: Stack protocollare STEM completo a 7 layer OSI
  - Physical Layer (L1): Buffer I/O, gestione driver canale
  - DataLink Layer (L2): Framing, CRC16 Modbus, validazione integrità 
  - Network Layer (L3): Routing multi-hop, broadcast, device discovery
  - Transport Layer (L4): Chunking/riassemblaggio, PacketId rolling (1-7)
  - Session Layer (L5): Gestione sessioni, calcolo SRID, heartbeat
  - Presentation Layer (L6): Crittografia AES-128 ECB, padding PKCS7
  - Application Layer (L7): 43 comandi STEM, handler registry, variabili logiche
- **Protocol.Infrastructure**: Contratti per driver (`IChannelDriver`, `ChannelType`)
- **Protocol.Stack**: `ProtocolStackBuilder` per configurazione fluent dello stack
- **Drivers.Can**: Driver CAN per PEAK PCAN-USB con chunking NetInfo
- **Drivers.Ble**: Driver BLE cross-platform (Plugin.BLE) con MTU negotiation e auto-reconnect
- **Tests**: 2439 test (96% unit, 4% integration)

### Note

Questa è la prima release pubblica. Il progetto è una riscrittura in C#/.NET 10 
del protocollo STEM originariamente sviluppato in C, mantenendo compatibilità 
binaria con il firmware esistente.

---

## Storico URL versioni

[Unreleased]: https://bitbucket.org/stem-fw/stem-communication-protocol/branches/compare/HEAD..v0.6.0
[0.6.0]: https://bitbucket.org/stem-fw/stem-communication-protocol/src/v0.6.0/
[0.5.4]: https://bitbucket.org/stem-fw/stem-communication-protocol/src/v0.5.4/
[0.5.3]: https://bitbucket.org/stem-fw/stem-communication-protocol/src/v0.5.3/
[0.5.2]: https://bitbucket.org/stem-fw/stem-communication-protocol/src/v0.5.2/
[0.5.1]: https://bitbucket.org/stem-fw/stem-communication-protocol/src/v0.5.1/
[0.5.0]: https://bitbucket.org/stem-fw/stem-communication-protocol/src/v0.5.0/

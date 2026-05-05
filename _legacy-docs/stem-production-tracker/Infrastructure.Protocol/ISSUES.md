# Infrastructure.Protocol - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunità di refactoring e violazioni di best practice per il componente **Infrastructure.Protocol**.

> **Ultimo aggiornamento:** 2026-03-11

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 2 | 0 |
| **Media** | 2 | 0 |
| **Bassa** | 3 | 0 |

**Totale aperte:** 7  
**Totale risolte:** 0

---

## Indice Issue Aperte

- [PROT-001 - State non thread-safe in BleDeviceConnection](#prot-001--state-non-thread-safe-in-bledeviceconnection)
- [PROT-002 - SendAsync non gestisce tutti i tipi di errore](#prot-002--sendasync-non-gestisce-tutti-i-tipi-di-errore)
- [PROT-003 - ConnectionConfiguration non valida MacAddress](#prot-003--connectionconfiguration-non-valida-macaddress)
- [PROT-004 - Singleton IDeviceConnection può causare problemi in test](#prot-004--singleton-ideviceconnection-può-causare-problemi-in-test)
- [PROT-005 - Magic numbers per LocalDeviceId e DestinationId](#prot-005--magic-numbers-per-localdeviceid-e-destinationid)
- [PROT-006 - BleDeviceDiscovery DeviceDiscovered può causare memory leak](#prot-006--bledevicediscovery-devicediscovered-può-causare-memory-leak)
- [PROT-007 - Manca IFirmwareUploader per upload via BLE (TODO)](#prot-007--manca-ifirmwareuploader-per-upload-via-ble-todo)

---

## Indice Issue Risolte

(Nessuna issue risolta)

---

## Priorità Alta

### PROT-001 - State non thread-safe in BleDeviceConnection

**Categoria:** Bug  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

La proprietà `State` viene letta e scritta da thread diversi senza sincronizzazione corretta. L'event handler `OnStackConnectionStateChanged` scrive `State` fuori dal lock, mentre `GetConnectedStack()` la legge dentro un lock. Questo può causare:
- Race condition tra lettura e scrittura
- Valori stale su CPU multi-core (visibility issue)

#### File Coinvolti

- `Infrastructure.Protocol\Services\BleDeviceConnection.cs` (righe 19, 128-132, 116-126)

#### Codice Problematico

```csharp
// Riga 19 - Proprietà auto-implementata, nessuna sincronizzazione
public ConnectionState State { get; private set; } = ConnectionState.Disconnected;

// Righe 128-132 - Scrittura fuori dal lock!
private void OnStackConnectionStateChanged(object? sender, ConnectionStateChangedEventArgs e)
{
    State = e.CurrentState;  // <-- Race condition!
    StateChanged?.Invoke(this, e);
}

// Righe 116-126 - Lettura dentro il lock
private ProtocolStack GetConnectedStack()
{
    lock (_lock)
    {
        if (_stack is null || State != ConnectionState.Connected)  // <-- Legge State
            throw new InvalidOperationException(...);
        return _stack;
    }
}
```

#### Problema Specifico

Scenario problematico:
1. Thread A chiama `GetConnectedStack()`, entra nel lock, legge `State == Connected`
2. Thread B (callback BLE) esegue `OnStackConnectionStateChanged`, imposta `State = Disconnecting`
3. Thread A esce dal lock e usa lo stack, che potrebbe essere in fase di disconnessione

#### Soluzione Proposta

**Opzione A: Usare Volatile.Read/Write**

```csharp
private ConnectionState _state = ConnectionState.Disconnected;

public ConnectionState State
{
    get => Volatile.Read(ref _state);
    private set => Volatile.Write(ref _state, value);
}
```

**Opzione B: Sincronizzare tutto nel lock**

```csharp
private void OnStackConnectionStateChanged(object? sender, ConnectionStateChangedEventArgs e)
{
    lock (_lock)
    {
        State = e.CurrentState;
    }
    StateChanged?.Invoke(this, e);  // Fuori dal lock per evitare deadlock
}
```

**Opzione C (Raccomandato): Combinare entrambi**

```csharp
private ConnectionState _state = ConnectionState.Disconnected;

public ConnectionState State => Volatile.Read(ref _state);

private void OnStackConnectionStateChanged(object? sender, ConnectionStateChangedEventArgs e)
{
    Volatile.Write(ref _state, e.CurrentState);
    StateChanged?.Invoke(this, e);
}

private ProtocolStack GetConnectedStack()
{
    lock (_lock)
    {
        var currentState = Volatile.Read(ref _state);
        if (_stack is null || currentState != ConnectionState.Connected)
            throw new InvalidOperationException(
                $"Cannot perform operation: not connected (state: {currentState})");
        return _stack;
    }
}
```

#### Benefici Attesi

- Thread-safety garantita
- Nessun race condition
- Letture sempre consistenti

---

## Priorità Media

### PROT-002 - SendAsync non gestisce tutti i tipi di errore

**Categoria:** Bug  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

`SendAsync` lancia una generica `InvalidOperationException("Send failed")` senza propagare informazioni sull'errore dal `SendResult`. Il chiamante non può distinguere tra errori di rete, timeout, buffer pieno, ecc.

#### File Coinvolti

- `Infrastructure.Protocol\Services\BleDeviceConnection.cs` (righe 88-96)

#### Codice Problematico

```csharp
public async Task SendAsync(byte[] data, uint destinationId = 0x1FFFFFFF, CancellationToken ct = default)
{
    var stack = GetConnectedStack();
    var result = await stack.SendAsync(data, destinationId, ct);

    if (!result.IsSuccess)
        throw new InvalidOperationException("Send failed");  // <-- Nessun dettaglio!
}
```

#### Soluzione Proposta

```csharp
public async Task SendAsync(byte[] data, uint destinationId = 0x1FFFFFFF, CancellationToken ct = default)
{
    var stack = GetConnectedStack();
    var result = await stack.SendAsync(data, destinationId, ct);

    if (!result.IsSuccess)
    {
        // Propaga errore con dettagli
        throw new InvalidOperationException(
            $"Send failed: {result.ErrorCode} - {result.ErrorMessage}");
    }
}
```

**Oppure creare eccezione custom:**

```csharp
public class ProtocolSendException : Exception
{
    public int ErrorCode { get; }

    public ProtocolSendException(int errorCode, string message) 
        : base(message)
    {
        ErrorCode = errorCode;
    }
}
```

#### Benefici Attesi

- Errori più informativi
- Possibilità di gestire errori specifici nel chiamante
- Debug più facile

---

### PROT-003 - ConnectionConfiguration non valida MacAddress

**Categoria:** Bug  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

`ConnectionConfiguration.MacAddress` è `required` ma non ha validazione di formato. Valori invalidi come `"abc"` o stringhe vuote vengono accettati e causano errori più avanti nel driver BLE.

#### File Coinvolti

- `Infrastructure.Protocol\Interfaces\IDeviceConnection.cs` (righe 8-21)

#### Codice Problematico

```csharp
public sealed class ConnectionConfiguration
{
    /// <summary>Indirizzo MAC del dispositivo (obbligatorio)</summary>
    public required string MacAddress { get; init; }  // Nessuna validazione!

    // ...
}
```

#### Soluzione Proposta

**Opzione A: Init-only validation (raccomandato)**

```csharp
public sealed class ConnectionConfiguration
{
    private readonly string _macAddress = null!;

    public required string MacAddress
    {
        get => _macAddress;
        init
        {
            if (string.IsNullOrWhiteSpace(value))
                throw new ArgumentException("MAC address cannot be empty", nameof(MacAddress));

            // Validazione formato (come CORE-002)
            var normalized = value.Trim().ToUpperInvariant().Replace('-', ':');
            if (!MacAddressRegex.IsMatch(normalized))
                throw new ArgumentException(
                    $"Invalid MAC address format: '{value}'. Expected format: XX:XX:XX:XX:XX:XX",
                    nameof(MacAddress));

            _macAddress = normalized;
        }
    }

    private static readonly Regex MacAddressRegex = new(
        @"^([0-9A-F]{2}:){5}[0-9A-F]{2}$",
        RegexOptions.Compiled);

    // ...
}
```

#### Nota

Questa issue è correlata a **CORE-002** (manca validazione MAC in Device).

#### Benefici Attesi

- Fail-fast su input invalidi
- Errori chiari per l'utente
- MAC address normalizzato

---

## Priorità Bassa

### PROT-004 - Singleton IDeviceConnection può causare problemi in test

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

`IDeviceConnection` è registrato come **Singleton** nel DI container. Questo può causare problemi:
- Stato condiviso tra test
- Difficoltà nel moccare per test isolati
- Un solo device connesso per tutta l'applicazione

#### File Coinvolti

- `Infrastructure.Protocol\DependencyInjection.cs` (riga 19)

#### Codice Problematico

```csharp
services.AddSingleton<IDeviceConnection, BleDeviceConnection>();
```

#### Soluzione Proposta

Il Singleton è probabilmente intenzionale (una sola connessione BLE alla volta). Tuttavia:

**Per i test:** Usare `NSubstitute` per moccare `IDeviceConnection`.

**Per flessibilità futura:** Considerare Scoped o factory pattern:

```csharp
// Factory per creare connessioni on-demand
services.AddSingleton<IDeviceConnectionFactory, BleDeviceConnectionFactory>();

public interface IDeviceConnectionFactory
{
    IDeviceConnection Create();
}
```

#### Benefici Attesi

- Test più isolati
- Possibilità di connessioni multiple in futuro (se necessario)
- Pattern più flessibile

---

### PROT-005 - Magic numbers per LocalDeviceId e DestinationId

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

I valori `0x00030141` (LocalDeviceId) e `0x1FFFFFFF` (DestinationId broadcast) sono hardcoded senza costanti documentate.

#### File Coinvolti

- `Infrastructure.Protocol\Interfaces\IDeviceConnection.cs` (righe 14, 67)
- `Infrastructure.Protocol\Services\BleDeviceConnection.cs` (riga 89)

#### Codice Problematico

```csharp
// In ConnectionConfiguration
public uint LocalDeviceId { get; init; } = 0x00030141;  // Magic number

// In IDeviceConnection.SendAsync
Task SendAsync(byte[] data, uint destinationId = 0x1FFFFFFF, ...);  // Magic number
```

#### Soluzione Proposta

```csharp
/// <summary>Costanti per ID dispositivo nel protocollo STEM.</summary>
public static class StemProtocolConstants
{
    /// <summary>
    /// ID dispositivo locale di default per l'applicazione tracker.
    /// Formato: 0x0003 (gruppo) + 0x0141 (ID specifico)
    /// </summary>
    public const uint DefaultLocalDeviceId = 0x00030141;

    /// <summary>
    /// ID broadcast per inviare a tutti i dispositivi.
    /// Tutti i bit a 1 nel campo RecipientId (29 bit).
    /// </summary>
    public const uint BroadcastDestinationId = 0x1FFFFFFF;
}
```

Poi usare:

```csharp
public uint LocalDeviceId { get; init; } = StemProtocolConstants.DefaultLocalDeviceId;
```

#### Benefici Attesi

- Codice auto-documentante
- Singolo punto di modifica
- Documentazione degli ID nel codice

---

### PROT-006 - BleDeviceDiscovery DeviceDiscovered può causare memory leak

**Categoria:** Resource Management  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

L'evento `DeviceDiscovered` di `BleDeviceDiscovery` può causare memory leak se i subscriber non si de-registrano. Essendo `IDeviceDiscovery` registrato come **Transient**, ogni istanza ha il proprio event e viene garbage-collected, ma il problema si verifica se il subscriber mantiene un riferimento.

#### File Coinvolti

- `Infrastructure.Protocol\Services\BleDeviceDiscovery.cs` (riga 14)
- `Infrastructure.Protocol\Interfaces\IDeviceDiscovery.cs` (riga 29)

#### Codice Problematico

```csharp
public event EventHandler<DiscoveredDevice>? DeviceDiscovered;
```

L'evento è esposto pubblicamente. Se un ViewModel si sottoscrive e non si de-registra, mantiene in vita il `BleDeviceDiscovery`.

#### Soluzione Proposta

**Opzione A: Documentare nel XML comment**

```csharp
/// <summary>
/// Evento sollevato quando viene scoperto un nuovo dispositivo durante la scansione.
/// IMPORTANTE: De-registrarsi sempre quando non più necessario per evitare memory leak.
/// </summary>
event EventHandler<DiscoveredDevice>? DeviceDiscovered;
```

**Opzione B: Weak event pattern (più complesso)**

```csharp
// Usare WeakEventManager di WPF o implementazione custom
```

**Opzione C: IDisposable (raccomandato per semplicità)**

```csharp
public sealed class BleDeviceDiscovery : IDeviceDiscovery, IDisposable
{
    public void Dispose()
    {
        DeviceDiscovered = null;  // Rimuove tutti i subscriber
    }
}
```

#### Benefici Attesi

- Prevenzione memory leak
- Pattern chiaro per la gestione dell'evento
- Documentazione del comportamento atteso

---

### PROT-007 - Manca IFirmwareUploader per upload via BLE (TODO)

**Categoria:** Feature Mancante  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Aperto  
**Data Apertura:** 2026-03-11

#### Descrizione

Non esiste un servizio per caricare firmware sui dispositivi via BLE. L'UI attualmente simula l'upload con `Task.Delay`.

#### Dipendenze

- Correlato a **GUI-010** (FirmwareUpdateViewModel upload simulato)

#### Soluzione Proposta

1. Creare interfaccia `IFirmwareUploader`:

```csharp
public interface IFirmwareUploader
{
    /// <summary>
    /// Carica firmware sul device connesso.
    /// </summary>
    /// <param name="firmwareData">Bytes del firmware</param>
    /// <param name="progress">Progress reporter (0-100)</param>
    /// <param name="cancellationToken">Token per annullare</param>
    Task UploadAsync(
        byte[] firmwareData,
        IProgress<int>? progress = null,
        CancellationToken cancellationToken = default);
}
```

2. Implementare `BleFirmwareUploader` che usa `IDeviceConnection`:

```csharp
public sealed class BleFirmwareUploader : IFirmwareUploader
{
    private readonly IDeviceConnection _connection;

    public async Task UploadAsync(byte[] firmwareData, IProgress<int>? progress, CancellationToken ct)
    {
        // 1. START_BOOTLOADER (CommandId 5)
        await SendCommandAsync(5, ct);
        progress?.Report(10);

        // 2. UPDATE_BOOTLOADER_PAGE (CommandId 7) in loop
        var pageSize = 256;  // o altro valore specifico device
        var totalPages = (firmwareData.Length + pageSize - 1) / pageSize;

        for (int i = 0; i < totalPages; i++)
        {
            var pageData = firmwareData.Skip(i * pageSize).Take(pageSize).ToArray();
            await SendPageAsync(7, i, pageData, ct);

            var uploadProgress = 10 + (80 * i / totalPages);
            progress?.Report(uploadProgress);
        }

        // 3. STOP_BOOTLOADER (CommandId 6)
        await SendCommandAsync(6, ct);
        progress?.Report(100);
    }
}
```

3. Registrare in DI:

```csharp
services.AddTransient<IFirmwareUploader, BleFirmwareUploader>();
```

#### Note

- Richiede documentazione da FW team su formato esatto payload
- Dimensione pagina varia per device (verificare con FW)
- Potrebbe servire verifica CRC dopo upload

---

## Issue Risolte

(Nessuna issue risolta al momento)

---

## Wontfix

(Nessuna issue wontfix al momento)

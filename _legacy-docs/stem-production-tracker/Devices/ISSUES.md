# Devices - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunità di refactoring e violazioni di best practice per il componente **Devices**.

> **Ultimo aggiornamento:** 2026-03-10

> ⚠️ **NOTA:** Questo progetto è **incompleto**. Solo OPTIMUS XP è implementato. EDEN BS8, EDEN XP e R3L XP sono pianificati ma non ancora sviluppati.

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 0 | 0 |
| **Media** | 2 | 0 |
| **Bassa** | 3 | 0 |

**Totale aperte:** 5  
**Totale risolte:** 0

---

## Indice Issue Aperte

- [DEV-001 - Manca interfaccia IDevicePlugin per polimorfismo](#dev-001--manca-interfaccia-ideviceplugin-per-polimorfismo)
- [DEV-002 - OptimusXpPlugin non thread-safe nella cache _definition](#dev-002--optimusxpplugin-non-thread-safe-nella-cache-_definition)
- [DEV-003 - BaseVariableMapBuilder.ParseDataType case-sensitivity inconsistente](#dev-003--basevariablemapbuilderparsedatatype-case-sensitivity-inconsistente)
- [DEV-004 - Singleton OptimusXpPlugin potrebbe non essere appropriato](#dev-004--singleton-optimusxpplugin-potrebbe-non-essere-appropriato)
- [DEV-005 - Manca documentazione struttura plugin per nuovi device](#dev-005--manca-documentazione-struttura-plugin-per-nuovi-device)

---

## Indice Issue Risolte

(Nessuna issue risolta)

---

## Priorità Media

### DEV-001 - Manca interfaccia IDevicePlugin per polimorfismo

**Categoria:** Design  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Non esiste un'interfaccia comune `IDevicePlugin` che definisca il contratto per tutti i plugin device. Questo rende difficile:
- Gestire plugin in modo polimorfico
- Factory pattern per creare plugin dinamicamente
- Testing con mock di plugin

#### File Coinvolti

- `Devices\OptimusXp\OptimusXpPlugin.cs` (intera classe)
- `Devices\DependencyInjection.cs` (registrazione)

#### Problema Specifico

Quando si aggiungeranno altri plugin (EdenBs8, EdenXp, R3lXp), ogni chiamante dovrà conoscere il tipo concreto:

```csharp
// Attualmente - dipendenza da tipo concreto
var plugin = serviceProvider.GetRequiredService<OptimusXpPlugin>();

// Futuro problema - come scegliere il plugin giusto?
// if (deviceType == "OptimusXp") get OptimusXpPlugin
// else if (deviceType == "EdenBs8") get EdenBs8Plugin  // Non c'è polimorfismo!
```

#### Soluzione Proposta

**Creare interfaccia comune:**

```csharp
// Devices/Interfaces/IDevicePlugin.cs
public interface IDevicePlugin
{
    /// <summary>Tipo device supportato (es. "OptimusXp")</summary>
    string DeviceType { get; }

    /// <summary>Carica la definizione del device</summary>
    Task<DeviceDefinitionDto> GetDefinitionAsync(CancellationToken ct = default);

    /// <summary>Registra le variabili nella mappa</summary>
    Task<int> RegisterVariablesAsync(IVariableMap map, CancellationToken ct = default);

    /// <summary>Ottiene l'indirizzo scheda</summary>
    Task<uint> GetBoardAddressAsync(CancellationToken ct = default);
}
```

**Factory per selezione plugin:**

```csharp
public interface IDevicePluginFactory
{
    IDevicePlugin GetPlugin(string deviceType);
    IEnumerable<string> GetSupportedDeviceTypes();
}
```

#### Benefici Attesi

- Polimorfismo per gestire tutti i plugin uniformemente
- Factory pattern per selezione dinamica
- Testabilità migliorata
- Preparazione per nuovi plugin

---

### DEV-002 - OptimusXpPlugin non thread-safe nella cache _definition

**Categoria:** Bug  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Il campo `_definition` viene usato come cache lazy ma non è thread-safe. Se due thread chiamano `GetDefinitionAsync()` contemporaneamente, potrebbero entrambi caricare la definizione.

#### File Coinvolti

- `Devices\OptimusXp\OptimusXpPlugin.cs` (righe 16, 25-29)

#### Codice Problematico

```csharp
private DeviceDefinitionDto? _definition;  // Non thread-safe

public async Task<DeviceDefinitionDto> GetDefinitionAsync(CancellationToken cancellationToken = default)
{
    _definition ??= await _definitionProvider.GetDefinitionAsync(DeviceType, cancellationToken);
    return _definition;
}
```

Il null-coalescing assignment (`??=`) non è atomico per operazioni async.

#### Soluzione Proposta

**Opzione A: Lazy<Task<T>> (raccomandato)**

```csharp
private readonly Lazy<Task<DeviceDefinitionDto>> _definitionLazy;

public OptimusXpPlugin(IDeviceDefinitionProvider definitionProvider)
{
    _definitionProvider = definitionProvider;
    _definitionLazy = new Lazy<Task<DeviceDefinitionDto>>(
        () => _definitionProvider.GetDefinitionAsync(DeviceType));
}

public Task<DeviceDefinitionDto> GetDefinitionAsync(CancellationToken cancellationToken = default)
{
    // Nota: CancellationToken ignorato per la cache, ma OK per singleton
    return _definitionLazy.Value;
}
```

**Opzione B: SemaphoreSlim**

```csharp
private readonly SemaphoreSlim _loadLock = new(1, 1);
private DeviceDefinitionDto? _definition;

public async Task<DeviceDefinitionDto> GetDefinitionAsync(CancellationToken ct = default)
{
    if (_definition is not null)
        return _definition;

    await _loadLock.WaitAsync(ct);
    try
    {
        _definition ??= await _definitionProvider.GetDefinitionAsync(DeviceType, ct);
        return _definition;
    }
    finally
    {
        _loadLock.Release();
    }
}
```

#### Benefici Attesi

- Thread-safety garantita
- Singolo caricamento anche con chiamate concorrenti
- Pattern standard per lazy async initialization

---

## Priorità Bassa

### DEV-003 - BaseVariableMapBuilder.ParseDataType case-sensitivity inconsistente

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

`ParseDataType()` converte in `ToUpperInvariant()` prima del match, ma `IsReadOnly()` fa lo stesso separatamente. I file JSON potrebbero usare case diversi e la documentazione non specifica il formato atteso.

#### File Coinvolti

- `Devices\Common\BaseVariableMapBuilder.cs` (righe 37-51, 58-67)

#### Codice Problematico

```csharp
// Entrambi convertono in uppercase internamente
public static VariableDataType ParseDataType(string dataType)
{
    return dataType.ToUpperInvariant() switch { ... };
}

public static bool IsReadOnly(string access)
{
    return access.ToUpperInvariant() switch { ... };
}
```

#### Soluzione Proposta

Documentare nel JSON schema il formato atteso, oppure normalizzare una volta sola:

```csharp
/// <summary>Normalizza il valore per confronto case-insensitive</summary>
private static string Normalize(string value) => value.Trim().ToUpperInvariant();
```

#### Benefici Attesi

- Documentazione chiara del formato JSON
- Singolo punto di normalizzazione
- Meno duplicazione

---

### DEV-004 - Singleton OptimusXpPlugin potrebbe non essere appropriato

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

`OptimusXpPlugin` è registrato come **Singleton**, ma dipende da `IDeviceDefinitionProvider`. Se il provider viene aggiornato (es. reload JSON), il plugin manterrà la cache vecchia.

#### File Coinvolti

- `Devices\DependencyInjection.cs` (riga 33)

#### Codice Problematico

```csharp
services.AddSingleton<OptimusXpPlugin>();
```

#### Soluzione Proposta

**Opzione A: Scoped (per request/operazione)**

```csharp
services.AddScoped<OptimusXpPlugin>();
```

**Opzione B: Mantenere Singleton con metodo ClearCache()**

```csharp
public void ClearCache() => _definition = null;
```

**Nota:** Il Singleton è probabilmente OK perché le definizioni device non cambiano a runtime in produzione. Questa issue è più una nota di design.

#### Benefici Attesi

- Chiarezza sulla scelta del lifetime
- Possibilità di invalidare cache se necessario

---

### DEV-005 - Manca documentazione struttura plugin per nuovi device

**Categoria:** Documentation  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Il progetto Devices non ha documentazione su come creare un nuovo plugin. Quando si implementerà EDEN BS8, bisognerà capire il pattern guardando OptimusXpPlugin.

#### File Coinvolti

- `Devices\README.md` (già esistente, ma manca template)

#### Soluzione Proposta

**Aggiungere sezione "Creare un nuovo plugin" nel README:**

```markdown
## Creare un nuovo plugin

1. Creare cartella `Devices/{DeviceName}/`
2. Creare `{DeviceName}Plugin.cs` seguendo il pattern di `OptimusXpPlugin`
3. Creare JSON definition in `Infrastructure.Persistence/DeviceDefinitions/Data/devices/{device-name}.json`
4. Aggiungere metodo `Add{DeviceName}()` in `DependencyInjection.cs`
5. Registrare in `AddDevices()`

### Template plugin

```csharp
public sealed class {DeviceName}Plugin(IDeviceDefinitionProvider definitionProvider)
{
    public const string DeviceType = "{DeviceName}";
    // ... copiare da OptimusXpPlugin
}
```
```

#### Benefici Attesi

- Onboarding più facile per nuovi sviluppatori
- Pattern consistente tra plugin
- Meno tempo per implementare nuovi device

---

## Issue Risolte

(Nessuna issue risolta al momento)

---

## Wontfix

(Nessuna issue wontfix al momento)

---

## Note Progettuali

### Plugin pianificati (non ancora implementati)

| Device | Status | Note |
|--------|--------|------|
| **OPTIMUS XP** | ✅ Implementato | Plugin completo, JSON definition presente |
| **EDEN BS8** | 🔲 Pianificato | Primo target dopo OPTIMUS XP |
| **EDEN XP** | 🔲 Pianificato | Simile a EDEN BS8 |
| **R3L XP** | 🔲 Pianificato | Ha device secondario (Sherpa) |

### Architettura target

```
Devices/
├── Common/
│   └── BaseVariableMapBuilder.cs    # Logica condivisa
├── Interfaces/                       # DA CREARE
│   └── IDevicePlugin.cs             # Interfaccia comune
├── OptimusXp/
│   └── OptimusXpPlugin.cs           # ✅ Implementato
├── EdenBs8/                          # DA CREARE
│   └── EdenBs8Plugin.cs
├── EdenXp/                           # DA CREARE
│   └── EdenXpPlugin.cs
└── R3lXp/                            # DA CREARE
    └── R3lXpPlugin.cs
```

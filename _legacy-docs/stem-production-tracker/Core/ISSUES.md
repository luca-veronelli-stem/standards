# Core - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunità di refactoring e violazioni di best practice per il componente **Core**.

> **Ultimo aggiornamento:** 2026-03-10

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 0 | 0 |
| **Media** | 5 | 0 |
| **Bassa** | 6 | 0 |

**Totale aperte:** 11  
**Totale risolte:** 0

---

## Indice Issue Aperte

- [CORE-001 - Duplicazione Logica GetStatus tra WorkOrder e Phase](#core-001--duplicazione-logica-getstatus-tra-workorder-e-phase)
- [CORE-002 - Manca Validazione Formato MAC Address](#core-002--manca-validazione-formato-mac-address)
- [CORE-003 - Manca Validazione PhaseNumber multiplo di 10](#core-003--manca-validazione-phasenumber-multiplo-di-10)
- [CORE-004 - User non è sealed](#core-004--user-non-è-sealed)
- [CORE-005 - Manca IEquatable su FunctionalGroup e FunctionalGroupTemplate](#core-005--manca-iequatable-su-functionalgroup-e-functionalgrouptemplate)
- [CORE-006 - TestSheet.AddCheck inefficiente con Sort ad ogni aggiunta](#core-006--testsheetaddcheck-inefficiente-con-sort-ad-ogni-aggiunta)
- [CORE-007 - Mancano costanti per Magic Numbers](#core-007--mancano-costanti-per-magic-numbers)
- [CORE-008 - Manca IEquatable su AssemblySession, TestSession, Phase](#core-008--manca-iequatable-su-assemblysession-testsession-phase)
- [CORE-009 - TestSheet viola SRP (schema + builder)](#core-009--testsheet-viola-srp-schema--builder)
- [CORE-010 - CheckExecution senza Id (non aggiornabile)](#core-010--checkexecution-senza-id-non-aggiornabile)
- [CORE-011 - Pattern Restore() verboso (KISS)](#core-011--pattern-restore-verboso-kiss)

---

## Indice Issue Risolte

(Nessuna issue risolta)

---

## Priorità Media

### CORE-001 - Duplicazione Logica GetStatus tra WorkOrder e Phase

**Categoria:** Code Smell  
**Priorità:** Media  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

I metodi `WorkOrder.GetStatus()` e `Phase.GetStatus()` hanno logica identica per calcolare `ProgressStatus` dai device. Questo viola il principio DRY (Don't Repeat Yourself).

#### File Coinvolti

- `Core\Models\WorkOrder.cs` (righe 52-66)
- `Core\Models\Phase.cs` (righe 56-70)

#### Codice Problematico

```csharp
// WorkOrder.cs riga 52-66
public static ProgressStatus GetStatus(IEnumerable<Device> devices)
{
    var deviceList = devices.ToList();

    if (deviceList.Count == 0)
        return ProgressStatus.New;

    if (deviceList.All(d => d.Status == DeviceStatus.Completed))
        return ProgressStatus.Completed;

    if (deviceList.All(d => d.Status == DeviceStatus.Ordered))
        return ProgressStatus.New;

    return ProgressStatus.InProcess;
}

// Phase.cs - Identico
public static ProgressStatus GetStatus(IEnumerable<Device> phaseDevices)
{
    // ... logica identica
}
```

#### Soluzione Proposta

**Opzione A: Extension method condiviso**

```csharp
// In DeviceExtensions.cs o ProgressStatusExtensions.cs
public static class DeviceCollectionExtensions
{
    public static ProgressStatus GetProgressStatus(this IEnumerable<Device> devices)
    {
        var deviceList = devices.ToList();

        if (deviceList.Count == 0)
            return ProgressStatus.New;

        if (deviceList.All(d => d.Status == DeviceStatus.Completed))
            return ProgressStatus.Completed;

        if (deviceList.All(d => d.Status == DeviceStatus.Ordered))
            return ProgressStatus.New;

        return ProgressStatus.InProcess;
    }
}

// Utilizzo in WorkOrder/Phase
public static ProgressStatus GetStatus(IEnumerable<Device> devices) 
    => devices.GetProgressStatus();
```

#### Benefici Attesi

- Singola implementazione della logica
- Manutenibilità migliorata
- Coerenza garantita tra WorkOrder e Phase

---

### CORE-002 - Manca Validazione Formato MAC Address

**Categoria:** Bug  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Il metodo `Device.SetBleMacAddress()` non valida il formato del MAC address. Accetta qualsiasi stringa non vuota, inclusi valori invalidi come "abc" o "12345".

#### File Coinvolti

- `Core\Models\Device.cs` (righe 96-103)

#### Codice Problematico

```csharp
// riga 96-103
public void SetBleMacAddress(string macAddress)
{
    if (string.IsNullOrWhiteSpace(macAddress))
        throw new ArgumentException("MAC address cannot be empty", nameof(macAddress));

    BleMacAddress = macAddress.Trim().ToUpperInvariant();
}
```

#### Soluzione Proposta

```csharp
private static readonly Regex MacAddressRegex = new(
    @"^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$",
    RegexOptions.Compiled);

public void SetBleMacAddress(string macAddress)
{
    if (string.IsNullOrWhiteSpace(macAddress))
        throw new ArgumentException("MAC address cannot be empty", nameof(macAddress));

    var normalized = macAddress.Trim().ToUpperInvariant().Replace('-', ':');
    
    if (!MacAddressRegex.IsMatch(normalized))
        throw new ArgumentException(
            $"Invalid MAC address format: '{macAddress}'. Expected format: XX:XX:XX:XX:XX:XX",
            nameof(macAddress));

    BleMacAddress = normalized;
}
```

#### Benefici Attesi

- Fail-fast su input malformati
- Consistenza formato (sempre `XX:XX:XX:XX:XX:XX`)
- Errori chiari per l'utente

---

### CORE-006 - TestSheet.AddCheck inefficiente con Sort ad ogni aggiunta

**Categoria:** Performance  
**Priorità:** Media  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Il metodo `TestSheet.AddCheck()` esegue un `Sort()` della lista completa ad ogni aggiunta. Con N check, la complessità diventa O(N² log N) invece di O(N log N).

#### File Coinvolti

- `Core\Models\TestSheet.cs` (righe 60-66)

#### Codice Problematico

```csharp
// riga 60-66
public void AddCheck(CheckDefinition check)
{
    ArgumentNullException.ThrowIfNull(check);
    _checks.Add(check);
    _checks.Sort((a, b) => a.Id.CompareTo(b.Id));  // O(N log N) ogni volta!
}
```

#### Soluzione Proposta

**Opzione A: Binary search insert (mantiene ordine)**

```csharp
public void AddCheck(CheckDefinition check)
{
    ArgumentNullException.ThrowIfNull(check);
    
    // Binary search per trovare la posizione corretta
    var index = _checks.BinarySearch(check, Comparer<CheckDefinition>.Create(
        (a, b) => a.Id.CompareTo(b.Id)));
    
    if (index < 0) index = ~index;
    
    _checks.Insert(index, check);  // O(N) insert, ma O(log N) search
}
```

**Opzione B: Lazy sort (ordina solo quando serve)**

```csharp
private bool _checksSorted = true;

public void AddCheck(CheckDefinition check)
{
    ArgumentNullException.ThrowIfNull(check);
    _checks.Add(check);
    _checksSorted = false;
}

public IReadOnlyList<CheckDefinition> Checks
{
    get
    {
        if (!_checksSorted)
        {
            _checks.Sort((a, b) => a.Id.CompareTo(b.Id));
            _checksSorted = true;
        }
        return _checks;
    }
}
```

#### Benefici Attesi

- Riduzione complessità da O(N² log N) a O(N log N)
- Migliore performance per schede con molti check
- Pattern più efficiente per bulk loading

---

## Priorità Bassa

### CORE-003 - Manca Validazione PhaseNumber multiplo di 10

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Secondo la specifica Lean 4, i numeri di fase devono essere multipli di 10 (/10, /20, /30...). Il costruttore di `Phase` valida solo che sia positivo, non che sia multiplo di 10.

#### File Coinvolti

- `Core\Models\Phase.cs` (righe 27-38)

#### Codice Problematico

```csharp
// riga 30-31
if (phaseNumber <= 0)
    throw new ArgumentException("Phase number must be positive", nameof(phaseNumber));
```

#### Soluzione Proposta

```csharp
if (phaseNumber <= 0)
    throw new ArgumentException("Phase number must be positive", nameof(phaseNumber));

// Validazione multiplo di 10 (opzionale - warning invece di errore)
if (phaseNumber % 10 != 0)
    // Log warning? O throw?
    throw new ArgumentException(
        $"Phase number should be a multiple of 10 (got {phaseNumber})",
        nameof(phaseNumber));
```

**Nota:** Potrebbe essere un warning invece di un errore per retrocompatibilità.

#### Benefici Attesi

- Conformità alla specifica formale
- Prevenzione errori di inserimento dati

---

### CORE-004 - User non è sealed

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

La classe `User` non è dichiarata `sealed`, a differenza di tutti gli altri modelli del dominio (WorkOrder, Phase, Device, etc.). Questo potrebbe permettere ereditarietà non intenzionale.

#### File Coinvolti

- `Core\Models\User.cs` (riga 8)

#### Codice Problematico

```csharp
// riga 8
public class User  // <-- Manca 'sealed'
{
```

#### Soluzione Proposta

```csharp
public sealed class User
{
```

#### Benefici Attesi

- Consistenza con gli altri modelli
- Prevenzione ereditarietà accidentale
- Possibili ottimizzazioni JIT

---

### CORE-005 - Manca IEquatable su FunctionalGroup e FunctionalGroupTemplate

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Le classi `FunctionalGroup` e `FunctionalGroupTemplate` non implementano `IEquatable<T>`, a differenza di WorkOrder, Phase e Device. Questo rende inconsistente il confronto e potrebbe causare comportamenti inattesi in collezioni.

#### File Coinvolti

- `Core\Models\FunctionalGroup.cs`
- `Core\Models\FunctionalGroupTemplate.cs`

#### Soluzione Proposta

```csharp
// FunctionalGroup.cs
public sealed class FunctionalGroup : IEquatable<FunctionalGroup>
{
    // ... proprietà esistenti ...

    public bool Equals(FunctionalGroup? other)
    {
        if (other is null) return false;
        return PartNumber == other.PartNumber && SerialNumber == other.SerialNumber;
    }

    public override bool Equals(object? obj) => Equals(obj as FunctionalGroup);

    public override int GetHashCode() => HashCode.Combine(PartNumber, SerialNumber);
}

// FunctionalGroupTemplate.cs
public sealed class FunctionalGroupTemplate : IEquatable<FunctionalGroupTemplate>
{
    // ... proprietà esistenti ...

    public bool Equals(FunctionalGroupTemplate? other)
    {
        if (other is null) return false;
        return PartNumber == other.PartNumber;
    }

    public override bool Equals(object? obj) => Equals(obj as FunctionalGroupTemplate);

    public override int GetHashCode() => PartNumber.GetHashCode();
}
```

#### Benefici Attesi

- Consistenza con altri modelli
- Confronto corretto in collezioni (HashSet, Dictionary)
- Comportamento predicibile con LINQ Distinct()

---

### CORE-007 - Mancano costanti per Magic Numbers

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Alcuni valori numerici sono hardcoded senza costanti, rendendo il codice meno leggibile e più difficile da mantenere.

#### File Coinvolti

- `Core\Models\CheckDefinition.cs` (riga 44: `id < 0`)

#### Codice Problematico

```csharp
// CheckDefinition.cs riga 44
if (id < 0)
    throw new ArgumentException("ID must be >= 0", nameof(id));
```

#### Soluzione Proposta

```csharp
public sealed class CheckDefinition
{
    /// <summary>ID minimo valido per un check</summary>
    public const int MinCheckId = 0;

    public CheckDefinition(...)
    {
        if (id < MinCheckId)
            throw new ArgumentException($"ID must be >= {MinCheckId}", nameof(id));
        // ...
    }
}
```

**Nota:** Questo è un caso borderline. `0` come valore minimo per un ID è abbastanza auto-esplicativo, ma una costante migliorerebbe la documentazione inline.

#### Benefici Attesi

- Codice più auto-documentante
- Centralizzazione valori di validazione
- Facilità di modifica futura

---

### CORE-008 - Manca IEquatable su AssemblySession, TestSession, Phase

**Categoria:** Inconsistenza  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Alcune classi domain model implementano `IEquatable<T>` (`Device`, `WorkOrder`), altre no (`AssemblySession`, `TestSession`, `Phase`). Questo crea inconsistenza nelle semantiche di equality.

#### File Coinvolti

- `Core\Models\AssemblySession.cs` - manca `IEquatable<AssemblySession>`
- `Core\Models\TestSession.cs` - manca `IEquatable<TestSession>`
- `Core\Models\Phase.cs` - manca `IEquatable<Phase>`

#### Codice Problematico

```csharp
// Device - HA IEquatable
public sealed class Device : IEquatable<Device>

// WorkOrder - HA IEquatable
public sealed class WorkOrder : IEquatable<WorkOrder>

// AssemblySession - MANCA
public sealed class AssemblySession  // No IEquatable!

// TestSession - MANCA
public sealed class TestSession  // No IEquatable!
```

#### Soluzione Proposta

Implementare `IEquatable<T>` per tutte le classi domain model principali:

```csharp
public sealed class AssemblySession : IEquatable<AssemblySession>
{
    public bool Equals(AssemblySession? other)
    {
        if (other is null) return false;
        if (Id != 0 && other.Id != 0) return Id == other.Id;
        return ReferenceEquals(this, other);
    }

    public override bool Equals(object? obj) => Equals(obj as AssemblySession);
    public override int GetHashCode() => Id != 0 ? Id.GetHashCode() : RuntimeHelpers.GetHashCode(this);
}
```

#### Benefici Attesi

- Semantiche equality consistenti
- Comportamento prevedibile in collezioni (HashSet, Dictionary)
- Confronti affidabili in LINQ

---

### CORE-009 - TestSheet viola SRP (schema + builder)

**Categoria:** Design / SRP Violation  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

`TestSheet` ha metodi mutator (`AddCheck`, `AddFunctionalGroupTemplate`) che la rendono sia un Value Object/Schema che un Builder. Dopo essere caricata da JSON, può essere modificata, violando l'aspettativa di immutabilità.

#### File Coinvolti

- `Core\Models\TestSheet.cs` (righe 53-66)

#### Codice Problematico

```csharp
// TestSheet dovrebbe essere immutabile (è uno schema/template)
// Ma ha metodi che la modificano!

public void AddFunctionalGroupTemplate(FunctionalGroupTemplate template)
{
    ArgumentNullException.ThrowIfNull(template);
    _functionalGroupTemplates.Add(template);  // Mutazione!
}

public void AddCheck(CheckDefinition check)
{
    ArgumentNullException.ThrowIfNull(check);
    _checks.Add(check);
    _checks.Sort((a, b) => a.Id.CompareTo(b.Id));  // Mutazione + sort!
}
```

#### Scenario Problematico

```csharp
// Scenario problematico
var sheet = await provider.GetByPartNumberAsync("OPTIMUS-XP");
sheet.AddCheck(new CheckDefinition(...));  // Modifica lo schema caricato!
// Tutti i consumer vedono il check aggiunto (cache condivisa)
```

#### Soluzione Proposta

**Opzione A: Rendere TestSheet immutabile**

```csharp
public sealed class TestSheet
{
    public IReadOnlyList<CheckDefinition> Checks { get; }
    public IReadOnlyList<FunctionalGroupTemplate> FunctionalGroupTemplates { get; }

    public TestSheet(
        string partNumber,
        ProductType productType,
        string description,
        IEnumerable<CheckDefinition> checks,
        IEnumerable<FunctionalGroupTemplate> templates,
        string? revision = null,
        bool hasSecondaryDevice = false)
    {
        // ... validazione
        Checks = checks.OrderBy(c => c.Id).ToList();
        FunctionalGroupTemplates = templates.ToList();
    }
}
```

**Opzione B: Separare Builder**

```csharp
public class TestSheetBuilder
{
    public TestSheetBuilder AddCheck(CheckDefinition check) { ... }
    public TestSheetBuilder AddFunctionalGroupTemplate(FunctionalGroupTemplate t) { ... }
    public TestSheet Build() { ... }
}
```

#### Benefici Attesi

- Immutabilità garantita
- Thread-safety (schema condiviso in cache)
- SRP rispettato

---

## Priorità Bassa (Nuove)

### CORE-010 - CheckExecution senza Id (non aggiornabile)

**Categoria:** Design / Coupling  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

`CheckExecution` è un Value Object senza `Id`, ma nel DB (`CheckExecutionEntity`) ha un `Id`. Non è possibile aggiornare o cancellare una singola execution dal domain model.

#### File Coinvolti

- `Core\Models\CheckExecution.cs` - NO Id
- `Infrastructure.Persistence\Entities\CheckExecutionEntity.cs` - HA Id

#### Codice Problematico

```csharp
// Core/Models/CheckExecution.cs - NO Id
public sealed class CheckExecution
{
    public int CheckId { get; }
    public CheckOutcome Outcome { get; }
    public string Operator { get; }
    public DateTime ExecutedAt { get; }
    // ... NO Id!
}

// CheckExecutionEntity - HA Id ereditato da BaseEntity
public class CheckExecutionEntity : BaseEntity  // Ha Id!
```

#### Soluzione Proposta

**Opzione A (Raccomandato): Aggiungere Id opzionale**

```csharp
public sealed class CheckExecution
{
    /// <summary>ID per tracking dopo persistenza (0 se nuovo)</summary>
    public int Id { get; private set; }

    // ... altri campi

    public static CheckExecution Restore(int id, ...) { ... }
}
```

**Opzione B: Mantenere Value Object puro**

Se non serve mai aggiornare/cancellare execution singole, l'assenza di Id è intenzionale. Documentare la scelta.

#### Nota

Questa scelta impatta il pattern di mapping in `Services/Mapping/CheckExecutionMapper.cs`.

#### Benefici Attesi

- Possibilità di aggiornare note di una execution
- Cancellazione singola execution (se necessario)
- Mapping più lineare

---

### CORE-011 - Pattern Restore() verboso (KISS)

**Categoria:** Code Smell / KISS Violation  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-10

#### Descrizione

Ogni domain model ha un factory method `Restore()` con molti parametri posizionali. Questo crea codice verboso e soggetto a errori.

#### File Coinvolti

- `Core\Models\Device.cs` (8 parametri)
- `Core\Models\TestSession.cs` (9 parametri)
- `Core\Models\AssemblySession.cs` (7 parametri)

#### Codice Problematico

```csharp
// DeviceMapper.cs - 8 parametri posizionali!
return Device.Restore(
    id: entity.Id,
    workOrder: workOrder,
    serialSuffix: entity.SerialSuffix,
    assignedPhase: phase,
    status: entity.Status,
    finalSerial: entity.FinalSerial,
    firmwareVersion: entity.FirmwareVersion,
    bleMacAddress: entity.BleMacAddress
);
```

#### Soluzione Proposta

**Opzione A: Oggetto parametri (RestoreData)**

```csharp
public sealed record DeviceRestoreData(
    int Id,
    WorkOrder WorkOrder,
    string SerialSuffix,
    Phase AssignedPhase,
    DeviceStatus Status,
    string? FinalSerial = null,
    string? FirmwareVersion = null,
    string? BleMacAddress = null);

public static Device Restore(DeviceRestoreData data) { ... }
```

**Opzione B: Mantenere named parameters (status quo)**

Il pattern attuale funziona con named parameters. È verboso ma esplicito.

#### Nota

Questa è un'issue di stile/manutenibilità, non un bug. Il pattern attuale è funzionante e testato.

#### Benefici Attesi

- Meno errori da parametri in ordine sbagliato
- Refactoring più sicuro (aggiunta parametri)
- Codice più leggibile

---

## Issue Risolte

(Nessuna issue risolta al momento)

---

## Wontfix

(Nessuna issue wontfix al momento)

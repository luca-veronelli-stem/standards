# Core - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunità di refactoring e violazioni di best practice per il componente **Core**.

> **Ultimo aggiornamento:** 2026-04-10

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 0 | 2 |
| **Media** | 0 | 3 |
| **Bassa** | 3 | 0 |

**Totale aperte:** 3  
**Totale risolte:** 5

---

## Indice Issue Aperte

- [CORE-003 - Dictionary.RemoveVariable non verifica esistenza](#core-003--dictionaryremovevariable-non-verifica-esistenza)
- [CORE-004 - Mancanza di metodi Update sui modelli](#core-004--mancanza-di-metodi-update-sui-modelli)
- [CORE-005 - BitInterpretation.VariableId non ha validazione positiva](#core-005--bitinterpretationvariableid-non-ha-validazione-positiva)

## Indice Issue Risolte

- [CORE-008 - Creare StandardVariableOverride, rimuovere VariableDeviceState (T-006)](#core-008--creare-standardvariableoverride-rimuovere-variabledevicestate-t-006)
- [CORE-006 - Dictionary.Restore bypassa validazione unicità indirizzi](#core-006--dictionaryrestore-bypassa-validazione-unicità-indirizzi)
- [CORE-007 - Refactoring Core models per Domain v2](#core-007--refactoring-core-models-per-domain-v2)
- [CORE-001 - AuditEntityType contiene "Device" non esistente nel dominio](#core-001--auditentitytype-contiene-device-non-esistente-nel-dominio)
- [CORE-002 - Variable.Category deriva solo da AddressHigh == 0x00](#core-002--variablecategory-deriva-solo-da-addresshigh--0x00)

---

## Priorità Bassa

### CORE-003 - Dictionary.RemoveVariable non verifica esistenza

**Categoria:** API  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-18  

#### Descrizione

Il metodo `RemoveVariable` non notifica il chiamante se la variabile non esisteva nella lista. `List<T>.Remove()` ritorna `false` silenziosamente.

#### File Coinvolti

- `Core/Models/Dictionary.cs` (righe 55-58)

#### Codice Problematico

```csharp
public void RemoveVariable(Variable variable)
{
    _variables.Remove(variable);  // <-- Non verifica risultato
}
```

#### Problema Specifico

- Chiamare `RemoveVariable` con una variabile non presente non genera errore
- Potrebbe nascondere bug nel chiamante che assume la variabile fosse presente
- Inconsistenza: `AddVariable` valida, `RemoveVariable` no

#### Soluzione Proposta

**Opzione A: Return bool**

```csharp
public bool RemoveVariable(Variable variable)
{
    return _variables.Remove(variable);
}
```

**Opzione B: Throw se non trovata**

```csharp
public void RemoveVariable(Variable variable)
{
    if (!_variables.Remove(variable))
        throw new InvalidOperationException(
            $"Variable '{variable.Name}' not found in dictionary.");
}
```

#### Benefici Attesi

- API più prevedibile
- Bug detection più veloce
- Coerenza con `AddVariable`

---

### CORE-004 - Mancanza di metodi Update sui modelli

**Categoria:** API  
**Priorità:** Bassa  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-03-18  

#### Descrizione

I modelli `User`, `Dictionary`, `Command` non hanno metodi per aggiornare le proprietà. Solo `Variable` e `CommandDeviceState` hanno `Enable()`/`Disable()`.

#### File Coinvolti

- `Core/Models/User.cs`
- `Core/Models/Dictionary.cs`
- `Core/Models/Command.cs`

#### Problema Specifico

- Per aggiornare un `User.DisplayName` bisognerebbe creare una nuova istanza
- Il pattern immutabile è buono, ma mancano metodi `With*` o `Update*`
- Il Services layer dovrà gestire mapping complessi per update

#### Soluzione Proposta

**Opzione A: Metodi Update specifici (raccomandata)**

```csharp
// In User.cs
public void UpdateDisplayName(string newDisplayName)
{
    ArgumentException.ThrowIfNullOrWhiteSpace(newDisplayName);
    DisplayName = newDisplayName;
}
```

**Opzione B: Pattern With (immutabile puro)**

```csharp
public Dictionary WithName(string newName) => 
    new(newName, IsStandard) { Id = Id };
```

#### Benefici Attesi

- API più ergonomica per update CRUD
- Validazione centralizzata nelle modifiche
- Minore complessità nel Services layer

---

### CORE-005 - BitInterpretation.VariableId non ha validazione positiva

**Categoria:** API  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-03-18  

#### Descrizione

Il costruttore di `BitInterpretation` non valida che `variableId` sia positivo. Un `variableId = 0` o negativo sarebbe invalido ma non genera errore.

#### File Coinvolti

- `Core/Models/BitInterpretation.cs` (righe 17-30)

#### Codice Problematico

```csharp
public BitInterpretation(int variableId, int wordIndex, int bitIndex, string? meaning)
{
    if (wordIndex < 0)
        throw new ArgumentOutOfRangeException(nameof(wordIndex), "...");
    if (bitIndex < 0 || bitIndex > 15)
        throw new ArgumentOutOfRangeException(nameof(bitIndex), "...");

    // Manca: validazione variableId > 0
    VariableId = variableId;
    // ...
}
```

#### Soluzione Proposta

```csharp
public BitInterpretation(int variableId, int wordIndex, int bitIndex, string? meaning)
{
    if (variableId <= 0)
        throw new ArgumentOutOfRangeException(nameof(variableId), 
            "VariableId must be positive.");
    // ... resto validazioni
}
```

#### Benefici Attesi

- Fail-fast su dati invalidi
- Coerenza con altre validazioni nella classe
- Prevenzione bug a runtime

---

## Issue Risolte

### CORE-008 - Creare StandardVariableOverride, rimuovere VariableDeviceState (T-006)

**Categoria:** Refactoring  
**Priorità:** Alta  
**Impatto:** Alto — cambiamento di dominio fondamentale  
**Status:** ✅Risolto  
**Data Apertura:** 2026-03-30  
**Data Risoluzione:** 2026-04-07  
**Branch:** fix/t-006  
**Parent Issue:** [T-006](../ISSUES_TRACKER.md#t-006--standardvariableoverride-per-dizionario-domain-v7)

#### Soluzione Implementata

1. **Creato** `Core/Models/StandardVariableOverride.cs`:
   - `Id`, `DictionaryId`, `StandardVariableId`, `IsEnabled`, `Description?`
   - Factory method `Restore` per ricostruzione da DB
   - Metodi `Enable()`, `Disable()`, `SetDescription()`

2. **Eliminato** `Core/Models/VariableDeviceState.cs`

3. **Modificato** `Core/Enums/AuditEntityType.cs`:
   - Aggiunto `StandardVariableOverride` (8 valori totali)

4. **Modificato** `Core/Models/BitInterpretation.cs`:
   - `DeviceId?` → `DictionaryId?` (null = template Standard, valorizzato = per-dizionario)

#### Benefici Ottenuti

- Override variabili standard per-dizionario (non più per-device) ✅
- Semantica allineata a Lean 4 Specification v7 ✅
- BitInterpretation con scope per-dizionario (BR-017, BR-018) ✅

---

### CORE-006 - Dictionary.Restore bypassa validazione unicità indirizzi

**Categoria:** Bug (Defensive Programming)  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** ✅Risolto  
**Data Apertura:** 2026-03-23  
**Data Risoluzione:** 2026-03-25  
**Branch:** fix/core-006

#### Soluzione Implementata

Applicata **Opzione A: Assert difensivo in Restore**:

```csharp
var varList = variables.ToList();
var duplicates = varList.GroupBy(v => v.FullAddress).Where(g => g.Count() > 1).ToList();
if (duplicates.Count > 0)
    throw new InvalidOperationException(
        $"Duplicate FullAddress found in dictionary '{name}': " +
        string.Join(", ", duplicates.Select(g => $"0x{g.Key:X4}")));
```

#### Test Aggiunti

- `Restore_DuplicateAddress_ThrowsInvalidOperationException`

#### Benefici Ottenuti

- Fail-fast su dati corrotti nel DB ✅
- Coerenza con `AddVariable` ✅
- Debug più veloce in sviluppo ✅

---

### CORE-007 - Refactoring Core models per Domain v2

**Categoria:** Refactoring  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-03-25  
**Data Risoluzione:** 2026-03-25  
**Branch:** domain/ridefinizione-dominio-v2  
**Master Issue:** T-002

#### Descrizione

Rimozione entità `BoardType`, spostamento `FirmwareType` su `Board`, sostituzione semantica 3-tuple con `IsStandard` flag. Riferimento: Lean 4 Specification v2 (SESSION_024).

#### Soluzione Implementata

**Modifiche Effettuate:**

1. **`Core/Models/BoardType.cs`:** Rimosso (entità eliminata dal dominio)
2. **`Core/Models/Board.cs`:** Rimosso `BoardType`, aggiunto `FirmwareType` (int), `DictionaryId?` (int?), `IsPrimary` (bool)
3. **`Core/Models/Dictionary.cs`:** Rimosso `DeviceType?`, `BoardType?`. Aggiunto `IsStandard` (bool)
4. **`Core/Enums/AuditEntityType.cs`:** Rimosso `BoardType` (7→6 valori)

#### Benefici Ottenuti

- Domain model allineato alla realtà hardware ✅
- Semantica dizionario derivata (Standard/Dedicated/Shared/Orphan) ✅
- Meno entità = meno codice = meno bug ✅

---

### CORE-001 - AuditEntityType contiene "Device" non esistente nel dominio

**Categoria:** Design  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-03-18  
**Data Risoluzione:** 2026-03-19  
**Branch:** fix/core-001-002

#### Soluzione Implementata

Implementata **Opzione A: Rimuovere Device**. L'enum ora ha 7 valori.

#### Benefici Ottenuti

- Enum allineato al dominio reale ✅
- Nessun valore orfano ✅

---

### CORE-002 - Variable.Category deriva solo da AddressHigh == 0x00

**Categoria:** Design  
**Priorità:** Media  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-03-18  
**Data Risoluzione:** 2026-03-19  
**Branch:** fix/core-001-002

#### Soluzione Implementata

Implementate **entrambe le opzioni**:
1. Validazione nel costruttore: `AddressHigh` deve essere `0x00` o `0x80`
2. Match esplicito con `switch` expression nella proprietà `Category`

#### Test Aggiunti

- `Constructor_InvalidAddressHigh_ThrowsArgumentOutOfRangeException` (3 InlineData: 0x01, 0x40, 0xFF)

#### Benefici Ottenuti

- Fail-fast su AddressHigh invalido ✅
- Coerenza con enum VariableCategory ✅

---

## Wontfix

*(Nessuna issue in wontfix)*

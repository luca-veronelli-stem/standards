# Test Sheets

> **Sistema di definizione schede collaudo per prodotti STEM.**  
> **Ultimo aggiornamento:** 2026-03-04

---

## Panoramica

Il sistema **Test Sheets** permette di definire le schede collaudo dei prodotti STEM in file JSON, caricati a **runtime** senza necessità di ricompilare l'applicazione.

Ogni scheda collaudo definisce:
- **Part Number** - Identificativo univoco del prodotto/variante
- **Controlli** - Lista dei check da eseguire (Assembly e Testing)
- **Gruppi Funzionali** - Template dei componenti tracciati

---

## Caratteristiche

| Feature | Descrizione |
|---------|-------------|
| **JSON-based** | Definizioni in file JSON modificabili |
| **Controlli tipizzati** | Generic, Value (con range), Boolean |
| **Fasi separate** | Assembly (montaggio) vs Testing (collaudo) |
| **Gruppi Funzionali** | Template componenti per ogni prodotto |
| **Cache** | Caricamento ottimizzato con cache |
| **Migrabile** | Interfaccia astratta per futuro database |

---

## Struttura File

```
TestSheets/
├── Data/
│   └── optimus-xp.json              # Scheda OPTIMUS-XP (27 controlli + 2 gruppi funzionali)
├── Interfaces/
│   └── ITestSheetProvider.cs        # Interfaccia astratta
├── Models/
│   ├── TestSheetDto.cs              # DTO scheda completa + ToDomain()
│   ├── CheckDefinitionDto.cs        # DTO singolo controllo
│   └── FunctionalGroupTemplateDto.cs # DTO template gruppo funzionale
├── Providers/
│   └── JsonTestSheetProvider.cs     # Implementazione JSON
└── README.md
```

---

## Formato JSON

### Scheda Collaudo

```json
{
  "partNumber": "OPTIMUS-XP",
  "productType": "OptimusXp",
  "description": "SUPPORTO BARELLA AMMORTIZZATO TRASLABILE",
  "revision": "R03",
  "requiresFirmware": false,
  "hasSecondaryDevice": false,
  "functionalGroups": [
    { "partNumber": "DIS0022597", "description": "Scheda Elettronica" },
    { "partNumber": "OLCEOPT", "description": "Centralina Oleodinamica" }
  ],
  "checks": [
    {
      "id": 1,
      "description": "Controllo difetto di verniciatura",
      "type": "Generic",
      "phase": "Assembly",
      "notes": null
    },
    {
      "id": 21,
      "description": "Soglia di sottotensione batteria",
      "type": "Value",
      "phase": "Testing",
      "minValue": 9.5,
      "maxValue": 10.5,
      "notes": "Valore in Volt"
    }
  ]
}
```

---

## Campi TestSheet

| Campo | Tipo | Required | Descrizione |
|-------|------|:--------:|-------------|
| `partNumber` | string | ✅ | Identificativo univoco (es. "OPTIMUS-XP") |
| `productType` | string | ✅ | Tipo prodotto (EdenBs8, OptimusXp, ...) |
| `description` | string | ✅ | Descrizione del prodotto |
| `revision` | string | ❌ | Revisione scheda (es. "R03") |
| `hasSecondaryDevice` | bool | ❌ | Se ha device secondario (es. Sherpa) |
| `functionalGroups` | array | ❌ | Template gruppi funzionali (componenti tracciati) |
| `checks` | array | ❌ | Lista controlli |

## Campi FunctionalGroupTemplate

| Campo | Tipo | Required | Descrizione |
|-------|------|:--------:|-------------|
| `partNumber` | string | ✅ | Identificativo componente (es. "DIS0022597") |
| `description` | string | ❌ | Descrizione componente (es. "Scheda Elettronica") |

I template definiti nella scheda collaudo diventano **istanze** quando il montatore inserisce il S/N del componente effettivamente installato.

## Campi CheckDefinition

| Campo | Tipo | Required | Descrizione |
|-------|------|:--------:|-------------|
| `id` | int | ✅ | ID progressivo nella scheda |
| `description` | string | ✅ | Descrizione del controllo |
| `type` | string | ✅ | Tipo: Generic, Value, Boolean |
| `phase` | string | ✅ | Fase: Assembly, Testing |
| `referenceValue` | double | ❌ | Valore di riferimento (solo per Value) |
| `tolerance` | double | ❌ | Tolleranza ammessa (solo per Value) |
| `unit` | string | ❌ | Unità di misura per display (es. "mm") |
| `notes` | string | ❌ | Note aggiuntive |

### Tipi di Controllo

| Tipo | Codice | Descrizione | Esito |
|------|--------|-------------|-------|
| **Generic** | `G` | Controllo visivo/funzionale | OK / NO |
| **Value** | `V` | Misurazione con riferimento ± tolleranza | Valore numerico |
| **Boolean** | `B` | Presenza/assenza feature | Sì / No |

### Fasi di Controllo

| Fase | Codice | Descrizione |
|------|--------|-------------|
| **Assembly** | `A`, `10` | Durante montaggio (montatore) |
| **Testing** | `T`, `20` | Durante collaudo (collaudatore) |

---

## Utilizzo

### Registrazione DI

```csharp
// In AddPersistence() - già incluso
services.AddSingleton<ITestSheetProvider, JsonTestSheetProvider>();
```

### Caricamento Schede

```csharp
public class MyService
{
    private readonly ITestSheetProvider _provider;

    public async Task LoadSheetAsync()
    {
        // Per part number specifico
        var sheet = await _provider.GetByPartNumberAsync("OPTIMUS-XP");
        
        // Per tipo prodotto (include varianti)
        var sheets = await _provider.GetByProductTypeAsync(ProductType.OptimusXp);
        
        // Lista tutti i part number disponibili
        var partNumbers = await _provider.GetAvailablePartNumbersAsync();
        
        // Verifica esistenza
        var exists = await _provider.ExistsAsync("OPTIMUS-XP");
    }
}
```

### Conversione a Domain Model

```csharp
// Il provider ritorna già il Domain Model (TestSheet)
var sheet = await _provider.GetByPartNumberAsync("OPTIMUS-XP");

// Accesso ai controlli
foreach (var check in sheet.Checks)
{
    Console.WriteLine($"{check.Id}: {check.Description} ({check.Phase})");
}

// Filtro per fase
var assemblyChecks = sheet.Checks.Where(c => c.Phase == CheckPhase.Assembly);
var testingChecks = sheet.Checks.Where(c => c.Phase == CheckPhase.Testing);
```

---

## Varianti

I prodotti possono avere varianti con controlli diversi:

```
TestSheets/Data/
├── optimus-xp.json       # Scheda base
├── optimus-xp-066.json   # Variante 066 (futuro)
└── optimus-xp-070.json   # Variante 070 (futuro)
```

Per ogni ODL si usa **una sola scheda** (una variante specifica).

---

## Migrazione Futura

L'interfaccia `ITestSheetProvider` permette di cambiare implementazione:

```csharp
// Oggi: JSON files
services.AddSingleton<ITestSheetProvider, JsonTestSheetProvider>();

// Domani: Database
services.AddSingleton<ITestSheetProvider, DatabaseTestSheetProvider>();
```

---

## Persistenza TestSheetPartNumber

Le sessioni (Assembly e Test) salvano il `TestSheetPartNumber` nel database.

Quando una sessione viene recuperata, il service carica automaticamente la `TestSheet` corretta dal provider:

```csharp
// In AssemblySessionService.MapToDomainWithExecutionsAsync()
var sheet = await _testSheetProvider.GetByPartNumberAsync(entity.TestSheetPartNumber, ct)
    ?? throw new InvalidOperationException($"TestSheet '{entity.TestSheetPartNumber}' not found");
```

Questo garantisce che `CanComplete()` verifichi i controlli **reali** della scheda associata.

## Links

- [Infrastructure.Persistence](../README.md)
- [DeviceDefinitions](../DeviceDefinitions/README.md)
- [Core Models](../../Core/README.md)
- [Tests](../../Tests/README.md)

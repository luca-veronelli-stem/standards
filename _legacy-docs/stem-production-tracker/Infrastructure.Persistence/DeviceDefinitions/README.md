# Device Definitions

> **Sistema di definizione variabili per dispositivi STEM.**  
> **Ultimo aggiornamento:** 2026-03-02

---

## Panoramica

Il sistema **Device Definitions** permette di definire le variabili dei dispositivi STEM in file JSON, caricati a **runtime** senza necessità di ricompilare l'applicazione.

---

## Caratteristiche

| Feature | Descrizione |
|---------|-------------|
| **JSON-based** | Definizioni in file JSON modificabili |
| **Separazione Standard/Device** | Variabili comuni vs specifiche |
| **Cache** | Caricamento ottimizzato con cache |
| **Validazione** | Controllo indirizzi duplicati |
| **Migrabile** | Interfaccia astratta per futuro Azure SQL |

---

## Struttura File

```
DeviceDefinitions/
├── Data/
│   ├── common/
│   │   └── standard-variables.json    # Variabili comuni (0x00xx)
│   └── devices/
│       ├── optimus-xp.json            # OPTIMUS XP (0x80xx)
│       ├── eden-bs8.json              # (futuro)
│       └── r3l.json                   # (futuro)
├── Interfaces/
│   └── IDeviceDefinitionProvider.cs   # Interfaccia astratta
├── Models/
│   ├── VariableDefinitionDto.cs       # DTO variabile
│   ├── DeviceDefinitionDto.cs         # DTO device
│   └── JsonDtos.cs                    # DTO per parsing
└── Providers/
    └── JsonFileDefinitionProvider.cs  # Implementazione JSON
```

---

## Formato JSON

### Standard Variables (common)

```json
{
  "name": "StandardVariables",
  "description": "Variabili comuni a tutti i device STEM",
  "variables": [
    {
      "name": "Firmware macchina",
      "addressHigh": 0,
      "addressLow": 0,
      "dataType": "UInt16",
      "access": "ReadOnly",
      "description": "Versione firmware"
    }
  ]
}
```

### Device Variables

```json
{
  "deviceType": "OptimusXp",
  "boardAddress": "0x000A0441",
  "description": "OPTIMUS XP - Piano oleodinamico",
  "variables": [
    {
      "name": "SystemOn",
      "addressHigh": 128,
      "addressLow": 3,
      "dataType": "UInt8",
      "access": "ReadOnly",
      "min": 0,
      "max": 1,
      "description": "0 = spento, 1 = acceso"
    }
  ]
}
```

---

## Campi Variabile

| Campo | Tipo | Required | Descrizione |
|-------|------|:--------:|-------------|
| `name` | string | ✅ | Nome descrittivo |
| `addressHigh` | byte | ✅ | Byte alto indirizzo (decimale) |
| `addressLow` | byte | ✅ | Byte basso indirizzo (decimale) |
| `dataType` | string | ✅ | Tipo dato (vedi sotto) |
| `access` | string | ✅ | ReadOnly, ReadWrite, None |
| `min` | double | ❌ | Valore minimo |
| `max` | double | ❌ | Valore massimo |
| `unit` | string | ❌ | Unità di misura |
| `arraySize` | int | ❌ | Dimensione (solo ByteArray) |
| `description` | string | ❌ | Descrizione/significato |

### Data Types

| Tipo | Dimensione | Note |
|------|:----------:|------|
| `UInt8` | 1 byte | 0-255 |
| `Int8` | 1 byte | -128 to 127 |
| `UInt16` | 2 bytes | 0-65535 |
| `Int16` | 2 bytes | -32768 to 32767 |
| `UInt32` | 4 bytes | 0-4294967295 |
| `Int32` | 4 bytes | ±2 miliardi |
| `Float` | 4 bytes | IEEE 754 |
| `ByteArray` | N bytes | Richiede `arraySize` |

### Access Types

| Accesso | Significato | IsReadOnly |
|---------|-------------|:----------:|
| `ReadOnly` / `R` | Solo lettura | ✅ |
| `ReadWrite` / `RW` | Lettura/scrittura | ❌ |
| `None` / `N` | Non accessibile | ✅ |

---

## Utilizzo

### Registrazione DI

```csharp
// In AddPersistence() - già incluso
services.AddSingleton<IDeviceDefinitionProvider, JsonFileDefinitionProvider>();
```

### Caricamento Definizioni

```csharp
public class MyService
{
    private readonly IDeviceDefinitionProvider _provider;

    public async Task LoadOptimusAsync()
    {
        var definition = await _provider.GetDefinitionAsync("OptimusXp");
        
        Console.WriteLine($"Device: {definition.DeviceType}");
        Console.WriteLine($"Variables: {definition.VariableCount}");
        Console.WriteLine($"Standard: {definition.StandardVariables.Count()}");
        Console.WriteLine($"Specific: {definition.DeviceSpecificVariables.Count()}");
    }
}
```

---

## Convenzioni Indirizzi

| Range | Tipo | Esempio |
|-------|------|---------|
| `0x0000 - 0x7FFF` | Standard (comuni) | `addressHigh < 128` |
| `0x8000 - 0xFFFF` | Device-specific | `addressHigh >= 128` |

---

## Migrazione Futura

L'interfaccia `IDeviceDefinitionProvider` permette di cambiare implementazione:

```csharp
// Oggi: JSON files
services.AddSingleton<IDeviceDefinitionProvider, JsonFileDefinitionProvider>();

// Domani: Azure SQL
services.AddSingleton<IDeviceDefinitionProvider, AzureSqlDefinitionProvider>();
```

---

## Links

- [Devices Plugin](../../Devices/README.md)
- [Protocol VariableDefinition](https://dev.azure.com/stem-fw/stem-nuget)

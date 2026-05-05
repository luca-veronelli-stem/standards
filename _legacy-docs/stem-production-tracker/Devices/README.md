# Devices

> **Plugin per i dispositivi STEM supportati.**  
> **Ultimo aggiornamento:** 2026-02-28

---

## Panoramica

Il progetto **Devices** contiene i plugin per i vari tipi di dispositivi STEM. Ogni plugin:

- Carica le definizioni variabili da JSON (via `IDeviceDefinitionProvider`)
- Converte le definizioni nel formato Protocol (`VariableDefinition`)
- Popola la `IVariableMap` per la comunicazione

---

## Caratteristiche

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **OPTIMUS XP** | ✅ | Piano oleodinamico |
| **EDEN BS8** | 🔲 | Da implementare |
| **R3L Master/Slave** | 🔲 | Da implementare |

---

## Requisiti

- **.NET 10.0**
- `Stem.Communication.Protocol` 0.6.0+
- `Infrastructure.Persistence` (per `IDeviceDefinitionProvider`)

---

## Quick Start

```csharp
// Registrazione DI
services.AddPersistence(connectionString);  // include IDeviceDefinitionProvider
services.AddDevices();                      // registra tutti i plugin

// Oppure solo OPTIMUS
services.AddOptimusXp();
```

```csharp
// Utilizzo
public class MyService
{
    private readonly OptimusXpPlugin _optimus;
    private readonly IVariableMap _variableMap;

    public async Task InitializeAsync()
    {
        // Registra tutte le variabili OPTIMUS nella mappa
        var count = await _optimus.RegisterVariablesAsync(_variableMap);
        Console.WriteLine($"Registrate {count} variabili OPTIMUS XP");
    }
}
```

---

## Struttura

```
Devices/
├── Common/
│   └── BaseVariableMapBuilder.cs    # Logica condivisa
├── OptimusXp/
│   └── OptimusXpPlugin.cs           # Plugin OPTIMUS XP
├── EdenBs8/                         # (futuro)
├── R3l/                             # (futuro)
├── DependencyInjection.cs           # AddDevices(), AddOptimusXp()
└── README.md
```

---

## Architettura

```
┌─────────────────────────────────────────────────────────────┐
│  JSON Files (Infrastructure.Persistence/DeviceDefinitions/) │
│  ├── common/standard-variables.json                        │
│  └── devices/optimus-xp.json                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ IDeviceDefinitionProvider
┌─────────────────────────────────────────────────────────────┐
│  DeviceDefinitionDto (standard + device-specific merged)   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ OptimusXpPlugin + BaseVariableMapBuilder
┌─────────────────────────────────────────────────────────────┐
│  Stem.Protocol.IVariableMap (pronto per comunicazione)     │
└─────────────────────────────────────────────────────────────┘
```

---

## Aggiungere un nuovo device

1. Crea il file JSON in `Infrastructure.Persistence/DeviceDefinitions/Data/devices/{device-type}.json`
2. Crea la cartella `Devices/{DeviceType}/`
3. Crea `{DeviceType}Plugin.cs` (copia da `OptimusXpPlugin.cs`)
4. Aggiungi `AddDeviceType()` in `DependencyInjection.cs`
5. Aggiungi chiamata in `AddDevices()`

---

## Issue Correlate

→ [Devices/ISSUES.md](./ISSUES.md) *(da creare)*

---

## Links

- [Infrastructure.Persistence](../Infrastructure.Persistence/README.md)
- [Stem.Protocol Documentation](https://dev.azure.com/stem-fw/stem-nuget)

# Standard Struttura Cartelle Componenti

> **Versione:** 1.0  
> **Data:** 2026-02-17  
> **Stato:** Proposta

---

## Scopo

Definire una struttura di cartelle consistente per ogni componente del progetto, facilitando:
- Navigazione e discoverability del codice
- Onboarding di nuovi sviluppatori
- Separazione chiara tra tipi pubblici e interni

---

## Struttura Standard

```
{ComponentName}/
├── 📁 Configuration/           # Configurazioni e costanti
│   ├── {Component}Configuration.cs
│   ├── {Component}Constants.cs
│   └── {Other}Configuration.cs
│
├── 📁 Models/                  # DTO, record, struct pubblici
│   ├── {Model}Info.cs
│   ├── {Model}Result.cs
│   └── {Model}EventArgs.cs
│
├── 📁 Abstractions/            # Interfacce pubbliche
│   ├── I{Component}.cs
│   └── I{Component}Factory.cs
│
├── 📁 {Feature}/               # Feature principali (se multiple)
│   ├── {Feature}.cs
│   ├── {Feature}Factory.cs
│   └── Platforms/              # Implementazioni platform-specific
│       ├── Windows/
│       │   └── Windows{Feature}.cs
│       └── Mobile/
│           └── Plugin{Feature}.cs
│
├── 📁 Helpers/                 # Classi helper interne
│   ├── {Name}Helper.cs
│   └── {Name}Buffer.cs
│
├── 📁 Exceptions/              # Eccezioni custom (se presenti)
│   └── {Component}Exception.cs
│
├── {Component}.csproj
├── README.md
└── ISSUES.md
```

---

## Regole

### FS-001: Cartelle per Responsabilità
| Cartella | Contenuto | Visibilità |
|----------|-----------|------------|
| `Configuration/` | `*Configuration.cs`, `*Constants.cs` | `public` |
| `Models/` | DTO, record, EventArgs | `public` |
| `Abstractions/` | Interfacce | `public` |
| `Helpers/` | Utility interne | `internal` |
| `Exceptions/` | Eccezioni custom | `public` |
| `Platforms/` | Implementazioni platform-specific | varia |

### FS-002: Nesting Massimo
- **Max 3 livelli** di cartelle (es. `Scanner/Platforms/Windows/`)
- Se serve più nesting, valutare splitting in componenti separati

### FS-003: File nella Root
Solo i file essenziali nella root del componente:
- `*.csproj`
- `README.md`
- `ISSUES.md`
- Entry point pubblici (opzionale, se pochi file)

### FS-004: Platforms Condivise
Se più feature hanno implementazioni platform-specific:
```
{Component}/
├── Scanner/
│   └── Platforms/Windows/...
├── Driver/
│   └── Platforms/Windows/...
```

Se una sola feature:
```
{Component}/
├── Platforms/
│   └── Windows/
│       ├── WindowsScanner.cs
│       └── WindowsDriver.cs
```

### FS-005: Naming Conventions
| Tipo | Pattern | Esempio |
|------|---------|---------|
| Interfacce | `I{Name}.cs` | `IBleScanner.cs` |
| Factory | `{Name}Factory.cs` | `BleScannerFactory.cs` |
| Config | `{Name}Configuration.cs` | `BleChannelConfiguration.cs` |
| Costanti | `{Name}Constants.cs` | `BleChannelConstants.cs` |
| Platform impl | `{Platform}{Name}.cs` | `WindowsBleScanner.cs` |
| Helper | `{Name}Helper.cs` | `BleFramingHelper.cs` |
| Modelli | `{Name}Info.cs`, `{Name}Result.cs` | `BleDeviceInfo.cs` |

---

## Quando Usare Cartelle

| Condizione | Azione |
|------------|--------|
| ≤3 file dello stesso tipo | File nella root o cartella parent |
| >3 file dello stesso tipo | Creare cartella dedicata |
| Implementazioni platform-specific | Sempre in `Platforms/{Platform}/` |
| Unica implementazione | Nessuna cartella Platforms necessaria |

---

## Esempi

### Componente Semplice (pochi file)
```
Drivers.Can/
├── CanChannelDriver.cs
├── CanChannelConfiguration.cs
├── CanChannelConstants.cs
├── ICanHardware.cs
├── Platforms/
│   └── Windows/
│       └── PcanHardware.cs
├── Helpers/
│   └── NetInfoHelper.cs
├── Drivers.Can.csproj
└── README.md
```

### Componente Complesso (molti file)
```
Drivers.Ble/
├── Configuration/
│   ├── BleChannelConfiguration.cs
│   ├── BleChannelConstants.cs
│   └── BleScanConfiguration.cs
├── Models/
│   └── BleDeviceInfo.cs
├── Abstractions/
│   ├── IBleScanner.cs
│   └── IBleHardware.cs
├── Scanner/
│   ├── BleScannerFactory.cs
│   └── Platforms/
│       ├── Windows/WindowsBleScanner.cs
│       └── Mobile/PluginBleScanner.cs
├── Driver/
│   ├── BleChannelDriver.cs
│   ├── BleChannelDriverFactory.cs
│   └── Platforms/
│       ├── Windows/WindowsBleHardware.cs
│       └── Mobile/PluginBleHardware.cs
├── Helpers/
│   ├── BleFramingHelper.cs
│   ├── BleMtuHelper.cs
│   └── BleReassemblyBuffer.cs
├── Exceptions/
│   └── BleHardwareException.cs
├── Drivers.Ble.csproj
└── README.md
```

---

## Migrazione Esistente

Per componenti esistenti, migrare gradualmente:
1. Creare nuove cartelle
2. Spostare file uno alla volta
3. Aggiornare namespace se necessario
4. Verificare build
5. Aggiornare riferimenti nei test

---

## Eccezioni

| Componente | Eccezione | Motivazione |
|------------|-----------|-------------|
| `Protocol/Layers/` | Struttura OSI | Segue modello 7 layer standard |
| `Tests/` | Specchia `src/` | Convenzione xUnit |

---

## Checklist Nuovo Componente

- [ ] Creare cartella `Configuration/` se >1 config
- [ ] Creare cartella `Models/` se >1 DTO
- [ ] Creare cartella `Abstractions/` se >1 interfaccia
- [ ] Creare cartella `Platforms/` se multi-platform
- [ ] Creare cartella `Helpers/` se >1 helper
- [ ] README.md nella root
- [ ] ISSUES.md nella root

---

## Changelog

| Data | Versione | Descrizione |
|------|----------|-------------|
| 2026-02-17 | 1.0 | Bozza iniziale |


# Firmware

> **Provider per gestione firmware dei dispositivi STEM.**  
> **Ultimo aggiornamento:** 2026-03-11

---

## Panoramica

Il modulo **Firmware** gestisce il recupero delle informazioni firmware da sorgenti esterne (Azure API) 
e supporta l'aggiornamento firmware sui dispositivi STEM via BLE.

---

## Caratteristiche

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **StubFirmwareProvider** | ✅ | Dati fake per sviluppo (senza API key) |
| **AzureFirmwareProvider** | ✅ | Chiama API REST Azure (richiede API key) |
| **Firmware Ponte** | ✅ | Supporto per firmware bridge schede DIS0022597 |
| **FirmwareUpdateDialog** | ✅ | Dialog WPF per selezione firmware |
| **UI Montatore** | ✅ | Pulsante aggiorna in AssemblySessionPanel |
| **UI Collaudatore** | ✅ | Pulsante aggiorna in TestSessionPanel |
| **Upload BLE** | 🔲 | TODO - comandi Protocol 5 → 7 → 6 |

---

## Struttura

```
Infrastructure.Persistence/Firmware/
├── Interfaces/
│   └── IFirmwareProvider.cs       # Interfaccia provider
├── Providers/
│   ├── StubFirmwareProvider.cs    # Dati fake (sviluppo)
│   └── AzureFirmwareProvider.cs   # API REST (produzione)
└── README.md
```

---

## Configurazione

### appsettings.json

```json
{
  "Firmware": {
    "BaseUrl": "https://firmware-api.stem.it",
    "ApiKey": "your-api-key-here"
  }
}
```

### Logica di selezione provider

```csharp
// In DependencyInjection.cs
if (options?.IsConfigured == true)
    services.AddSingleton<IFirmwareProvider, AzureFirmwareProvider>();
else
    services.AddSingleton<IFirmwareProvider, StubFirmwareProvider>();
```

- **ApiKey vuota o mancante** → `StubFirmwareProvider` (dati fake)
- **ApiKey configurata** → `AzureFirmwareProvider` (API reale)

---

## Modello Dati

### FirmwareInfo

```csharp
public sealed record FirmwareInfo(
    string Version,           // es. "1.2.3"
    ProductType ProductType,  // tipo prodotto target
    DateTime ReleaseDate,     // data rilascio
    string? Notes,            // note (opzionali)
    bool IsBridge = false     // true se firmware ponte
);
```

### Firmware Ponte

Il firmware ponte (`IsBridge = true`) può essere applicato a device con scheda **DIS0022597**:
- EDEN BS8
- EDEN XP
- OPTIMUS XP

Usato per "ribattezzare" schede tra device diversi della stessa famiglia.

---

## Utilizzo

### Ottenere firmware disponibili

```csharp
var firmwares = await _firmwareProvider.GetAvailableAsync(ProductType.OptimusXp);
// Restituisce lista ordinata per data decrescente
// Include firmware ponte applicabili
```

### Scaricare un firmware

```csharp
var bytes = await _firmwareProvider.DownloadAsync(firmware);
// Restituisce i bytes del binario
```

---

## Migrazione futura: Azure Key Vault

La configurazione è pronta per la migrazione a Azure Key Vault:

```csharp
// Aggiungere in App.xaml.cs
builder.Configuration.AddAzureKeyVault(
    new Uri(Environment.GetEnvironmentVariable("AZURE_KEY_VAULT_URI")!),
    new DefaultAzureCredential());
```

Il codice applicativo **non cambia** - il valore viene letto dallo stesso percorso `Firmware:ApiKey`.

---

## Links

- [Core/Models/FirmwareInfo.cs](../../Core/Models/FirmwareInfo.cs) - Domain model
- [GUI.Windows/ViewModels/FirmwareUpdateViewModel.cs](../../GUI.Windows/ViewModels/FirmwareUpdateViewModel.cs) - ViewModel dialog
- [README principale](../../README.md)

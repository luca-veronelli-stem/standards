# STEM Communication - Feature Tracker

> **Ultimo aggiornamento:** 2026-02-20

---

## Riepilogo

| Status | Conteggio |
|--------|-----------|
| **In Sviluppo** | 0 |
| **Pianificate** | 0 |
| **Completate** | 1 |

**Totale:** 1 feature

---

## Indice Feature

### Pianificate

*Nessuna feature pianificata.*

### In Sviluppo

*Nessuna feature attualmente in sviluppo.*

### Completate

| ID | Componente | Titolo | Versione |
|----|------------|--------|----------|
| **F-001** | Drivers.Ble | [API Device Discovery per Scansione Dispositivi Nearby](#f-001---api-device-discovery-per-scansione-dispositivi-nearby) | 0.5.2 |

---

## Convenzioni

| Elemento | Formato | Esempio |
|----------|---------|---------|
| **Feature ID** | `F-{NNN}` | `F-001`, `F-002` |
| **Status** | Pianificata / In Sviluppo / Completata | - |
| **Priorità** | Alta / Media / Bassa | - |
| **Data** | ISO 8601 (YYYY-MM-DD) | `2026-02-17` |

---

## Feature Completate

### F-001 - API Device Discovery per Scansione Dispositivi Nearby

**Componente:** Drivers.Ble  
**Priorità:** Media  
**Status:** ✅ Completata  
**Data Richiesta:** 2026-02-16  
**Data Completamento:** 2026-02-17  
**Versione:** 0.5.2

#### Descrizione

API per scansionare dispositivi BLE nelle vicinanze e mostrare una lista selezionabile all'utente.

#### Implementazione

**Tipi implementati:**

| Tipo | File | Note |
|------|------|------|
| `IBleScanner` | `IBleScanner.cs` | Interfaccia pubblica |
| `BleScannerFactory` | `BleScannerFactory.cs` | Factory per creazione |
| `BleScanConfiguration` | `BleScanConfiguration.cs` | Config con validazione |
| `BleDeviceInfo` | `BleDeviceInfo.cs` | DTO dispositivo |
| `WindowsBleScanner` | `Hardware/Windows/WindowsBleScanner.cs` | Impl. Windows (internal) |

**API pubblica:**

```csharp
// 1. Crea scanner
await using var scanner = BleScannerFactory.Create();

// 2. Evento per aggiornamenti real-time
scanner.DeviceDiscovered += (s, device) => 
    Console.WriteLine($"{device.Name} ({device.MacAddress}) RSSI: {device.Rssi}");

// 3. Scansiona (ritorna lista dopo timeout)
var devices = await scanner.ScanAsync(new BleScanConfiguration
{
    Timeout = TimeSpan.FromSeconds(10),
    FilterStemDevicesOnly = true,
    MinimumRssi = -80
});

// 4. Connetti al dispositivo selezionato
var driver = BleChannelDriverFactory.Create(devices[0]);
await driver.ConnectAsync(config);
```

**Modifiche correlate:**

| Modifica | Motivazione |
|----------|-------------|
| `BleChannelConfiguration.DeviceMacAddress` ora **required** | Rimuove ambiguità, MAC è l'identificatore primario |
| `BleChannelConfiguration.DeviceNameFilter` rimosso | Deprecato a favore del flusso scan → select → connect |
| `BleChannelDriverFactory.Create(BleDeviceInfo)` nuovo overload | Semplifica creazione driver da scan result |
| Impl. platform-specific ora `internal` | Nasconde dettagli, utente usa solo factory |

**Test:**
- 89 nuovi test per scanner e configurazioni
- 672 test BLE totali, 658 passed, 14 skipped
- Testato end-to-end con 6 dispositivi STEM reali ✅

#### Breaking Changes (v0.5.2)

```csharp
// PRIMA (0.5.1)
var config = new BleChannelConfiguration
{
    DeviceNameFilter = "STEM_Device"  // ❌ Non più supportato
};

// DOPO (0.5.2)
await using var scanner = BleScannerFactory.Create();
var devices = await scanner.ScanAsync();
var selected = devices.First(d => d.Name?.Contains("STEM_Device") == true);

var driver = BleChannelDriverFactory.Create(selected);  // ✅ Nuovo workflow
```

---

## Come Proporre una Feature

1. Aprire una discussione o issue su Bitbucket
2. Descrivere il caso d'uso e il problema che risolve
3. Proporre una soluzione tecnica (opzionale)
4. Attendere approvazione prima di iniziare l'implementazione
5. Una volta approvata, verrà aggiunta a questo file come "Pianificata"

---

## Links

- [ISSUES.md](./Protocol/ISSUES.md) - Bug e problemi tecnici
- [CHANGELOG.md](./CHANGELOG.md) - Storico versioni
- [README.md](./README.md) - Documentazione principale

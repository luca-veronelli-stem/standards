# Standard Visibilità - Controllo API Surface

> **Versione:** 2.0  
> **Data:** 2026-02-12  
> **Riferimento Issue:** T-017  
> **Stato:** Active

---

## Scopo

Questo standard definisce le regole di visibilità (`public`, `internal`, `private`, `protected`) per tutti i componenti del progetto STEM Protocol, garantendo:

1. **API Surface minima** per i consumatori dei pacchetti NuGet
2. **Encapsulation** dei dettagli implementativi
3. **Stabilità** delle interfacce pubbliche
4. **Manutenibilità** del codebase

**Si applica a:** Protocol, Drivers.Can, Drivers.Ble, Client

---

## Principi Guida

1. **Minimal API Surface:** Esporre solo ciò che i consumatori DEVONO usare
2. **Default to Internal:** Le classi sono `internal` salvo necessità pubblica documentata
3. **Sealed by Default:** Classi pubbliche sono `sealed` salvo design esplicito per ereditarietà
4. **Interface over Implementation:** Le interfacce sono pubbliche, le implementazioni sono interne
5. **Test via InternalsVisibleTo:** I test accedono ai membri internal senza esporli pubblicamente

---

## Regole

### R-001: Classi e Struct

| Tipo | Visibilità | Livello |
|------|------------|---------|
| Facade/Entry Point | `public sealed class` | ✅ DEVE |
| Interface | `public interface` | ✅ DEVE |
| DTO/Model pubblico | `public sealed class/record` | ✅ DEVE |
| Configuration | `public sealed class` | ✅ DEVE |
| Statistics | `public sealed class` | ✅ DEVE |
| EventArgs | `public sealed class` | ✅ DEVE |
| Constants | `public static class` | ✅ DEVE |
| Layer Implementation | `internal sealed class` | ✅ DEVE |
| Helper/Utility | `internal sealed/static class` | ✅ DEVE |
| State Machine | `internal sealed class` | ✅ DEVE |
| Buffer/Manager interno | `internal sealed class` | ✅ DEVE |
| Base class ereditabile | `public abstract class` | ⚠️ DOVREBBE |

### R-002: Enum

| Tipo | Visibilità | Livello |
|------|------------|---------|
| Enum usato in API pubblica | `public enum` | ✅ DEVE |
| Enum interno (errori parsing, etc.) | `internal enum` | ✅ DEVE |

### R-003: Membri

| Tipo | Visibilità | Livello |
|------|------------|---------|
| Campi di istanza | `private` | ✅ DEVE |
| Properties pubbliche API | `public` | ✅ DEVE |
| Properties interne | `internal` | ✅ DEVE |
| Metodi helper privati | `private` | ✅ DEVE |
| Hook per derivate | `protected virtual` | ⚠️ DOVREBBE |

### R-004: InternalsVisibleTo

```xml
<!-- In Directory.Build.props -->
<ItemGroup>
  <InternalsVisibleTo Include="Tests" />
  <InternalsVisibleTo Include="DynamicProxyGenAssembly2" /> <!-- Per Moq -->
</ItemGroup>
```

---

## API Pubblica (55 tipi)

### Entry Points (3)

| Tipo | Nome |
|------|------|
| `public sealed class` | `ProtocolStack` |
| `public sealed class` | `ProtocolStackBuilder` |
| `public sealed class` | `StackConfiguration` |

### Interfacce (9)

| Tipo | Nome |
|------|------|
| `public interface` | `IProtocolLayer` |
| `public interface` | `ILayerStatistics` |
| `public interface` | `IChannelDriver` |
| `public interface` | `IChannelConfiguration` |
| `public interface` | `ICommandHandler` |
| `public interface` | `IAckHandler` |
| `public interface` | `IVariableMap` |
| `public interface` | `IDeviceDiscoveryService` |
| `public interface` | `IBroadcastManager` |

### Configurazioni (7)

`LayerConfiguration` (base, non-sealed) + 6 sealed derivate per ogni layer.

### Statistiche (9)

7 `*LayerStatistics` + `ChannelStatistics` + `BufferStatistics`

### Enums (12)

`ChannelType`, `CryptType`, `CommandId`, `LayerStatus`, `SessionState`, `StemDevice`, `VariableDataType`, `FlowDirection`, `DeviceStatus`, `PacketPriority`, `RoutingStrategy`, `MetricsFormat`

### Static Classes - Costanti (9)

`ProtocolConstants`, `*LayerConstants` (7), `VariableDataTypeExtensions`

### EventArgs (9)

`MessageReceivedEventArgs`, `AckReceivedEventArgs`, `SessionEstablishedEventArgs`, `SessionTerminatedEventArgs`, `StateChangedEventArgs`, `DeviceDiscoveredEventArgs`, `DeviceLostEventArgs`, `RouteAddedEventArgs`, `LinkQualityAlertEventArgs`

### DTOs (5)

`ApplicationMessage`, `LayerContext`, `LayerResult`, `VariableDefinition`, `ChannelMetadata`

### Eccezioni (4)

`ChannelException` (base), `ChannelNotConnectedException`, `ChannelTimeoutException`, `ConnectionLostException`

### Utilities (2)

`DeviceIdCalculator`, `ApplicationMessageSerializer`

---

## Drivers.Ble - API Pubblica (10 tipi)

> Aggiunto con F-001 (2026-02-17)

### Entry Points (3)

| Tipo | Nome | Note |
|------|------|------|
| `public sealed class` | `BleChannelDriver` | Driver principale (costruttore internal) |
| `public static class` | `BleChannelDriverFactory` | Factory per creare driver |
| `public static class` | `BleScannerFactory` | Factory per creare scanner |

### Interfacce (1)

| Tipo | Nome | Note |
|------|------|------|
| `public interface` | `IBleScanner` | API scansione dispositivi |

### Configurazioni (2)

| Tipo | Nome | Note |
|------|------|------|
| `public sealed record` | `BleChannelConfiguration` | Config connessione (DeviceMacAddress required) |
| `public sealed record` | `BleScanConfiguration` | Config scansione |

### Costanti (1)

| Tipo | Nome |
|------|------|
| `public static class` | `BleChannelConstants` |

### DTOs (1)

| Tipo | Nome | Note |
|------|------|------|
| `public sealed record` | `BleDeviceInfo` | DTO dispositivo scoperto |

### Eccezioni (1)

| Tipo | Nome | Note |
|------|------|------|
| `public class` | `BleHardwareException` | Non-sealed (base class) |

### Enums (1)

| Tipo | Nome | Note |
|------|------|------|
| `public enum` | `BleOperationType` | Usato in BleHardwareException |

### Tipi Internal (7)

| Tipo | Nome | Motivazione |
|------|------|-------------|
| `internal interface` | `IBleHardware` | Astrazione interna hardware |
| `internal sealed class` | `WindowsBleHardware` | Impl. Windows |
| `internal sealed class` | `WindowsBleScanner` | Impl. Windows |
| `internal sealed class` | `PluginBleHardware` | Impl. Mobile |
| `internal static class` | `BleFramingHelper` | Helper framing |
| `internal static class` | `BleMtuHelper` | Helper MTU |
| `internal sealed class` | `BleReassemblyBuffer` | Buffer riassemblaggio |

---

## Esempi

### ✅ Uso Corretto

```csharp
// Entry point - public sealed
public sealed class ProtocolStack : IAsyncDisposable, IDisposable
{
    // Properties espongono interfacce, non implementazioni
    public IProtocolLayer Physical => PhysicalInternal;
    
    // Accesso tipizzato interno per builder/tests
    internal PhysicalLayerClass PhysicalInternal { get; }
}

// Implementazione layer - internal sealed
internal sealed class DataLinkLayer : ProtocolLayerBase
{
    private readonly Crc16Calculator _crc;  // Campo privato
}

// Helper - internal sealed
internal sealed class Crc16Calculator
{
    public ushort Calculate(ReadOnlySpan<byte> data) => ...;
}

// Configurazione - public sealed derivata
public sealed class NetworkLayerConfiguration : LayerConfiguration
{
    public uint LocalDeviceId { get; set; }
}
```

### ❌ Uso Scorretto

```csharp
// ❌ Helper pubblico espone dettagli implementativi
public class Crc16Calculator { }

// ❌ Layer pubblico - dovrebbe essere internal
public class DataLinkLayer : ProtocolLayerBase { }

// ❌ Classe pubblica non sealed - ereditarietà accidentale
public class SomeConfiguration : LayerConfiguration { }

// ❌ ProtocolStack espone tipo concreto invece di interfaccia
public DataLinkLayer DataLink { get; }  // Sbagliato
public IProtocolLayer DataLink { get; } // Corretto
```

---

## Eccezioni

| Componente | Eccezione | Motivazione |
|------------|-----------|-------------|
| `LayerConfiguration` | Non-sealed | Base class per 6 configurazioni derivate |
| `ProtocolLayerBase` | Public abstract | Hook per layer custom (raramente usato) |
| `ChannelException` | Non-sealed | Base class per eccezioni specifiche |
| `CanHardwareException` | Non-sealed | Base class per eccezioni CAN |
| `BleHardwareException` | Non-sealed | Base class per eccezioni BLE |
| `RoutingTableManager` | Non-sealed internal | Mockato nei test (Moq richiede virtual/non-sealed) |
| `NetworkMetricsCollector` | Non-sealed internal | Mockato nei test |
| `RouteCalculator` | Non-sealed internal | Mockato nei test |
| `ApplicationMessageSerializer` | Public | Usato da Client per serializzazione messaggi |
| `DeviceIdCalculator` | Public | Utility necessaria agli utenti per calcolo SRID |

---

## Enforcement

### Automatico

- [x] **InternalsVisibleTo** in `Directory.Build.props`
- [ ] **TODO:** Roslyn Analyzer per verificare `sealed` su classi pubbliche
- [ ] **TODO:** API surface tracking con PublicApiAnalyzers

### Code Review Checklist

- [ ] Nuove classi pubbliche hanno motivazione documentata?
- [ ] Classi pubbliche sono `sealed` (o hanno motivazione per non esserlo)?
- [ ] Helper/utility sono `internal`?
- [ ] Implementazioni layer sono `internal sealed`?
- [ ] Test usano `InternalsVisibleTo` invece di rendere pubblico?

---

## Metriche

| Metrica | Prima (T-017) | Dopo T-017 | Dopo F-001 | Cambiamento |
|---------|---------------|------------|------------|-------------|
| Tipi pubblici | 78 | 55 | 65 | +10 (BLE API) |
| Classi sealed | ~3 | ~40 | ~45 | +5 |
| Helper internal | ~5 | ~35 | ~42 | +7 |

---

## Riferimenti

- [Microsoft .NET Design Guidelines](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/)
- [Framework Design Guidelines (Cwalina)](https://www.informit.com/store/framework-design-guidelines)
- [NuGet API Best Practices](https://docs.microsoft.com/en-us/nuget/create-packages/best-practices)

---

## Changelog

| Data | Versione | Descrizione |
|------|----------|-------------|
| 2026-02-11 | 1.0 | Definizione iniziale standard |
| 2026-02-12 | 2.0 | Consolidamento post-migrazione T-017: eccezioni documentate, metriche aggiornate, formato allineato a STANDARD_TEMPLATE |
| 2026-02-17 | 2.1 | Aggiunta sezione Drivers.Ble API (F-001): 10 tipi pubblici, 7 internal, metriche aggiornate |

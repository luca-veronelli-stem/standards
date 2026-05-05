# Tests - STEM Communication Protocol

> **Test unitari e di integrazione per il protocollo STEM.**  

> **Ultimo aggiornamento:** 2026-02-26

---

## Stato Attuale

| Metrica | Valore |
|---------|--------|
| **Test Totali** | ~2616 |
| **Passati** | ~2602 ✅ |
| **Skipped** | ~14 |
| **Durata** | ~6 secondi |
| **Framework** | xUnit 2.9.3 |
| **Mocking** | Moq 4.20.72 |

### Distribuzione

| Tipo | Quantita | Percentuale |
|------|----------|-------------|
| **Unit Test** | ~2510 | 96% |
| **Integration Test** | ~106 | 4% |

---

## Target Framework

```xml
<TargetFramework>net10.0</TargetFramework>
```

### Limitazioni Multi-Platform (BLE-020)

Il progetto `Drivers.Ble` usa **multi-targeting**:
- `net10.0` → Plugin.BLE per mobile (Android, iOS)
- `net10.0-windows10.0.19041.0` → API native Windows

Il progetto `Tests` compila solo per `net10.0`, quindi:

| Componente | Testabile Direttamente | Note |
|------------|------------------------|------|
| `PluginBleHardware` | ✅ Sì | Disponibile in `net10.0` |
| `WindowsBleHardware` | ❌ No | Escluso dalla compilazione `net10.0` |
| `IBleHardware` (contratto) | ✅ Sì | Testato con mock |
| `BleChannelDriverFactory` | ✅ Sì | Validazione parametri |
| `BleChannelDriver` | ✅ Sì | Con mock di `IBleHardware` |

**Nota:** `InternalsVisibleTo` non risolve il problema perché `WindowsBleHardware` è `public`, 
ma il codice non esiste nel target `net10.0`. Per test diretti su `WindowsBleHardware` 
servirebbe un progetto test separato con target `net10.0-windows`.

I test attuali verificano il **contratto `IBleHardware`** che `WindowsBleHardware` implementa.
Se i test del contratto passano e `WindowsBleHardware` compila, c'è buona confidenza sul comportamento.

---

## Struttura

```
Tests/
├── Unit/
│   ├── Drivers/
│   │   ├── Can/              # Test CanChannelDriver, CanFrame, etc.
│   │   └── Ble/              # Test BleChannelDriver, etc.
│   └── Protocol/
│       ├── Infrastructure/   # Test ChannelType, etc.
│       └── Layers/
│           ├── ApplicationLayer/
│           ├── PresentationLayer/
│           ├── SessionLayer/
│           ├── TransportLayer/
│           ├── NetworkLayer/
│           ├── DataLinkLayer/
│           ├── PhysicalLayer/
│           ├── Base/
│           └── Stack/
│
├── Integration/
│   ├── Drivers/              # PhysicalLayer + Driver
│   └── Protocol/Layers/      # Layer adiacenti, full stack
│
└── Tests.csproj
```

### Test Recenti (STK-012)

Con STK-012 sono stati aggiunti test per eventi `ConnectionStateChanged`:

| File | Test Aggiunti | Focus |
|------|---------------|-------|
| `ConnectionStateTests.cs` | 25 | Enum values, EventArgs invarianti |
| `BleChannelDriverTests.cs` | 8 | Eventi su connect/disconnect/reconnect |
| `CanChannelDriverTests.cs` | 4 | Eventi su connect/disconnect |
| `PhysicalLayerTests.cs` | 4 | Propagazione eventi da driver |
| `ProtocolStackTests.cs` | 3 | Evento esposto su stack |

---

## Copertura per Componente

| Componente | Test | Focus Principale |
|------------|------|------------------|
| **ApplicationLayer** | ~180 | Comandi, handler, variabili |
| **PresentationLayer** | ~95 | Crittografia, padding |
| **SessionLayer** | ~120 | State machine, SRID |
| **TransportLayer** | ~140 | Chunking, riassemblaggio |
| **NetworkLayer** | ~160 | Routing, broadcast, discovery |
| **DataLinkLayer** | ~150 | Frame, CRC16, parsing |
| **PhysicalLayer** | ~105 | Buffer, I/O, eventi connessione |
| **Base** | ~60 | LayerResult, Context, Config |
| **Stack** | ~155 | Builder, orchestrazione, eventi |
| **Infrastructure** | ~25 | ConnectionState, EventArgs |
| **Drivers.Can** | ~135 | Chunking CAN, NetInfo, eventi |
| **Drivers.Ble** | ~660 | MTU, auto-reconnect, factory, eventi |
| **Integration** | ~100 | Layer adiacenti, full stack |

### Test Skippati

Alcuni test sono marcati come `[Fact(Skip = "...")]` perché:

| Motivo | Test Coinvolti |
|--------|----------------|
| Richiede hardware BLE reale | ~4 |
| BLE-019: Chunking MTU header | ~10 |

---

## Esecuzione

```bash
# Tutti i test
dotnet test

# Layer specifico
dotnet test --filter "FullyQualifiedName~NetworkLayer"

# Solo unit test
dotnet test --filter "FullyQualifiedName~Unit"

# Solo integration test
dotnet test --filter "FullyQualifiedName~Integration"

# Con coverage
dotnet test --collect:"XPlat Code Coverage"
```

---

## Convenzioni

### Naming

```
<Metodo>_<Scenario>_<Comportamento>
```

Esempi:
- `InitializeAsync_WithValidConfig_ShouldSucceed`
- `ProcessUpstreamAsync_WhenNotInitialized_ShouldReturnError`
- `Serialize_WithAckFlag_ShouldSetBit15`

### Pattern AAA

```csharp
[Fact]
public async Task MethodName_Scenario_ExpectedBehavior()
{
    // Arrange
    var layer = new ApplicationLayer();
    await layer.InitializeAsync(config);

    // Act
    layer.Shutdown();

    // Assert
    Assert.False(layer.IsInitialized);
}
```

### Theory per Test Parametrici

```csharp
[Theory]
[InlineData(0, 1)]
[InlineData(1, 2)]
[InlineData(255, 256)]
public void GetSize_ForType_ShouldReturnCorrectSize(int dataType, int expectedSize)
{
    // ...
}
```

### Mock con Moq

```csharp
var mockVariableMap = new Mock<IVariableMap>();
mockVariableMap
    .Setup(m => m.ReadAsync(It.IsAny<ushort>()))
    .ReturnsAsync(new byte[] { 0x42 });

var handler = new ReadLogicalVariableHandler(mockVariableMap.Object);
```

---

## Aggiungere Test

### Unit Test

1. Crea file `<Componente>Tests.cs` nella cartella appropriata
2. Segui convenzioni naming
3. Usa pattern AAA

```csharp
namespace Tests.Unit.Protocol.Layers.ApplicationLayer;

public class NomeComponenteTests
{
    [Fact]
    public void Metodo_Scenario_Comportamento()
    {
        // Arrange
        // Act
        // Assert
    }
}
```

### Integration Test

1. Usa cartella `Integration/`
2. Testa interazione tra layer adiacenti
3. Usa mock per hardware

### Verifica

```bash
dotnet test
dotnet build --warnaserror
```

---

## Links

- [Protocol/README.md](../Protocol/README.md)
- [Protocol/ISSUES.md](../Protocol/ISSUES.md)
- [xUnit Docs](https://xunit.net/docs/getting-started/netcore/cmdline)
- [Moq Quickstart](https://github.com/moq/moq4/wiki/Quickstart)

## Licenza

- **Proprietario:** STEM E.m.s.
- **Autore:** Luca Veronelli (l.veronelli@stem.it)
- **Data di Creazione:** 2026-01-26
- **Licenza:** Proprietaria - Tutti i diritti riservati

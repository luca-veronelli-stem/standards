# Standard Interface Design - Criteri per Definizione Interfacce

> **Versione:** 1.0  
> **Data:** 2026-02-13  
> **Riferimento Issue:** -  
> **Stato:** Active

---

## Scopo

Questo standard definisce i criteri per decidere **quando** creare un'interfaccia per una classe, garantendo:

- **Pragmatismo:** Interfacce solo dove apportano valore reale
- **Testabilità:** Mock solo per dipendenze esterne o complesse
- **Semplicità:** Evitare over-engineering (YAGNI)

Si applica a: tutte le classi in Protocol/, Drivers.Can/, Drivers.Ble/.

---

## Principi Guida

1. **Valore reale:** Creare interfacce solo quando risolvono un problema concreto
2. **Test pragmatici:** Helper deterministici si testano direttamente, non servono mock
3. **YAGNI:** Non creare interfacce "perché potrebbero servire"
4. **Contratti stabili:** Le interfacce pubbliche sono contratti API da mantenere
5. **DI mirato:** Dependency injection solo per dipendenze esterne/hardware

---

## Regole

### Quando DEVE Esistere un'Interfaccia

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| IF-001 | ✅ DEVE | API pubblica consumata da esterni → interfaccia |
| IF-002 | ✅ DEVE | Dipendenza hardware/I/O da mockare nei test → interfaccia |
| IF-003 | ✅ DEVE | Più implementazioni reali esistenti → interfaccia |
| IF-004 | ✅ DEVE | Plugin/estensione point → interfaccia |
| IF-005 | ✅ DEVE | Dependency injection dall'esterno → interfaccia |

### Quando PUÒ Esistere un'Interfaccia

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| IF-010 | 💡 PUÒ | Helper con stato complesso + eventi → interfaccia (per isolamento test) |
| IF-011 | 💡 PUÒ | Algoritmo potenzialmente sostituibile → interfaccia |

### Quando NON DEVE Esistere un'Interfaccia

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| IF-020 | ❌ NON DEVE | DTO/Model senza comportamento → NO interfaccia |
| IF-021 | ❌ NON DEVE | Helper statico/stateless → NO interfaccia |
| IF-022 | ❌ NON DEVE | Result type / struct immutabile → NO interfaccia |
| IF-023 | ❌ NON DEVE | Configuration class (solo dati + Validate) → NO interfaccia |
| IF-024 | ❌ NON DEVE | Solo per "poter mockare" helper deterministico → NO interfaccia |

---

## Matrice Decisionale

| Caratteristica | Interfaccia? | Esempio |
|----------------|:------------:|---------|
| Hardware/I/O esterno | ✅ | `IChannelDriver`, `ICanHardware` |
| API pubblica/contratto | ✅ | `IProtocolLayer`, `ILayerStatistics` |
| Più implementazioni | ✅ | `ICommandHandler` (4 handler) |
| Iniettato dall'esterno | ✅ | `IVariableMap`, `IChannelConfiguration` |
| Stato + eventi complessi | 💡 | `IBroadcastManager` |
| Helper deterministico | ❌ | `PacketChunker`, `Crc16Calculator` |
| DTO/Model | ❌ | `DataLinkFrame`, `TransportChunk` |
| Struct Result | ❌ | `ParseResult`, `ReassemblyResult` |
| Classe Configuration | ❌ | `TransportLayerConfiguration` |

### Nota: Configuration Classes

| Tipo | Interfaccia? | Motivo |
|------|:------------:|--------|
| `IChannelConfiguration` | ✅ | Passata a `IChannelDriver.InitializeAsync()` (DI esterno) |
| `LayerConfiguration` | ❌ | Classe base, layer fa cast a tipo concreto |
| `*LayerConfiguration` | ❌ | Solo dati + `Validate()`, nessun polimorfismo richiesto |

---

## Esempi

### ✅ Uso Corretto - Interfaccia per hardware

```csharp
// Hardware esterno → DEVE avere interfaccia per mock nei test
public interface ICanHardware
{
    Task<bool> InitializeAsync(CanConfiguration config);
    Task WriteAsync(uint canId, byte[] data, CancellationToken ct);
    event EventHandler<CanMessageReceivedEventArgs> MessageReceived;
}

// Driver implementa l'interfaccia
public class PcanHardware : ICanHardware { ... }

// Test può mockare
var mockHardware = new Mock<ICanHardware>();
var driver = new CanChannelDriver(mockHardware.Object);
```

### ✅ Uso Corretto - Interfaccia per API pubblica

```csharp
// Contratto stabile per consumatori esterni
public interface IProtocolLayer
{
    Task<LayerResult> ProcessUpstreamAsync(byte[] data, LayerContext context);
    Task<LayerResult> ProcessDownstreamAsync(byte[] data, LayerContext context);
}

// Tutti i layer implementano
internal sealed class TransportLayer : ProtocolLayerBase { ... }
```

### ✅ Uso Corretto - Interfaccia per helper con stato complesso

```csharp
// Helper con cache, eventi, timer → interfaccia per isolamento
public interface IBroadcastManager
{
    bool IsDuplicate(uint senderId, byte[] data);
    event EventHandler<int> BuffersTimedOut;
}

// Permette test isolati del NetworkLayer
var mockBroadcast = new Mock<IBroadcastManager>();
mockBroadcast.Setup(b => b.IsDuplicate(It.IsAny<uint>(), It.IsAny<byte[]>()))
             .Returns(false);
```

### ❌ Uso Scorretto - Interfaccia per helper deterministico

```csharp
// ❌ NON fare: interfaccia inutile per helper stateless
public interface IPacketChunker  // INUTILE!
{
    List<TransportChunk> CreateChunks(byte[] payload, uint destinationId);
}

// Il test può usare direttamente l'implementazione
var chunker = new PacketChunker(chunkSize: 200);
var chunks = chunker.CreateChunks(payload, destId);
Assert.Equal(5, chunks.Count);  // Test deterministico, no mock necessario
```

### ❌ Uso Scorretto - Interfaccia per DTO

```csharp
// ❌ NON fare: interfaccia per struttura dati
public interface IDataLinkFrame  // INUTILE!
{
    CryptType Crypt { get; set; }
    uint SenderId { get; set; }
    byte[] Data { get; set; }
}

// I DTO sono strutture dati, non comportamenti
```

---

## Stato Attuale nel Progetto

### Interfacce Esistenti (Conformi)

| Interfaccia | Categoria | Regola | Motivo |
|-------------|-----------|:------:|--------|
| `IProtocolLayer` | API pubblica | IF-001 | Contratto layer |
| `ILayerStatistics` | API pubblica | IF-001 | Contratto statistiche |
| `IChannelDriver` | Hardware | IF-002 | Mock driver nei test |
| `IChannelConfiguration` | DI esterno | IF-005 | Polimorfismo config driver |
| `ICanHardware` | Hardware | IF-002 | Mock PCAN |
| `IBleHardware` | Hardware | IF-002 | Mock BLE |
| `ICommandHandler` | Plugin | IF-003/IF-004 | 4+ implementazioni |
| `IAckHandler` | Plugin | IF-004 | Estensione point |
| `IVariableMap` | DI esterno | IF-005 | Iniettato dall'utente |
| `IBroadcastManager` | Stato complesso | IF-010 | Isolamento test NetworkLayer |
| `IDeviceDiscoveryService` | Stato complesso | IF-010 | Isolamento test NetworkLayer |

### Classi Senza Interfaccia (Conformi)

| Classe | Categoria | Regola | Motivo NO interfaccia |
|--------|-----------|:------:|----------------------|
| `PacketChunker` | Helper | IF-021 | Deterministico, test diretto |
| `ChunkReassembler` | Helper | IF-024 | Test diretto, no mock necessario |
| `Crc16Calculator` | Helper statico | IF-021 | Puro, deterministico |
| `DataLinkFrameBuilder` | Helper | IF-021 | Metodi statici |
| `DataLinkFrame` | DTO | IF-020 | Solo dati |
| `TransportChunk` | DTO | IF-020 | Solo dati |
| `ParseResult` | Result type | IF-022 | Struct immutabile |
| `ReassemblyResult` | Result type | IF-022 | Struct immutabile |
| `LayerConfiguration` | Config | IF-023 | Classe base dati |
| `*LayerConfiguration` | Config | IF-023 | Solo dati + Validate() |

---

## Test: Come Testare Senza Mock

Per helper senza interfaccia, usare test diretti:

```csharp
// Test ChunkReassembler senza mock - funziona perfettamente
[Fact]
public void AddChunk_CompletePacket_ShouldReturnPayload()
{
    // Arrange - usa implementazione reale
    var reassembler = new ChunkReassembler();
    var chunk = CreateChunk(packetId: 1, remaining: 0, data: [0xAA]);

    // Act
    var result = reassembler.AddChunk(chunk);

    // Assert
    Assert.True(result.IsComplete);
    Assert.Equal([0xAA], result.Payload);
}

// Test PacketChunker senza mock
[Fact]
public void CreateChunks_LargePayload_ShouldSplitCorrectly()
{
    // Arrange
    var chunker = new PacketChunker(chunkSize: 200);
    var payload = new byte[1000];

    // Act
    var chunks = chunker.CreateChunks(payload, destinationId: 0x123);

    // Assert
    Assert.Equal(5, chunks.Count);  // 1000 / 200 = 5 chunk
}
```

---

## Eccezioni

Nessuna eccezione - tutte le interfacce esistenti seguono i criteri definiti.

---

## Enforcement

- [x] **Code Review:** Verificare che nuove interfacce seguano i criteri
- [x] **Code Review:** Rifiutare interfacce per helper deterministici
- [ ] **Analyzer:** Nessuno (decisione di design, non automatizzabile)

---

## Riferimenti

- [VISIBILITY_STANDARD.md](./VISIBILITY_STANDARD.md) - Visibilità classi/interfacce
- [LIFECYCLE_STANDARD.md](./LIFECYCLE_STANDARD.md) - Creazione helper (correlato)
- `Protocol/Infrastructure/` - Interfacce driver
- `Protocol/Layers/Base/Interfaces/` - Interfacce layer

---

## Changelog

| Data | Versione | Descrizione |
|------|----------|-------------|
| 2026-02-13 | 1.0 | Versione iniziale - criteri per interfacce |

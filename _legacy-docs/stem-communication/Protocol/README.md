# Protocol - Stack Protocollare STEM

> **Libreria .NET 10 che implementa lo stack protocollare STEM a 7 layer OSI per comunicazione con dispositivi embedded.**  

> **Ultimo aggiornamento:** 2026-02-26

---

## Panoramica

Il progetto **Protocol** e la libreria principale che implementa lo stack protocollare STEM. Fornisce un'architettura a 7 layer (modello OSI) per la comunicazione affidabile tra applicazioni .NET e dispositivi embedded STEM.

La libreria e una riscrittura moderna in C# del protocollo originale in C, mantenendo **compatibilita binaria** con il firmware esistente.

---

## Caratteristiche

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **Architettura OSI** | ✅ | 7 layer indipendenti + Stack container |
| **Connection Events** | ✅ | Eventi ConnectionStateChanged (STK-012) |
| **CancellationToken** | ✅ NEW | Cancellation su tutti i layer e interfacce (T-024) |
| **ConfigureAwait** | ✅ NEW | ConfigureAwait(false) per library code (T-019) |
| **Async-First** | ✅ | Tutte le operazioni I/O asincrone |
| **Thread-Safe** | ✅ | Pattern T-005 standardizzato |
| **Multi-Canale** | ✅ | UART, CAN, BLE, Cloud |
| **Compatibilita C** | ✅ | Binario compatibile con firmware STEM |
| **Testabilita** | ✅ | 2602 test, mock layer-specifici |
| **Osservabilita** | ✅ | Logging strutturato + statistiche |

---

## Requisiti

- **.NET 10.0** o superiore

### Dipendenze

| Package | Versione | Uso |
|---------|----------|-----|
| Microsoft.Extensions.Logging.Abstractions | 9.0.0 | Logging strutturato |

---

## Quick Start

### Con ProtocolStackBuilder (Consigliato)

```csharp
using Protocol.Layers.Stack;
using Protocol.Layers.Base.Enums;

// 1. Crea il driver del canale (fornito dall'applicazione)
var canDriver = new CanChannelDriver(hardware);

// 2. Costruisci lo stack con il builder fluent
var stack = new ProtocolStackBuilder()
    .WithLocalDeviceId(0x00030141)
    .WithChannelDriver(canDriver)
    .WithEncryption(CryptType.AES128, aesKey)
    .Build();

// 3. Inizializza
await stack.InitializeAsync();

// 4. Gestisci eventi connessione (STK-012)
stack.ConnectionStateChanged += (s, e) =>
{
    Console.WriteLine($"Connection: {e.PreviousState} -> {e.CurrentState}");
    if (e.CurrentState == ConnectionState.Disconnected && !e.WasExpected)
        Console.WriteLine($"Lost connection: {e.Reason}");
};

// 5. Invia/Ricevi
await stack.SendAsync(data, destinationId);
var received = await stack.ReceiveAsync();

// 6. Cleanup
await stack.DisposeAsync();
```

### Layer-by-Layer (Avanzato)

```csharp
using Protocol.Layers.ApplicationLayer;

var appLayer = new ApplicationLayer();
await appLayer.InitializeAsync(new ApplicationLayerConfiguration 
{ 
    LocalDeviceId = 0x12345678 
});

var result = await appLayer.ProcessDownstreamAsync(data, context);
```

---

## API / Componenti

### Architettura

```
┌─────────────────────────────────────────────────────────────┐
│                      ProtocolStack                          │
├─────────────────────────────────────────────────────────────┤
│  │ Application (7)  │ Comandi STEM, variabili, ACK          │
│  │ Presentation (6) │ Crittografia AES-128 ECB              │
│  │ Session (5)      │ Gestione sessioni, SRID, heartbeat    │
│  │ Transport (4)    │ Chunking, riassemblaggio              │
│  │ Network (3)      │ Routing, broadcast, discovery         │
│  │ DataLink (2)     │ Framing, CRC16 Modbus                 │
│  │ Physical (1)     │ Buffer, I/O canale                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                       IChannelDriver
                   (CAN, BLE, UART, Cloud)
```

### Layer

| Layer | Componenti Principali | Responsabilità |
|-------|----------------------|----------------|
| **Application (L7)** | CommandHandlerRegistry, VariableMap | 43 comandi STEM, variabili logiche |
| **Presentation (L6)** | CryptoProvider, AesEncryptor | Crittografia AES-128 ECB |
| **Session (L5)** | SessionManager, StateMachine | Sessioni, SRID, heartbeat |
| **Transport (L4)** | PacketChunker, ChunkReassembler | Frammentazione, PacketId 1-7 |
| **Network (L3)** | RoutingTable, BroadcastManager | Routing multi-hop, discovery |
| **DataLink (L2)** | FrameBuilder, CRC16Calculator | Framing, integrità CRC16 |
| **Physical (L1)** | ProtocolTxBuffer, ProtocolRxBuffer | Buffer I/O, IChannelDriver |
| **Base** | IProtocolLayer, ProtocolLayerBase | Interfacce comuni |
| **Stack** | ProtocolStackBuilder | Orchestrazione, builder fluent |
| **Infrastructure** | IChannelDriver, ChannelType | Contratti per driver |

### Interfacce Principali

```csharp
// Interfaccia comune per tutti i layer
public interface IProtocolLayer : IDisposable
{
    Task<bool> InitializeAsync(LayerConfiguration? config = null);
    Task<LayerResult> ProcessUpstreamAsync(byte[] data, LayerContext context);
    Task<LayerResult> ProcessDownstreamAsync(byte[] data, LayerContext context);
    void Shutdown();
}

// Contratto per driver di canale
public interface IChannelDriver : IAsyncDisposable
{
    Task<bool> ConnectAsync(PhysicalLayerConfiguration config, CancellationToken ct);
    Task<byte[]?> ReadAsync(CancellationToken ct);
    Task<int> WriteAsync(byte[] data, CancellationToken ct);
    bool IsConnected { get; }
    ChannelType ChannelType { get; }
}
```

---

## Struttura

```
Protocol/
├── Layers/
│   ├── Base/                    # IProtocolLayer, ProtocolLayerBase
│   ├── PhysicalLayer/           # Layer 1
│   ├── DataLinkLayer/           # Layer 2
│   ├── NetworkLayer/            # Layer 3
│   ├── TransportLayer/          # Layer 4
│   ├── SessionLayer/            # Layer 5
│   ├── PresentationLayer/       # Layer 6
│   ├── ApplicationLayer/        # Layer 7
│   └── Stack/                   # ProtocolStack, Builder
├── Infrastructure/              # IChannelDriver, ChannelType
├── Docs/                        # Documentazione tecnica
└── ISSUES.md                    # Issue tracking
```

---

## Issue Correlate

→ [ISSUES.md](./ISSUES.md)

### Riepilogo

| Componente | Aperte | Risolte | Totale |
|------------|--------|---------|--------|
| ApplicationLayer | 10 | 8 | 18 |
| PresentationLayer | 8 | 8 | 16 |
| SessionLayer | 9 | 6 | 15 |
| TransportLayer | 10 | 7 | 17 |
| NetworkLayer | 12 | 8 | 20 |
| DataLinkLayer | 6 | 6 | 12 |
| PhysicalLayer | 6 | 9 | 15 |
| Base | 0 | 2 | 2 |
| Stack | 10 | 2 | 12 |
| Infrastructure | 3 | 2 | 5 |
| **Totale** | **74** | **58** | **132** |

### Issue Aperte Principali

| ID | Titolo | Priorita |
|----|--------|----------|
| AL-003 | Multi-Device Support Limitato | Alta |
| SL-015 | UpdateRemoteDevice Non Gestisce Broadcast | Alta |
| DL-002 | Validazione Input Builder | Alta |
| CAN-003 | Race Condition InitializeAsync | Alta |
| T-014 | Unificazione NetInfoCodec tra Driver | Media |
| T-015 | Architettura Chunking Driver vs TransportLayer | Media |

---

## Links

### README Layer

| Layer | README |
|-------|--------|
| Application (L7) | [README](Layers/ApplicationLayer/README.md) |
| Presentation (L6) | [README](Layers/PresentationLayer/README.md) |
| Session (L5) | [README](Layers/SessionLayer/README.md) |
| Transport (L4) | [README](Layers/TransportLayer/README.md) |
| Network (L3) | [README](Layers/NetworkLayer/README.md) |
| DataLink (L2) | [README](Layers/DataLinkLayer/README.md) |
| Physical (L1) | [README](Layers/PhysicalLayer/README.md) |
| Base | [README](Layers/Base/README.md) |
| Stack | [README](Layers/Stack/README.md) |
| Infrastructure | [README](Infrastructure/README.md) |

### Riferimenti Esterni

- **Firmware C:** `stem-fw-protocollo-seriale-stem/`
- **Bluetooth Firmware:** `stem-fw-bluetooth-5-bgm111/`

---

## Licenza

- **Proprietario:** STEM E.m.s.
- **Autore:** Luca Veronelli (l.veronelli@stem.it)
- **Data di Creazione:** 2026-01-26
- **Licenza:** Proprietaria - Tutti i diritti riservati

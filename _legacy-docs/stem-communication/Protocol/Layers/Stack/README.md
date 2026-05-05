# Stack - Orchestratore Protocollo STEM

## Panoramica

Lo **Stack** è il punto di ingresso principale per utilizzare il protocollo STEM. Fornisce un builder fluent per costruire e configurare lo stack, orchestrazione del flusso dati attraverso tutti i 7 layer OSI, e gestione unificata del lifecycle.

> **Ultimo aggiornamento:** 2026-02-24

---

## Responsabilità

- **Builder fluent** per costruzione dichiarativa dello stack
- **Orchestrazione flusso** dati attraverso i 7 layer OSI
- **Gestione lifecycle** unificata (init, shutdown, dispose)
- **Configurazione unificata** tramite `StackConfiguration`
- **API semplificata** per invio/ricezione messaggi

---

## Architettura

```
Stack/
├── ProtocolStack.cs                    # Orchestratore principale
├── ProtocolStackBuilder.cs             # Builder fluent
└── StackConfiguration.cs               # Configurazione unificata
```

### Relazione con i Layer

```
┌─────────────────────────────────────────────────────────────┐
│                      ProtocolStack                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              ProtocolStackBuilder                     │  │
│  │  .WithLocalDeviceId(0x12345678)                       │  │
│  │  .WithChannelDriver(canDriver)                        │  │
│  │  .WithEncryption(CryptType.AES128, key)               │  │
│  │  .Build()                                             │  │
│  └───────────────────────────────────────────────────────┘  │
│                            │                                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                   7 Layer OSI                         │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │ Application (7) │ Comandi, variabili, ACK       │  │  │
│  │  ├─────────────────────────────────────────────────┤  │  │
│  │  │ Presentation (6) │ Crittografia AES-128         │  │  │
│  │  ├─────────────────────────────────────────────────┤  │  │
│  │  │ Session (5) │ Gestione sessioni, SRID           │  │  │
│  │  ├─────────────────────────────────────────────────┤  │  │
│  │  │ Transport (4) │ Chunking, riassemblaggio        │  │  │
│  │  ├─────────────────────────────────────────────────┤  │  │
│  │  │ Network (3) │ Routing, broadcast                │  │  │
│  │  ├─────────────────────────────────────────────────┤  │  │
│  │  │ DataLink (2) │ Framing, CRC16                   │  │  │
│  │  ├─────────────────────────────────────────────────┤  │  │
│  │  │ Physical (1) │ Buffer, I/O canale               │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Componenti Principali

### ProtocolStack

Classe principale che orchestra il flusso dati attraverso tutti i layer.

```csharp
public class ProtocolStack : IDisposable, IAsyncDisposable
{
    public bool IsInitialized { get; }
    public bool IsConnected { get; }

    public Task<bool> InitializeAsync(CancellationToken ct = default);
    public Task UninitializeAsync(CancellationToken ct = default);

    public Task<bool> SendAsync(byte[] data, uint destinationId, CancellationToken ct = default);
    public Task<LayerResult> ReceiveAsync(CancellationToken ct = default);

    // Eventi (STK-012)
    public event EventHandler<ConnectionStateChangedEventArgs>? ConnectionStateChanged;

    // Accesso ai singoli layer
    public PhysicalLayer Physical { get; }
    public DataLinkLayer DataLink { get; }
    public NetworkLayer Network { get; }
    public TransportLayer Transport { get; }
    public SessionLayer Session { get; }
    public PresentationLayer Presentation { get; }
    public ApplicationLayer Application { get; }
}
```

#### Eventi ConnectionStateChanged (STK-012)

Lo stack propaga gli eventi di cambio stato connessione dal driver sottostante.

```csharp
stack.ConnectionStateChanged += (sender, e) =>
{
    Console.WriteLine($"Connection: {e.PreviousState} -> {e.CurrentState}");

    if (e.CurrentState == ConnectionState.Disconnected && !e.WasExpected)
    {
        if (e.WillAttemptReconnect)
            ShowStatus("Riconnessione in corso...");
        else
            ShowError($"Connessione persa: {e.Reason}");
    }
    else if (e.CurrentState == ConnectionState.Connected)
    {
        ShowStatus("Connesso");
    }
};
```

**Perché uno Stack Container?**

I singoli layer **non** chiamano automaticamente i layer adiacenti. Ogni layer:
- Riceve dati in input
- Applica le proprie trasformazioni
- Restituisce un `LayerResult`

È lo **Stack** che orchestra il flusso, chiamando ogni layer in sequenza.

### ProtocolStackBuilder

Builder fluent per costruire lo stack con validazione alla build.

```csharp
public class ProtocolStackBuilder
{
    public ProtocolStackBuilder WithLocalDeviceId(uint deviceId);
    public ProtocolStackBuilder WithChannelDriver(IChannelDriver driver);
    public ProtocolStackBuilder WithChannelType(ChannelType channelType);
    public ProtocolStackBuilder WithEncryption(CryptType cryptType, byte[]? key = null);
    public ProtocolStackBuilder WithRouting(bool enable, int maxHops = 5);
    public ProtocolStackBuilder WithHeartbeat(bool enable, TimeSpan? interval = null);
    public ProtocolStackBuilder WithConfiguration(StackConfiguration config);
    
    public ProtocolStack Build();
}
```

### StackConfiguration

Configurazione unificata che aggrega le configurazioni di tutti i layer.

---

## Configurazione

Classe: `StackConfiguration`

### Identificazione

| Proprietà | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `LocalDeviceId` | `uint` | **Obbligatorio** | SRID del dispositivo locale |

### Physical Layer

| Proprietà | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `ChannelType` | `ChannelType` | `CAN_CHANNEL` | Tipo canale |
| `PortName` | `string?` | `null` | Porta seriale (UART) |
| `BaudRate` | `int` | `500000` | Baud rate |
| `TxBufferSize` | `int` | `1100` | Buffer TX |
| `RxBufferSize` | `int` | `1100` | Buffer RX |

### Presentation Layer

| Proprietà | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `EncryptionType` | `CryptType` | `NO_CRYPT` | Tipo crittografia |
| `AesKey` | `byte[]?` | `null` | Chiave AES-128 (16 bytes) |

### Session Layer

| Proprietà | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `SessionTimeout` | `TimeSpan` | `600s` | Timeout sessione |
| `EnableHeartbeat` | `bool` | `false` | Abilita heartbeat |
| `HeartbeatInterval` | `TimeSpan` | `2s` | Intervallo heartbeat |

### Transport Layer

| Proprietà | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `ReassemblyTimeout` | `TimeSpan` | `30s` | Timeout riassemblaggio |
| `CleanupInterval` | `TimeSpan` | `10s` | Intervallo cleanup |

### Network Layer

| Proprietà | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `EnableRouting` | `bool` | `false` | Abilita routing multi-hop |
| `MaxHops` | `int` | `5` | Max hop per routing |
| `EnableBroadcast` | `bool` | `true` | Abilita gestione broadcast |

### Application Layer

| Proprietà | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `HandlerTimeout` | `TimeSpan` | `5s` | Timeout handler comandi |

---

## Flusso Dati

### Downstream (Trasmissione)

```
Applicazione
      │ SendAsync(data, destinationId)
      ▼
┌──────────────────────────────────────────────────────────┐
│ ProtocolStack                                            │
│ ─────────────────────────────────────────────────────── │
│ for each layer (7 → 1):                                  │
│   result = layer.ProcessDownstreamAsync(data, context)   │
│   data = result.Data                                     │
└──────────────────────────────────────────────────────────┘
      │
      ▼
Hardware (via IChannelDriver)
```

### Upstream (Ricezione)

```
Hardware (via IChannelDriver)
      │
      ▼
┌──────────────────────────────────────────────────────────┐
│ ProtocolStack                                            │
│ ─────────────────────────────────────────────────────── │
│ for each layer (1 → 7):                                  │
│   result = layer.ProcessUpstreamAsync(data, context)     │
│   data = result.Data                                     │
└──────────────────────────────────────────────────────────┘
      │ ReceiveAsync() returns data
      ▼
Applicazione
```

---

## Esempi di Utilizzo

### Configurazione Minima

```csharp
var driver = new CanChannelDriver(hardware);

var stack = new ProtocolStackBuilder()
    .WithLocalDeviceId(0x00030141)  // SRID_EDEN
    .WithChannelDriver(driver)
    .Build();

await stack.InitializeAsync();
```

### Configurazione Completa

```csharp
var driver = new CanChannelDriver(hardware);
var aesKey = new byte[16] { /* chiave */ };

var stack = new ProtocolStackBuilder()
    .WithLocalDeviceId(0x00030141)
    .WithChannelDriver(driver)
    .WithChannelType(ChannelType.CAN_CHANNEL)
    .WithEncryption(CryptType.AES128, aesKey)
    .WithRouting(enable: true, maxHops: 3)
    .WithHeartbeat(enable: true, interval: TimeSpan.FromSeconds(5))
    .Build();

await stack.InitializeAsync();
```

### Con StackConfiguration

```csharp
var config = new StackConfiguration
{
    LocalDeviceId = 0x00030141,
    ChannelType = ChannelType.CAN_CHANNEL,
    EncryptionType = CryptType.AES128,
    AesKey = aesKey,
    EnableRouting = true,
    MaxHops = 3,
    EnableHeartbeat = true,
    HeartbeatInterval = TimeSpan.FromSeconds(5)
};

var stack = new ProtocolStackBuilder()
    .WithChannelDriver(driver)
    .WithConfiguration(config)
    .Build();
```

### Invio/Ricezione

```csharp
// Invio
byte[] payload = Encoding.UTF8.GetBytes("Hello STEM");
bool success = await stack.SendAsync(payload, destinationId: 0x00030141);

// Ricezione
byte[]? received = await stack.ReceiveAsync();
if (received != null)
{
    Console.WriteLine($"Ricevuti {received.Length} bytes");
}
```

### Lifecycle

```csharp
using var stack = new ProtocolStackBuilder()
    .WithLocalDeviceId(0x00030141)
    .WithChannelDriver(driver)
    .Build();

try
{
    await stack.InitializeAsync();
    
    // Uso dello stack...
    
    await stack.ShutdownAsync();
}
finally
{
    // Dispose automatico con using
}
```

---

## Issue Correlate

→ [Stack/ISSUES.md](./ISSUES.md)

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| Alta | 0 | 1 |
| Media | 6 | 0 |
| Bassa | 4 | 0 |
| **Totale** | **10** | **1** |

### Issue Aperte Principali

| ID | Titolo | Priorità |
|----|--------|----------|
| STK-001 | Race Condition InitializeAsync/ShutdownAsync | Media |
| STK-005 | AesKey Array Mutabile Esposto | Media |
| STK-006 | Builder Build() Multipli Condividono Config | Media |
| STK-007 | Validazione Configurazione Incompleta | Media |

### Issue Correlate Trasversali

| ID | Titolo | Impatto |
|----|--------|---------|
| T-006 | Rimuovere Shutdown() + UninitializeAsync() | ProtocolStack.Shutdown() verrà rimosso |

---

## Links

- [Base README](../Base/README.md) - Interfacce e classi base

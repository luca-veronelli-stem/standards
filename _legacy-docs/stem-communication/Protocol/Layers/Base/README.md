# Base - Fondamenti dello Stack Protocollare

## Panoramica

La cartella **Base** contiene le interfacce, enumerazioni, modelli e classe base fondamentali che definiscono l'architettura dello stack protocollare STEM. Questi componenti costituiscono il contratto comune che tutti i layer devono rispettare.

> **Ultimo aggiornamento:** 2026-02-13

---

## Responsabilità

- **Definizione contratti** tramite interfacce (`IProtocolLayer`, `ILayerStatistics`)
- **Classe base astratta** con pattern IDisposable (`ProtocolLayerBase`)
- **Modelli condivisi** (`LayerContext`, `LayerResult`, `LayerConfiguration`)
- **Enumerazioni comuni** (`FlowDirection`, `CryptType`, `StemDevice`)
- **Costanti protocollo** condivise tra layer

---

## Architettura

```
Base/
├── ProtocolLayerBase.cs                # Classe base astratta per tutti i layer
├── Interfaces/
│   ├── IProtocolLayer.cs               # Contratto principale per i layer
│   └── ILayerStatistics.cs             # Contratto per statistiche
├── Models/
│   ├── LayerConfiguration.cs           # Configurazione base
│   ├── LayerContext.cs                 # Contesto di processamento
│   ├── LayerResult.cs                  # Risultato del processamento
│   ├── MessageMetadata.cs              # Metadata messaggi
│   └── ProtocolConstants.cs            # Costanti condivise
└── Enums/
    ├── FlowDirection.cs                # Upstream/Downstream
    ├── LayerStatus.cs                  # Stati risultato layer
    ├── CryptType.cs                    # Tipi crittografia
    └── StemDevice.cs                   # SRID dispositivi noti
```

---

## Componenti Principali

### Interface: IProtocolLayer

Interfaccia base che definisce il contratto per tutti i layer del protocollo.

```csharp
public interface IProtocolLayer : IDisposable
{
    string LayerName { get; }
    int LayerLevel { get; }
    bool IsInitialized { get; }
    ILayerStatistics? Statistics { get; }
    
    Task<bool> InitializeAsync(LayerConfiguration? config = null);
    void Shutdown();
    
    Task<LayerResult> ProcessUpstreamAsync(byte[] data, LayerContext context);
    Task<LayerResult> ProcessDownstreamAsync(byte[] data, LayerContext context);
    
    void AttachUpperLayer(IProtocolLayer? upperLayer);
    void AttachLowerLayer(IProtocolLayer? lowerLayer);
    
    IProtocolLayer? UpperLayer { get; }
    IProtocolLayer? LowerLayer { get; }
}
```

### Interface: ILayerStatistics

Contratto per le statistiche di ogni layer.

```csharp
public interface ILayerStatistics
{
    string LayerName { get; }
    DateTime StartTime { get; }
}
```

### Class: ProtocolLayerBase

Classe base astratta che implementa `IProtocolLayer` con pattern IDisposable completo.

**Caratteristiche:**
- ✅ Pattern `Dispose(bool disposing)` completo
- ✅ Metodo `ThrowIfDisposed()` per fail-fast
- ✅ Thread-safe con `volatile` e `Volatile.Read/Write` (T-005)
- ✅ Due lock separati: `_syncLock` e `_disposeLock`
- ✅ Template method `DisposeResources()` per cleanup specifico
- ✅ Finalizer di sicurezza

**Tutti i 7 layer ereditano da `ProtocolLayerBase`:**

| Layer | Livello OSI |
|-------|-------------|
| `ApplicationLayer` | 7 |
| `PresentationLayer` | 6 |
| `SessionLayer` | 5 |
| `TransportLayer` | 4 |
| `NetworkLayer` | 3 |
| `DataLinkLayer` | 2 |
| `PhysicalLayer` | 1 |

---

## Modelli

### LayerConfiguration

Classe base per la configurazione dei layer.

```csharp
public class LayerConfiguration
{
    public bool EnableDetailedLogging { get; set; } = false;
}
```

Ogni layer definisce la propria configurazione che eredita da `LayerConfiguration`:
- `PhysicalLayerConfiguration`
- `NetworkLayerConfiguration`
- `SessionLayerConfiguration`
- etc.

### LayerContext

Contesto passato durante il processamento dei dati.

```csharp
public class LayerContext
{
    public FlowDirection Direction { get; set; }
    public uint SenderId { get; set; }
    public uint DestinationId { get; set; }
    public CryptType CryptType { get; set; }
    
    public void SetMetadata(string key, object value);
    public T? GetMetadata<T>(string key);
}
```

### LayerResult

Risultato del processamento di un layer.

```csharp
public class LayerResult
{
    public bool IsSuccess { get; }
    public byte[] Data { get; }
    public LayerStatus Status { get; }
    public ProtocolError? ProtocolError { get; }
    public string? ErrorCode { get; }
    public string? ErrorMessage { get; }

    public static LayerResult Success(byte[] data);
    public static LayerResult Error(ProtocolError error, Exception? ex = null);
}
```

### MessageMetadata

Metadata associati a un messaggio.

```csharp
public record MessageMetadata(
    CryptType CryptType,
    uint SenderId
);
```

---

## Enumerazioni

### FlowDirection

Direzione del flusso dati nello stack.

| Valore | Descrizione |
|--------|-------------|
| `Upstream` | Da PhysicalLayer verso ApplicationLayer (ricezione) |
| `Downstream` | Da ApplicationLayer verso PhysicalLayer (trasmissione) |

### LayerStatus

Stati possibili del risultato di un layer.

| Valore | Descrizione |
|--------|-------------|
| `Success` | Operazione completata con successo |
| `Error` | Errore durante l'elaborazione |
| `Pending` | Operazione in attesa (es. chunk incompleto) |
| `Skipped` | Layer bypassato |

### CryptType

Tipi di crittografia supportati.

| Valore | Valore numerico | Descrizione |
|--------|-----------------|-------------|
| `NO_CRYPT` | `0` | Nessuna crittografia |
| `AES128` | `1` | AES-128 ECB |

### StemDevice

SRID dei dispositivi STEM noti.

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `SRID_EDEN` | `0x00030141` | Madre EDEN |
| `SRID_OPTIMUS` | `0x000200C1` | Madre OPTIMUS |
| `SRID_BROADCAST` | `0x1FFFFFFF` | Broadcast globale |
| ... | ... | Altri dispositivi |

---

## Pattern di Utilizzo

### Implementare un Nuovo Layer

```csharp
public class MyLayer : ProtocolLayerBase
{
    private readonly MyLayerStatistics _statistics = new();
    
    public MyLayer()
    {
        Statistics = _statistics;
    }
    
    public override string LayerName => "MyLayer";
    public override int LayerLevel => 8;  // Esempio
    
    public override async Task<bool> InitializeAsync(LayerConfiguration? config = null)
    {
        ThrowIfDisposed();
        
        var myConfig = config as MyLayerConfiguration ?? new MyLayerConfiguration();
        myConfig.Validate();
        
        // Inizializzazione...
        
        IsInitialized = true;
        return true;
    }
    
    public override Task<LayerResult> ProcessUpstreamAsync(byte[] data, LayerContext context)
    {
        ThrowIfDisposed();

        if (!IsInitialized)
            return Task.FromResult(LayerResult.Error(
                new ProtocolError("XX-INIT-001", "Not initialized", false)));

        // Processamento...

        return Task.FromResult(LayerResult.Success(processedData));
    }
    
    public override Task<LayerResult> ProcessDownstreamAsync(byte[] data, LayerContext context)
    {
        ThrowIfDisposed();
        
        // Processamento...
        
        return Task.FromResult(LayerResult.Success(processedData));
    }
    
    protected override void DisposeResources()
    {
        // Cleanup risorse specifiche
    }
}
```

### Usare LayerContext per Passare Metadata

```csharp
// Nel layer che imposta
context.SetMetadata("MessageMetadata", new MessageMetadata(CryptType.AES128, senderId));

// Nel layer che legge
var metadata = context.GetMetadata<MessageMetadata>("MessageMetadata");
if (metadata != null)
{
    Console.WriteLine($"Sender: 0x{metadata.SenderId:X8}");
}
```

---

## Thread Safety

`ProtocolLayerBase` implementa thread safety conforme a T-005:

| Campo | Tipo | Pattern |
|-------|------|---------|
| `_disposed` | `volatile bool` | Visibilità tra thread |
| `_isInitialized` | `bool` | `Volatile.Read/Write` |
| `_isShuttingDown` | `volatile bool` | Segnala dispose in corso |
| `_syncLock` | `Lock` | Operazioni normali |
| `_disposeLock` | `Lock` | Dispose non-blocking |

---

## Issue Correlate

→ [Base/ISSUES.md](./ISSUES.md)

| ID | Titolo | Priorità |
|----|--------|----------|
| BASE-001 | IProtocolLayer Non Eredita da IDisposable | Bassa |
| BASE-002 | LayerContext.Metadata Non Thread-Safe | Bassa |

**Totale aperte:** 2 | **Totale risolte:** 0

---

## Riferimenti Firmware C

| Componente C# | File C | Descrizione |
|---------------|--------|-------------|
| `IProtocolLayer` | N/A | Pattern C# specifico |
| `CryptType` | `SP_Crypto.h` | `SP_CRYPT_TYPE_t` |
| `StemDevice` | `SP_Application.h` | `StemDevices_t` |
| `SRID_BROADCAST` | `SP_Application.h` | `SRID_BROADCAST` |

**Repository:** `stem-fw-protocollo-seriale-stem/` (read-only)

---

## Links

- [Stack README](../Stack/README.md) - Orchestrazione layer

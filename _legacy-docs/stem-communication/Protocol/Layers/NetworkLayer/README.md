# Network Layer (Layer 3)

## Panoramica

Il **Network Layer** è il terzo livello dello stack protocollare STEM, corrispondente al Layer 3 del modello OSI. Si occupa del routing dei pacchetti, della gestione dei broadcast, della discovery dei dispositivi e della raccolta di metriche di rete.

> **Ultimo aggiornamento:** 2026-02-12

---

## Responsabilità

- **Routing multi-hop** con supporto per percorsi alternativi
- **Gestione broadcast** con prevenzione storm e deduplication
- **Device discovery** automatico e tracking stato dispositivi
- **Calcolo percorsi ottimali** basato su hop count e link quality
- **Forwarding pacchetti** con retry, rate limiting e priorità
- **Raccolta metriche** per diagnostica e monitoring della rete

---

## Architettura

```
NetworkLayer/
├── NetworkLayer.cs                     # Implementazione principale del layer
├── Helpers/
│   ├── RoutingTableManager.cs          # Gestione routing table thread-safe
│   ├── DeviceDiscoveryService.cs       # Discovery e tracking dispositivi
│   ├── BroadcastManager.cs             # Gestione broadcast con deduplication
│   ├── RouteCalculator.cs              # Calcolo percorsi ottimali
│   ├── NetworkMetricsCollector.cs      # Raccolta metriche di rete
│   └── PacketForwarder.cs              # Forwarding con retry e rate limiting
├── Models/
│   ├── NetworkLayerConfiguration.cs    # Configurazione runtime
│   ├── NetworkLayerConstants.cs        # Costanti (max hops, timeout)
│   ├── NetworkLayerStatistics.cs       # Statistiche unificate del layer
│   ├── RouteInfo.cs                    # Informazioni route
│   ├── DeviceInfo.cs                   # Informazioni dispositivo
│   └── EventArgs.cs                    # Event arguments personalizzati
├── Enums/
│   ├── RoutingStrategy.cs              # Strategie di routing
│   ├── PacketPriority.cs               # Livelli di priorità pacchetti
│   └── DeviceStatus.cs                 # Stati dispositivo
└── Interfaces/
    ├── IBroadcastManager.cs            # Interfaccia broadcast manager
    └── IDeviceDiscoveryService.cs      # Interfaccia discovery service
```

---

## Formato Dati

### Routing e Indirizzamento

Il Network Layer gestisce due tipi di comunicazione:

#### Unicast

Comunicazione point-to-point tra due dispositivi specifici:

```
Sender (SRID) ──► NetworkLayer ──► Destination (SRID)
                       │
                  RoutingTable
                       │
                  Next Hop
```

#### Broadcast

Comunicazione verso tutti i dispositivi della rete:

```
Sender (SRID) ──► NetworkLayer ──► SRID_BROADCAST (0x1FFFFFFF)
                       │
                 BroadcastManager
                       │
                Storm Prevention
```

**Indirizzo Broadcast:** `0x1FFFFFFF` (definito in `StemDevice.SRID_BROADCAST`)

---

## Componenti Principali

### NetworkLayer

Classe principale che eredita da `ProtocolLayerBase`. Orchestra tutti i componenti helper.

```csharp
public class NetworkLayer : ProtocolLayerBase
{
    public override string LayerName => "Network";
    public override int LayerLevel => 3;
    
    public event EventHandler<DeviceDiscoveredEventArgs>? DeviceDiscovered;
    public event EventHandler<RouteAddedEventArgs>? RouteAdded;
    public event EventHandler<LinkQualityDegradedEventArgs>? LinkQualityDegraded;
}
```

### Helper: RoutingTableManager

Gestisce la routing table con supporto multi-hop thread-safe.

**Metodi principali:**
- `AddRoute(RouteInfo)` - Aggiunge/aggiorna route
- `GetRoute(destinationId)` - Ottiene route per destinazione
- `GetBestRoute(destinationId)` - Ottiene route ottimale
- `RemoveExpiredRoutes()` - Rimuove route scadute

### Helper: BroadcastManager

Gestisce messaggi broadcast con deduplication e storm prevention.

**Metodi principali:**
- `ShouldProcess(broadcastId)` - Verifica se processare (dedup)
- `RecordBroadcast(broadcastId)` - Registra broadcast processato
- `CleanupExpired()` - Rimuove entry scadute

### Helper: DeviceDiscoveryService

Scopre e traccia dispositivi sulla rete.

**Metodi principali:**
- `StartDiscovery()` - Avvia discovery periodico
- `StopDiscovery()` - Ferma discovery
- `GetKnownDevices()` - Lista dispositivi noti
- `GetDeviceInfo(deviceId)` - Info su dispositivo specifico

### Helper: RouteCalculator

Calcola il percorso ottimale verso una destinazione.

**Strategie:**
- `ShortestPath` - Minimizza hop count
- `BestQuality` - Massimizza link quality
- `Balanced` - Bilancia hop e quality

### Helper: PacketForwarder

Inoltra pacchetti con retry e rate limiting.

**Metodi principali:**
- `Forward(packet, nextHop)` - Inoltra pacchetto
- `SetPriority(packet, priority)` - Imposta priorità

### Helper: NetworkMetricsCollector

Raccoglie metriche per dispositivo (latenza, packet loss, quality).

**Metodi principali:**
- `RecordPacketSent(deviceId)` - Registra pacchetto inviato
- `RecordPacketReceived(deviceId, latencyMs)` - Registra ricezione
- `GetDeviceMetrics(deviceId)` - Ottiene metriche dispositivo
- `GetAggregateStatistics()` - Statistiche aggregate

---

## Configurazione

Classe: `NetworkLayerConfiguration`

### Routing

| Proprietà | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `LocalDeviceId` | `uint` | `0` | SRID del dispositivo locale |
| `EnableRouting` | `bool` | `false` | Abilita routing multi-hop |
| `AllowedHops` | `int` | `5` | Max hop per routing (1-15) |
| `RoutingTableTimeout` | `TimeSpan` | `600s` | Timeout entry routing table |
| `MinLinkQuality` | `double` | `0.5` | Qualità minima link (0.0-1.0) |
| `MaxAlternativeRoutes` | `int` | `3` | Route alternative da considerare |

### Broadcast

| Proprietà | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `EnableBroadcast` | `bool` | `true` | Abilita gestione broadcast |
| `BroadcastHistorySize` | `int` | `100` | Dimensione storia dedup (10-1000) |
| `BroadcastTimeout` | `TimeSpan` | `60s` | Timeout cache broadcast |

### Device Discovery

| Proprietà | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `EnableDeviceDiscovery` | `bool` | `false` | Abilita discovery automatico |
| `DeviceDiscoveryInterval` | `TimeSpan` | `30s` | Intervallo tra scansioni |

### Forwarding

| Proprietà | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `MaxForwardRetries` | `int` | `3` | Max retry per forwarding |
| `AllowedForwardsPerSecond` | `int` | `100` | Rate limiting (10-10000) |
| `EnablePriorityQueue` | `bool` | `false` | Abilita coda priorità |

### Metriche

| Proprietà | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `LinkQualityThreshold` | `double` | `0.7` | Soglia alert quality (0.0-1.0) |
| `MaxLatencyMeasurements` | `int` | `100` | Misurazioni latenza per device |
| `EnableMetricsTrending` | `bool` | `false` | Abilita trending (più memoria) |

### Validazione

Il metodo `Validate()` verifica:
- `AllowedHops` tra 1 e 15
- `RoutingTableTimeout` tra 10s e 3600s
- `MinLinkQuality` tra 0.0 e 1.0
- `BroadcastHistorySize` tra 10 e 1000
- `AllowedForwardsPerSecond` tra 10 e 10000

### Esempio

```csharp
var config = new NetworkLayerConfiguration
{
    LocalDeviceId = 0x00030141,  // SRID_EDEN
    EnableRouting = true,
    AllowedHops = 3,
    EnableBroadcast = true,
    EnableDeviceDiscovery = true
};
config.Validate();
```

---

## Costanti

Classe: `NetworkLayerConstants`

### Costanti Protocollo

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `BROADCAST_ADDRESS` | `0x1FFFFFFF` | Indirizzo broadcast STEM |

### Valori Default - Routing

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `DEFAULT_ALLOWED_HOPS` | `5` | Max hop default |
| `DEFAULT_ROUTING_TABLE_TIMEOUT_SECONDS` | `600` | Timeout routing table |
| `DEFAULT_MIN_LINK_QUALITY` | `0.5` | Qualità minima link |
| `DEFAULT_MAX_ALTERNATIVE_ROUTES` | `3` | Route alternative |

### Valori Default - Broadcast

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `DEFAULT_BROADCAST_HISTORY_SIZE` | `100` | Storia dedup |
| `DEFAULT_BROADCAST_TIMEOUT_SECONDS` | `60` | Timeout cache |

### Valori Default - Forwarding

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `DEFAULT_MAX_FORWARD_RETRIES` | `3` | Max retry |
| `DEFAULT_ALLOWED_FORWARDS_PER_SECOND` | `100` | Rate limit |

### Limiti Validazione

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `MIN_ALLOWED_HOPS` | `1` | Hop minimo |
| `MAX_ALLOWED_HOPS` | `15` | Hop massimo |
| `MIN_BROADCAST_HISTORY_SIZE` | `10` | Storia minima |
| `MAX_BROADCAST_HISTORY_SIZE` | `1000` | Storia massima |

---

## Flusso Dati

### Downstream (Trasmissione)

```
TransportLayer (Layer 4)
      │
      ▼
┌──────────────────────────────┐
│   ProcessDownstreamAsync     │
│   ─────────────────────────  │
│   1. Verifica DestinationId  │
│   2. [Broadcast?] Dedup      │
│   3. [Unicast?] Get Route    │
│   4. Aggiorna metriche       │
│   5. Passa a layer inferiore │
└──────────────────────────────┘
      │
      ▼
DataLinkLayer (Layer 2)
```

### Upstream (Ricezione)

```
DataLinkLayer (Layer 2)
      │
      ▼
┌──────────────────────────────┐
│   ProcessUpstreamAsync       │
│   ─────────────────────────  │
│   1. Estrae SenderId         │
│   2. [Broadcast?] Dedup      │
│   3. Aggiorna routing table  │
│   4. Aggiorna metriche       │
│   5. [Forward?] Inoltra      │
│   6. Passa a layer superiore │
└──────────────────────────────┘
      │
      ▼
TransportLayer (Layer 4)
```

---

## Statistiche

Classe: `NetworkLayerStatistics`

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `TotalPacketsSent` | `long` | Pacchetti inviati totali |
| `TotalPacketsReceived` | `long` | Pacchetti ricevuti totali |
| `TotalPacketsLost` | `long` | Pacchetti persi totali |
| `ActiveDevices` | `int` | Dispositivi attivi tracciati |
| `AveragePacketLossRate` | `double` | Tasso medio perdita pacchetti |

### Accesso Metriche Avanzate

```csharp
var stats = (NetworkLayerStatistics)layer.Statistics;

// Statistiche base
Console.WriteLine($"Pacchetti inviati: {stats.TotalPacketsSent}");
Console.WriteLine($"Dispositivi attivi: {stats.ActiveDevices}");

// Metriche avanzate per dispositivo
var deviceMetrics = stats.MetricsCollector.GetDeviceMetrics(deviceId);
Console.WriteLine($"Latenza media: {deviceMetrics.AverageLatencyMs} ms");
Console.WriteLine($"Link quality: {deviceMetrics.LinkQuality}");
```

---

## Eventi

Il NetworkLayer espone i seguenti eventi (conformi a [EVENTARGS_STANDARD.md](../../../Docs/Standards/EVENTARGS_STANDARD.md)):

| Evento | EventArgs | Descrizione |
|--------|-----------|-------------|
| `DeviceDiscovered` | `DeviceDiscoveredEventArgs` | Nuovo dispositivo scoperto sulla rete |
| `DeviceLost` | `DeviceLostEventArgs` | Dispositivo non più raggiungibile |
| `RouteAdded` | `RouteAddedEventArgs` | Nuova route aggiunta alla routing table |
| `LinkQualityAlert` | `LinkQualityAlertEventArgs` | Qualità del link degradata |

### EventArgs

Tutti gli EventArgs includono `Timestamp` (UTC) per tracciamento temporale.

| EventArgs | Proprietà Principali |
|-----------|---------------------|
| `DeviceDiscoveredEventArgs` | `DeviceId`, `Context`, `Timestamp` |
| `DeviceLostEventArgs` | `DeviceId`, `Timestamp` |
| `RouteAddedEventArgs` | `DestinationId`, `NextHop`, `HopCount`, `Timestamp` |
| `LinkQualityAlertEventArgs` | `DeviceId`, `LinkQuality` (0.0-1.0), `Timestamp` |

---

## Esempi di Utilizzo

### Inizializzazione Base (Passthrough)

```csharp
var layer = new NetworkLayer();
await layer.InitializeAsync(new NetworkLayerConfiguration
{
    LocalDeviceId = 0x00030141
});
// Routing disabilitato, solo passthrough
```

### Con Routing Multi-Hop

```csharp
var config = new NetworkLayerConfiguration
{
    LocalDeviceId = 0x00030141,
    EnableRouting = true,
    AllowedHops = 5,
    MinLinkQuality = 0.6
};

var layer = new NetworkLayer();
await layer.InitializeAsync(config);

// Sottoscrivi eventi
layer.DeviceDiscovered += (s, e) => 
    Console.WriteLine($"Nuovo dispositivo: 0x{e.DeviceId:X8}");
layer.LinkQualityDegraded += (s, e) => 
    Console.WriteLine($"Quality degradata: {e.DeviceId} → {e.Quality}");
```

### Con Device Discovery

```csharp
var config = new NetworkLayerConfiguration
{
    LocalDeviceId = 0x00030141,
    EnableDeviceDiscovery = true,
    DeviceDiscoveryInterval = TimeSpan.FromSeconds(15)
};

var layer = new NetworkLayer();
await layer.InitializeAsync(config);

// Lista dispositivi noti
var devices = layer.DiscoveryService.GetKnownDevices();
foreach (var device in devices)
{
    Console.WriteLine($"Device: 0x{device.DeviceId:X8}, Status: {device.Status}");
}
```

---

## Issue Correlate

→ [NetworkLayer/ISSUES.md](./ISSUES.md)

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| Alta | 0 | 4 |
| Media | 2 | 3 |
| Bassa | 10 | 1 |
| **Totale** | **12** | **8** |

### Issue Aperte Principali

| ID | Titolo | Priorità |
|----|--------|----------|
| NL-007 | Export CSV Non Implementato | Media |
| NL-018 | BroadcastManager Clear() Non Atomico | Media |
| NL-008 | PacketForwarder Doppio Rate Limiting | Bassa |
| NL-009 | DeviceInfo/RouteInfo Non Immutabili | Bassa |

### Issue Correlate Trasversali

| ID | Titolo | Impatto |
|----|--------|---------|
| T-013 | Lifecycle Helper: Costruttore vs InitializeAsync | Helper creati con default, config ignorata |

---

## Riferimenti Firmware C

| Componente C# | File C | Struttura/Funzione |
|---------------|--------|-------------------|
| `NetworkLayer` | `SP_Network.c` | `SP_Net_*()` |
| `RoutingTableManager` | `SP_Network.c` | `SP_Net_RouteTable[]` |
| `BroadcastManager` | `SP_Network.c` | `SP_Net_BroadcastCache[]` |
| `BROADCAST_ADDRESS` | `SP_Application.h` | `SRID_BROADCAST` |

**Repository:** `stem-fw-protocollo-seriale-stem/` (read-only)

---

## Links

- [Stack README](../Stack/README.md) - Orchestrazione layer
- [Base README](../Base/README.md) - Interfacce e classi base

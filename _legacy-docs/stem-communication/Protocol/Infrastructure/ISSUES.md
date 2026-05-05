# Infrastructure - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunità di refactoring e violazioni di best practice per il componente **Infrastructure** (Interfacce base per driver di canale, eccezioni, configurazioni).  

> **Ultimo aggiornamento:** 2026-02-24

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 0 | 0 |
| **Media** | 0 | 0 |
| **Bassa** | 3 | 2 |

**Totale aperte:** 3  
**Totale risolte:** 2

---

## Indice Issue Aperte

- [INF-001 - ReadWithMetadataAsync Default Implementation Scorretta](#inf-001---readwithmetadataasync-default-implementation-scorretta)
- [INF-002 - IChannelConfiguration.Validate() Contratto Ambiguo](#inf-002---ichannelconfigurationvalidate-contratto-ambiguo)
- [INF-003 - ChannelStatistics.StartTime Non Resettabile](#inf-003---channelstatisticsstarttime-non-resettabile)

---

## Indice Issue Risolte

- [INF-004 - ChannelType Manca Valore UNKNOWN](#inf-004---channeltype-manca-valore-unknown)
- [INF-005 - IChannelDriver Non Eredita IDisposable](#inf-005---ichanneldriver-non-eredita-idisposable)

---

## Priorità Bassa

### INF-001 - ReadWithMetadataAsync Default Implementation Scorretta

**Categoria:** Bug  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-06  

#### Descrizione

L'implementazione di default di `ReadWithMetadataAsync` ritorna sempre `null` invece di delegare a `ReadAsync()` e wrappare il risultato.

Questo significa che driver che non override il metodo perdono completamente la funzionalità di lettura, invece di fornire backward compatibility senza metadati.

#### File Coinvolti

- `Protocol/Infrastructure/IChannelDriver.cs` (righe 69-74)

#### Codice Problematico

```csharp
Task<(byte[]? Data, ChannelMetadata? Metadata)?> ReadWithMetadataAsync(
    CancellationToken cancellationToken = default)
{
    // Default implementation per backward compatibility
    // I driver che supportano metadati devono sovrascrivere questo metodo
    return Task.FromResult<(byte[]? Data, ChannelMetadata? Metadata)?>(null);
}
```

#### Problema Specifico

- Driver legacy che non implementano metadati ritornano sempre `null`
- Caller è costretto a fallback manuale su `ReadAsync()`
- Documentazione promette backward compatibility ma non la fornisce

#### Soluzione Proposta

```csharp
async Task<(byte[]? Data, ChannelMetadata? Metadata)?> ReadWithMetadataAsync(
    CancellationToken cancellationToken = default)
{
    var data = await ReadAsync(cancellationToken);
    return data != null ? (data, null) : null;
}
```

#### Benefici Attesi

- Backward compatibility reale
- Driver legacy funzionano senza modifiche
- Caller non deve gestire due API

---

### INF-002 - IChannelConfiguration.Validate() Contratto Ambiguo

**Categoria:** Design / Documentation  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-06  
**Ultimo Aggiornamento:** 2026-02-11

#### Descrizione

`IChannelConfiguration.Validate()` non specifica:
- Chi è responsabile di chiamarla (driver? PhysicalLayer? StackBuilder?)
- Quando chiamarla (prima di ConnectAsync? alla creazione?)
- Cosa fare se validazione fallisce dopo che config è già in uso

#### Pattern Attuale (de-facto)

Con **PL-016** (2026-02-11), i driver ora chiamano `config.Validate()` nel costruttore:

```csharp
// Pattern comune BLE/CAN driver:
public CanChannelDriver(ICanHardware hw, CanConfiguration cfg, ILogger? log = null)
{
    _config = cfg ?? throw new ArgumentNullException(nameof(cfg));
    cfg.Validate(); // Fail-fast nel costruttore
}
```

Ma la documentazione in `IChannelConfiguration.Validate()` non è stata aggiornata per riflettere questo pattern.

#### File Coinvolti

- `Protocol/Infrastructure/IChannelConfiguration.cs` (righe 30-34)

#### Soluzione Proposta

Aggiornare la documentazione per riflettere il pattern PL-016:

```csharp
/// <summary>
/// Valida la configurazione prima dell'uso.
/// </summary>
/// <remarks>
/// <para><b>Contratto (PL-016):</b></para>
/// <list type="bullet">
///   <item><description>DEVE essere chiamato dal costruttore del driver (fail-fast)</description></item>
///   <item><description>PUÒ essere chiamato da StackBuilder.Build() per validazione early</description></item>
///   <item><description>Lancia ArgumentException con messaggio descrittivo se invalida</description></item>
/// </list>
/// </remarks>
/// <exception cref="ArgumentException">Se la configurazione non è valida.</exception>
void Validate();
```

#### Benefici Attesi

- Contratto chiaro
- Fail-fast consistente
- Comportamento predicibile

---

### INF-003 - ChannelStatistics.StartTime Non Resettabile

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-06  

#### Descrizione

`ChannelStatistics.Reset()` azzera tutti i contatori ma non resetta `StartTime`. Questo causa calcoli di throughput scorrett dopo `Reset()`.

#### File Coinvolti

- `Protocol/Infrastructure/ChannelStatistics.cs` (righe 23, 87-95)

#### Codice Problematico

```csharp
/// <summary>Timestamp di creazione delle statistiche.</summary>
public DateTime StartTime { get; } = DateTime.UtcNow;  // Read-only, non resettabile

public void Reset()
{
    Interlocked.Exchange(ref _bytesSent, 0);
    Interlocked.Exchange(ref _bytesReceived, 0);
    // ...
    // StartTime NON viene resettato
}
```

#### Problema Specifico

Dopo `Reset()`:
- `Uptime` continua dal `StartTime` originale
- `AverageTxThroughput` / `AverageRxThroughput` calcolano media su tempo totale, non dopo reset
- Throughput medio post-reset è diluito dal tempo precedente

#### Soluzione Proposta

**Opzione A: Resettare StartTime**
```csharp
private long _startTimeTicks = DateTime.UtcNow.Ticks;

public DateTime StartTime => new DateTime(Volatile.Read(ref _startTimeTicks), DateTimeKind.Utc);

public void Reset()
{
    // ... reset contatori ...
    Interlocked.Exchange(ref _startTimeTicks, DateTime.UtcNow.Ticks);
}
```

**Opzione B: LastResetTime separato**
```csharp
public DateTime StartTime { get; }  // Immutabile
public DateTime? LastResetTime { get; private set; }

public TimeSpan UptimeSinceReset => DateTime.UtcNow - (LastResetTime ?? StartTime);

public void Reset()
{
    // ... reset contatori ...
    LastResetTime = DateTime.UtcNow;
}
```

#### Benefici Attesi

- Throughput corretto dopo reset
- Statistiche più accurate per monitoring

---

### INF-004 - ChannelType Manca Valore UNKNOWN

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-02-06  
**Data Risoluzione:** 2026-02-10  
**Branch:** `fix/inf-004`

#### Descrizione

L'enum `ChannelType` non aveva un valore `UNKNOWN` per indicare che il tipo di canale non è stato specificato. `UART_CHANNEL = 0` era il primo valore, quindi una variabile non inizializzata aveva implicitamente quel valore.

#### Soluzione Implementata

Aggiunto `UNKNOWN = 0` con shift di tutti i valori esistenti:

```csharp
public enum ChannelType
{
    UNKNOWN = 0,       // Canale non specificato (INF-004)
    UART_CHANNEL = 1,  // Era 0
    CAN_CHANNEL = 2,   // Era 1
    CLOUD_CHANNEL = 3, // Era 2
    BLE_CHANNEL = 4,   // Era 3
}
```

**Analisi di compatibilità:**
- ? **Wire Protocol:** `ChannelType` non viene mai serializzato nei frame DataLink
- ? **Firmware C:** Ogni lato usa il suo enum localmente, non c'è scambio di valori
- ? **Pattern matching:** Il codice usa i nomi, non i valori numerici
- ?? **Test:** Aggiornati 3 test che verificavano valori espliciti

#### File Modificati

- `Protocol/Infrastructure/ChannelType.cs` (enum con UNKNOWN e valori shiftati)
- `Tests/Unit/Protocol/Infrastructure/ChannelTypeTests.cs` (test aggiornati + nuovi)

#### Test Aggiunti/Aggiornati

**ChannelTypeTests.cs (12 test totali):**
- `ChannelType_Unknown_ShouldHaveValueZero` - verifica UNKNOWN = 0 *(nuovo)*
- `ChannelType_Default_ShouldBeUnknown` - verifica default(ChannelType) = UNKNOWN *(nuovo)*
- `ChannelType_Uart_ShouldHaveValueOne` - aggiornato da 0 a 1
- `ChannelType_Can_ShouldHaveValueTwo` - aggiornato da 1 a 2
- `ChannelType_Cloud_ShouldHaveValueThree` - aggiornato da 2 a 3
- `ChannelType_Ble_ShouldHaveValueFour` - verifica BLE = 4 *(nuovo)*
- `ChannelType_ShouldHaveExactlyFiveValues` - aggiornato da 4 a 5
- `ChannelType_ShouldHaveCorrectNames` - aggiunto UNKNOWN e BLE_CHANNEL

#### Benefici Ottenuti

- `default(ChannelType)` ora è `UNKNOWN`, non un canale valido
- Configurazioni incomplete rilevabili con `Validate()`
- Fail-fast se ChannelType non specificato
- Semantica chiara: default = "non configurato"

#### Issue Correlate

- **PL-015:** Ora può usare `ChannelType.UNKNOWN` come default in `PhysicalLayerConfiguration`
- **PL-016:** Prerequisito per rimozione `BaudRate`/`PortName`

---

## Issue Risolte

### INF-005 - IChannelDriver Non Eredita IDisposable

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-02-10  
**Data Risoluzione:** 2026-02-10  
**Branch:** `fix/inf-005`

#### Descrizione

`IChannelDriver` eredita solo `IAsyncDisposable`, non `IDisposable`. Questo forza le implementazioni (come `BleChannelDriver`, `CanChannelDriver`) a dichiarare `IDisposable` esplicitamente nella loro signature.

#### Soluzione Implementata

Aggiunto `IDisposable` a `IChannelDriver`:

```csharp
public interface IChannelDriver : IDisposable, IAsyncDisposable
{
    // ...
}
```

Rimossa dichiarazione ridondante dai driver:

| Driver | Prima | Dopo |
|--------|-------|------|
| `BleChannelDriver` | `: IChannelDriver, IDisposable` | `: IChannelDriver` |
| `CanChannelDriver` | `: IChannelDriver, IDisposable` | `: IChannelDriver` |

#### File Modificati

- `Protocol/Infrastructure/IChannelDriver.cs` (riga 19)
- `Drivers.Ble/BleChannelDriver.cs` (riga 26)
- `Drivers.Can/CanChannelDriver.cs` (riga 46)

#### Benefici Ottenuti

- Pattern dispose unificato nell'interfaccia base
- Implementazioni più pulite (meno boilerplate)
- `using` e `await using` garantiti per tutti i driver
- Nessun breaking change

#### Issue Correlate

- BLE-010 *(Wontfix)* - Scoperta originale analizzando `BleChannelDriver`

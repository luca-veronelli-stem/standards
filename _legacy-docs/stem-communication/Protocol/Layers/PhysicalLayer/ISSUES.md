# PhysicalLayer - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunità di refactoring e violazioni di best practice per il componente **PhysicalLayer**.  

> **Ultimo aggiornamento:** 2026-02-10

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 0 | 3 |
| **Media** | 2 | 1 |
| **Bassa** | 4 | 5 |

**Totale aperte:** 6  
**Totale risolte:** 9

---

## Indice Issue Aperte

- [PL-003 - Configurazione TxBufferSize/RxBufferSize Ignorata](#pl-003--configurazione-txbuffersizerbxbuffersize-ignorata)
- [PL-007 - Timeout Configurabile per Operazioni I/O (Parziale)](#pl-007--timeout-configurabile-per-operazioni-io)
- [PL-004 - ProtocolRxBuffer.IndexOf() Complessità O(n*m)](#pl-004--protocolrxbufferindexof-complessità-onm)
- [PL-008 - BufferStatistics.Utilization() Può Ritornare Valori Negativi](#pl-008--bufferstatisticsutilization-può-ritornare-valori-negativi)
- [PL-009 - ProtocolTxBuffer.Clear() Esegue Array.Clear Non Necessario](#pl-009--protocoltxbufferclear-esegue-arrayclear-non-necessario)
- [PL-013 - ProtocolRxBuffer.IndexOf() Lettura _dataLength Fuori Lock](#pl-013--protocolrxbufferindexof-lettura-_datalength-fuori-lock)

## Indice Issue Risolte

- [PL-016 - Configurazioni Canale-Specifiche nei Driver](#pl-016--configurazioni-canale-specifiche-nei-driver)
- [PL-015 - ChannelType Inferito dal Driver](#pl-015--channeltype-inferito-dal-driver)
- [PL-012 - CreateChannelDriver Non Deve Esistere](#pl-012--createchanneldriver-non-deve-esistere)
- [PL-001 - Buffer TX Non Sincronizzato con Scrittura su Canale](#pl-001--buffer-tx-non-sincronizzato-con-scrittura-su-canale)
- [PL-002 - Interfaccia IChannelDriver Manca CancellationToken](#pl-002--interfaccia-ichanneldriver-manca-cancellationtoken)
- [PL-006 - BufferStatistics DateTime Non Thread-Safe](#pl-006--bufferstatistics-datetime-non-thread-safe)
- [PL-010 - Mancanza di Metodo per Reset Statistiche](#pl-010--mancanza-di-metodo-per-reset-statistiche)
- [PL-011 - PhysicalLayer Non Implementa IDisposable](#pl-011--physicallayer-non-implementa-idisposable)
- [PL-014 - Mancanza di Logging](#pl-014--mancanza-di-logging)

---

## Priorità Alta

(Nessuna issue alta priorità aperta)

---

## Priorità Media

### PL-003 - Configurazione TxBufferSize/RxBufferSize Ignorata

**Categoria:** Bug  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-20  

#### Descrizione

Le proprietà `TxBufferSize` e `RxBufferSize` in `PhysicalLayerConfiguration` vengono ignorate. I buffer vengono creati con dimensioni fisse nel costruttore usando costanti.

#### File Coinvolti

- `Protocol/Layers/PhysicalLayer/PhysicalLayer.cs` (righe 62-64)
- `Protocol/Layers/PhysicalLayer/Models/PhysicalLayerConfiguration.cs`

#### Codice Problematico

```csharp
public PhysicalLayer(IChannelDriver? channelDriver = null, ILogger<PhysicalLayer>? logger = null)
{
    // Dimensioni fisse, ignorano configurazione passata a InitializeAsync()
    _txBuffer = new ProtocolTxBuffer(PhysicalLayerConstants.TX_BUFFER_MAX_LENGTH);
    _rxBuffer = new ProtocolRxBuffer(PhysicalLayerConstants.RX_BUFFER_MAX_LENGTH);
}
```

#### Soluzione Proposta

Creare buffer in `InitializeAsync()` con dimensioni dalla configurazione.

#### Benefici Attesi

- Configurazione rispettata
- Buffer dimensionabili per caso d'uso

---

### PL-007 - Timeout Configurabile per Operazioni I/O

**Categoria:** Design  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Parzialmente Risolto  
**Data Apertura:** 2026-01-25  
**Data Risoluzione Parziale:** 2026-02-06  
**Branch:** fix/t-011  

#### Descrizione

Il PhysicalLayer non aveva timeout configurabili per le operazioni `ReadAsync()` e `WriteAsync()`.

#### Soluzione Parziale (T-011)

Aggiunte proprietà configurabili in `PhysicalLayerConfiguration`:

```csharp
public int ReadTimeoutMs { get; set; } = PhysicalLayerConstants.DEFAULT_READ_TIMEOUT_MS;
public int WriteTimeoutMs { get; set; } = PhysicalLayerConstants.DEFAULT_WRITE_TIMEOUT_MS;
```

Costanti aggiunte in `PhysicalLayerConstants`:
- `DEFAULT_READ_TIMEOUT_MS = 1000`
- `DEFAULT_WRITE_TIMEOUT_MS = 1000`
- `MIN_TIMEOUT_MS = 100`
- `MAX_TIMEOUT_MS = 60000`

I valori vengono salvati in `_readTimeoutMs` e `_writeTimeoutMs` durante `InitializeAsync()`.

#### ⚠️ Lavoro rimanente

**I timeout NON sono ancora applicati alle operazioni I/O!**

```csharp
// Attuale - NESSUN timeout!
var readResult = await _channelDriver.ReadWithMetadataAsync(_shutdownCts.Token);

// Dovrebbe essere:
using var cts = CancellationTokenSource.CreateLinkedTokenSource(_shutdownCts.Token);
cts.CancelAfter(_readTimeoutMs);
var readResult = await _channelDriver.ReadWithMetadataAsync(cts.Token);
```

Stesso problema per `WriteAsync()`.

#### Benefici Ottenuti (Parziali)

- ✅ Timeout configurabili tramite configuration
- ✅ Limiti validati
- ✅ Pattern T-011 rispettato
- ❌ Timeout non ancora applicati alle operazioni

---

## Priorità Bassa

### PL-004 - ProtocolRxBuffer.IndexOf() Complessità O(n*m)

**Categoria:** Performance  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-20  

#### Descrizione

Il metodo `IndexOf()` usa un algoritmo naive con complessità O(n*m). Per buffer grandi e ricerche frequenti, questo può impattare le performance.

#### File Coinvolti

- `Protocol/Layers/PhysicalLayer/Models/ProtocolRxBuffer.cs` (righe 181-206)

#### Soluzione Proposta

Implementare algoritmo Boyer-Moore per O(n/m) nel caso medio.

#### Benefici Attesi

- Performance migliorate per pattern lunghi

---

### PL-008 - BufferStatistics.Utilization() Può Ritornare Valori Negativi

**Categoria:** Bug  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-28  

#### Descrizione

Il metodo `Utilization()` può ritornare valori negativi se `BytesRead + BytesDiscarded > BytesWritten`.

#### File Coinvolti

- `Protocol/Layers/PhysicalLayer/Models/BufferStatistics.cs`

#### Soluzione Proposta

Clampare il valore nel range [0, 1].

#### Benefici Attesi

- Statistiche sempre valide

---

### PL-009 - ProtocolTxBuffer.Clear() Esegue Array.Clear Non Necessario

**Categoria:** Performance  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-28  

#### Descrizione

Il metodo `Clear()` esegue `Array.Clear()` su tutto il buffer. Non necessario perché i dati vengono sovrascritti durante la successiva scrittura.

#### File Coinvolti

- `Protocol/Layers/PhysicalLayer/Models/ProtocolTxBuffer.cs` (righe 133-141)
- `Protocol/Layers/PhysicalLayer/Models/ProtocolRxBuffer.cs` (righe 213-222)

#### Soluzione Proposta

Rimuovere `Array.Clear` o renderlo opzionale (`SecureClear` per dati sensibili).

#### Benefici Attesi

- Marginale miglioramento performance

---

### PL-013 - ProtocolRxBuffer.IndexOf() Lettura _dataLength Fuori Lock

**Categoria:** Bug  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-02-01  

#### Descrizione

Nel metodo `IndexOf()`, la lettura di `_dataLength` avviene fuori dal lock, causando possibili falsi negativi in scenari multi-thread.

#### File Coinvolti

- `Protocol/Layers/PhysicalLayer/Models/ProtocolRxBuffer.cs` (riga 184)

#### Codice Problematico

```csharp
public int IndexOf(byte[] pattern)
{
    // Lettura di _dataLength FUORI dal lock
    if (pattern.Length == 0 || pattern.Length > _dataLength) return -1;

    lock (_lock)  // Lock acquisito DOPO il check
    {
        // ...
    }
}
```

#### Soluzione Proposta

Spostare il check dentro il lock.

#### Benefici Attesi

- Nessun falso negativo per race condition

---

## Issue Risolte

### PL-015 - ChannelType Inferito dal Driver

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-02-06  
**Data Risoluzione:** 2026-02-11  
**Branch:** `fix/pl-016`

#### Descrizione

In `PhysicalLayerConfiguration`, la proprietà `ChannelType` aveva un valore default (`CAN_CHANNEL`), causando ambiguità tra "utente ha scelto CAN" e "utente non ha configurato".

#### Soluzione Implementata

**Approccio diverso da quello proposto originariamente:**

Invece di aggiungere `ChannelType.UNKNOWN` e validare, abbiamo:

1. **Rimosso `ChannelType` da `PhysicalLayerConfiguration`** - non è responsabilità del layer
2. **Aggiunto `ChannelType` property a `IChannelDriver`** - il driver sa quale tipo è
3. **`ProtocolStackBuilder` inferisce automaticamente** il ChannelType dal driver

```csharp
// IChannelDriver.cs
public interface IChannelDriver : IDisposable, IAsyncDisposable
{
    ChannelType ChannelType { get; }  // Ogni driver ritorna il suo tipo
    // ...
}

// CanChannelDriver.cs
public ChannelType ChannelType => ChannelType.CAN_CHANNEL;

// BleChannelDriver.cs
public ChannelType ChannelType => ChannelType.BLE_CHANNEL;

// ProtocolStackBuilder.cs
public ProtocolStackBuilder WithChannelDriver(IChannelDriver driver)
{
    _driver = driver;
    _config.ChannelType = driver.ChannelType;  // Inferenza automatica
    return this;
}
```

#### File Modificati

- `Protocol/Infrastructure/IChannelDriver.cs` - aggiunta proprietà `ChannelType`
- `Protocol/Layers/PhysicalLayer/Models/PhysicalLayerConfiguration.cs` - rimossa proprietà `ChannelType`
- `Protocol/Layers/Stack/ProtocolStackBuilder.cs` - inferenza automatica
- `Drivers.Can/CanChannelDriver.cs` - implementa `ChannelType`
- `Drivers.Ble/BleChannelDriver.cs` - implementa `ChannelType`

#### Test

29 test che usano `ChannelType` passano, inclusi test di inferenza nel builder.

#### Benefici Ottenuti

- Nessuna ambiguità: il driver SA quale tipo è
- Zero configurazione: l'utente non deve specificare ChannelType
- Type-safety: impossibile configurare ChannelType sbagliato

---

### PL-016 - Configurazioni Canale-Specifiche nei Driver

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-02-06  
**Data Risoluzione:** 2026-02-11  
**Branch:** `fix/pl-016`

#### Descrizione

`PhysicalLayerConfiguration` conteneva proprietà specifiche per alcuni canali che non avevano senso per altri (es. `BaudRate` per UART/CAN ma non per BLE).

#### Soluzione Implementata

1. **`PhysicalLayerConfiguration`** contiene solo parametri comuni a tutti i canali:
   - `TxBufferSize`, `RxBufferSize`
   - `ReadTimeoutMs`, `WriteTimeoutMs`

2. **Configurazioni canale-specifiche nei driver:**
   - `CanConfiguration`: `DevicePath`, `Baudrate`, `FilterId/Mask`
   - `BleConfiguration`: `DeviceNameFilter`, `DeviceMacAddress`, `ServiceUuid`, `MTU`, etc.

3. **Driver richiedono config nel costruttore** (fail-fast):

```csharp
// Pattern comune CAN e BLE
public CanChannelDriver(ICanHardware hardware, CanConfiguration config, ILogger? logger = null)
{
    _config = config ?? throw new ArgumentNullException(nameof(config));
    config.Validate();  // Fail-fast nel costruttore
}
```

4. **Costanti centralizzate** secondo pattern T-011:
   - `CanDriverConstants` - DEFAULT_BAUDRATE, MAX_BAUDRATE, NetInfo layout, etc.
   - `BleDriverConstants` - DEFAULT_MTU, MIN_MTU, MAX_MTU, timeouts, etc.

#### File Modificati

- `Protocol/Layers/PhysicalLayer/Models/PhysicalLayerConfiguration.cs`
- `Drivers.Can/CanConfiguration.cs`
- `Drivers.Can/CanDriverConstants.cs` (nuovo)
- `Drivers.Can/CanChannelDriver.cs`
- `Drivers.Ble/BleConfiguration.cs`
- `Drivers.Ble/BleDriverConstants.cs` (nuovo)
- `Drivers.Ble/BleChannelDriver.cs`

#### Test

Tutti i 2403 test passano (1 fallimento preesistente non correlato).

#### Benefici Ottenuti

- Ogni driver ha solo le sue proprietà
- Nessuna proprietà inutilizzata
- Type-safety: impossibile passare config sbagliata
- Fail-fast: errori di configurazione rilevati subito
- Pattern T-011: costanti centralizzate e documentate

---

### PL-012 - CreateChannelDriver Non Deve Esistere

**Categoria:** Design  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-02-01  
**Data Risoluzione:** 2026-02-06  
**Branch:** fix/pl-012  

#### Descrizione

Il metodo `CreateChannelDriver()` nel `PhysicalLayer` lanciava `NotImplementedException` per tutti i tipi di canale. I driver NON devono essere creati dal protocollo ma forniti dall'applicazione.

#### Soluzione Implementata

1. **Rimosso** il metodo `CreateChannelDriver()` completamente
2. **Aggiunta validazione** in `InitializeAsync()`:

```csharp
// PL-012: Il driver deve essere fornito dall'applicazione, non creato dal protocollo
if (_channelDriver == null)
{
    throw new InvalidOperationException(
        "PhysicalLayer requires an IChannelDriver implementation. " +
        "Channel drivers must be provided by the application, not the protocol.");
}
```

#### Test Aggiunti

4 test in `PhysicalLayerTests.cs`:
- `InitializeAsync_WithoutChannelDriver_ShouldThrowInvalidOperationException`
- `InitializeAsync_WithNullConfigAndNoDriver_ShouldThrowInvalidOperationException`
- `InitializeAsync_WithInjectedDriver_ShouldSucceed`
- `InitializeAsync_WhenConnectFails_ShouldReturnFalse`

#### Benefici Ottenuti

- Separazione chiara responsabilità (protocollo vs applicazione)
- Messaggio errore chiaro e actionable
- Rimosso codice morto (22 righe)

---

### PL-001 - Buffer TX Non Sincronizzato con Scrittura su Canale

**Categoria:** Bug  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-01-15  
**Data Risoluzione:** 2026-02-06  
**Branch:** fix/pl-001  

#### Descrizione

Nel metodo `ProcessDownstreamAsync()`, i dati venivano scritti nel buffer TX **prima** di trasmetterli sul canale. Se `WriteAsync` falliva, i dati restavano nel buffer causando accumulo indefinito.

#### Soluzione Implementata

Invertito l'ordine delle operazioni: trasmissione prima, poi scrittura nel buffer:

```csharp
// PL-001 FIX: Trasmetti PRIMA sul canale, poi aggiorna buffer
await _channelDriver.WriteAsync(data, metadata, _shutdownCts.Token);

// Buffer usato solo per diagnostica/logging DOPO successo trasmissione
_txBuffer.Write(data);
```

#### Test Aggiunti

Test esistenti coprono già il caso (il buffer ora riflette solo dati effettivamente trasmessi).

#### Benefici Ottenuti

- Stato buffer sempre consistente con dati realmente trasmessi
- Nessun accumulo di dati orfani in caso di errori
- Comportamento prevedibile

#### Note Architetturali

Dopo questo fix, i buffer TX/RX hanno un ruolo **puramente diagnostico** (vedi README.md sezione "Nota sui Buffer"). Per canali frame-based (CAN/BLE) potrebbero essere sostituiti da semplici contatori.

---

### PL-006 - BufferStatistics DateTime Non Thread-Safe

**Categoria:** Bug  
**Priorità:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-25  
**Data Risoluzione:** 2026-02-03  
**Branch:** fix/t-005  

#### Descrizione

Le proprietà DateTime in `BufferStatistics` erano non atomiche.

#### Soluzione Implementata

Pattern DateTime → long (Ticks) conforme a T-005:

```csharp
private long _lastWriteTimeTicks;

public DateTime? LastWriteTime
{
    get
    {
        var ticks = Interlocked.Read(ref _lastWriteTimeTicks);
        return ticks == 0 ? null : new DateTime(ticks);
    }
}
```

#### Benefici Ottenuti

- Thread-safety completa
- Conforme a T-005

---

### PL-010 - Mancanza di Metodo per Reset Statistiche

**Categoria:** API  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-01-20  
**Data Risoluzione:** 2026-01-29  
**Branch:** fix/t-004  

#### Descrizione

`BufferStatistics` accumulava statistiche indefinitamente senza possibilità di reset.

#### Soluzione Implementata

Implementato metodo `Reset()` conforme a STATISTICS.md.

#### Benefici Ottenuti

- Statistiche resettabili
- Monitoraggio periodico facilitato

---

### PL-002 - Interfaccia IChannelDriver Manca CancellationToken

**Categoria:** Design  
**Priorità:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-01-15  
**Data Risoluzione:** 2026-01-28  
**Branch:** fix/pl-002  

#### Descrizione

L'interfaccia `IChannelDriver` non supportava `CancellationToken` per i metodi asincroni, impedendo cancellazione di operazioni bloccate durante shutdown.

#### Soluzione Implementata

**Modifiche Effettuate:**

1. **File `IChannelDriver.cs`:**
   - Aggiunto `CancellationToken cancellationToken = default` a tutti i metodi async

2. **File `PhysicalLayer.cs`:**
   - Aggiunto `CancellationTokenSource _shutdownCts`
   - Token passato a tutte le operazioni del driver
   - Cancellazione in `DisposeResources()`

#### Test Aggiunti

Test esistenti continuano a funzionare (token opzionale con default).

#### Benefici Ottenuti

- Shutdown graceful senza blocchi
- Cooperative cancellation pattern
- Retrocompatibile

---

### PL-014 - Mancanza di Logging

**Categoria:** Code Smell  
**Priorità:** Bassa  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-20  
**Data Risoluzione:** 2026-01-28  
**Branch:** fix/t-002  

#### Descrizione

Il PhysicalLayer non aveva alcun logging.

#### Soluzione Implementata

Logging completo implementato:
- `LogTrace`: Bytes ricevuti/trasmessi
- `LogDebug`: Statistiche buffer
- `LogInformation`: Connessione/disconnessione
- `LogWarning`: Buffer overflow, timeout
- `LogError`: Errori I/O

#### Benefici Ottenuti

- Troubleshooting semplificato
- Monitoring comunicazione

---

### PL-011 - PhysicalLayer Non Implementa IDisposable

**Categoria:** Design  
**Priorità:** Bassa  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-15  
**Data Risoluzione:** 2026-01-28  
**Branch:** fix/t-001  

#### Descrizione

`PhysicalLayer` non implementava `IDisposable`.

#### Soluzione Implementata

`PhysicalLayer` ora eredita da `ProtocolLayerBase` che implementa `IDisposable`. In `DisposeResources()`:
- Disconnette channel driver
- Pulisce buffer TX e RX
- Cancella CancellationTokenSource

Vedi issue trasversale T-001 per dettagli.

#### Benefici Ottenuti

- Cleanup corretto risorse
- Nessun memory leak

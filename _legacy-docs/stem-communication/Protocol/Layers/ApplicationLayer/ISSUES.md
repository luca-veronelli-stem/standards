# ApplicationLayer - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunita di refactoring e violazioni di best practice per il componente **ApplicationLayer**.  

> **Ultimo aggiornamento:** 2026-02-09

---

## Riepilogo

| Priorita | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 1 | 2 |
| **Media** | 4 | 4 |
| **Bassa** | 5 | 2 |

**Totale aperte:** 10  
**Totale risolte:** 8

---

## Indice Issue Aperte

- [AL-003 - Multi-Device Support Limitato](#al-003---multi-device-support-limitato)
- [AL-005 - WriteMemoryArea Non Traccia Successi/Fallimenti Parziali](#al-005---writememoryarea-non-traccia-successifallimenti-parziali)
- [AL-006 - Callback Post-Scrittura Invocato Prima della Costruzione Risposta](#al-006---callback-post-scrittura-invocato-prima-della-costruzione-risposta)
- [AL-007 - ReadMemoryArea Ignora Errori Silenziosamente](#al-007---readmemoryarea-ignora-errori-silenziosamente)
- [AL-008 - ProtocolVersionHandler Non Forza NO_CRYPT Come in C](#al-008---protocolversionhandler-non-forza-no_crypt-come-in-c)
- [AL-010 - Registrazione Handler Sovrascrive Silenziosamente](#al-010---registrazione-handler-sovrascrive-silenziosamente)
- [AL-011 - VariableDefinition API Verbosa](#al-011---variabledefinition-api-verbosa)
- [AL-012 - IVariableMap Manca Operazioni Bulk](#al-012---ivariablemap-manca-operazioni-bulk)
- [AL-014 - CommandHandlerRegistry Non Implementa IDisposable](#al-014---commandhandlerregistry-non-implementa-idisposable)
- [AL-015 - ApplicationLayerConstants Potrebbe Essere Incompleta](#al-015---applicationlayerconstants-potrebbe-essere-incompleta)

## Indice Issue Risolte

- [AL-017 - ProcessDownstreamAsync Non Valida Data/Context](#al-017---processdownstreamasync-non-valida-datacontext)
- [AL-016 - ApplicationLayerStatistics.LastMessage Timestamp Non Thread-Safe](#al-016---applicationlayerstatisticslastmessage-timestamp-non-thread-safe)
- [AL-018 - VariableMap.ConvertToLong() Non Gestisce Endianness](#al-018---variablemapconverttolong-non-gestisce-endianness)
- [AL-004 - Float Min/Max Validation Non Implementata](#al-004---float-minmax-validation-non-implementata)
- [AL-009 - CommandHandlerRegistry Non Traccia Metriche](#al-009---commandhandlerregistry-non-traccia-metriche)
- [AL-013 - Mancanza di Logging Completo](#al-013---mancanza-di-logging-completo)
- [AL-002 - Mancanza di Timeout per Handler Execution](#al-002---mancanza-di-timeout-per-handler-execution)
- [AL-001 - ApplicationLayer Non Implementa IDisposable Ma Gestisce Eventi](#al-001---applicationlayer-non-implementa-idisposable-ma-gestisce-eventi)

---

## Priorita Alta

### AL-003 - Multi-Device Support Limitato

**Categoria:** Design  
**Priorita:** Alta  
**Impatto:** Alto  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

Il codice C supporta tabelle multiple per dispositivi diversi (`SP_App_DevsTabs[]`). L'implementazione C# ha un design dove gli handler ricevono `IVariableMap` tramite dependency injection nel costruttore, ma non c'e supporto nativo per selezionare VariableMap diversi in base al device remoto.

#### File Coinvolti

- `Protocol/Layers/ApplicationLayer/Helpers/CommandHandlerRegistry.cs`
- `Protocol/Layers/ApplicationLayer/Helpers/CommandHandlers/*.cs`

#### Codice Problematico

```csharp
// Gli handler ricevono un singolo VariableMap nel costruttore
public class ReadLogicalVariableHandler(IVariableMap variableMap) : ICommandHandler
{
    private readonly IVariableMap _variableMap = variableMap;  // <-- Singola istanza
}
```

#### Problema Specifico

- Il client non puo gestire piu dispositivi simultaneamente con VariableMap dedicati
- Non conforme al codice C originale che supporta `SP_App_DevsTabs[]`
- Limita l'uso come gateway multi-device

#### Soluzione Proposta

**Opzione A: Factory pattern per VariableMap**

```csharp
public interface IVariableMapFactory
{
    IVariableMap GetVariableMapForDevice(uint deviceId);
}

public class ReadLogicalVariableHandler : ICommandHandler
{
    private readonly IVariableMapFactory _mapFactory;
    
    public ReadLogicalVariableHandler(IVariableMapFactory mapFactory)
    {
        _mapFactory = mapFactory;
    }
    
    public async Task<ApplicationMessage?> HandleAsync(
        ApplicationMessage message, 
        LayerContext context)
    {
        var variableMap = _mapFactory.GetVariableMapForDevice(context.SenderId);
        // ...
    }
}
```

#### Benefici Attesi

- Supporto client/gateway completo
- Conformita al codice C
- Gestione multi-device nativa

---

## Priorita Media

### AL-005 - WriteMemoryArea Non Traccia Successi/Fallimenti Parziali

**Categoria:** Observability  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

`WriteMemoryAreaHandler` restituisce solo uno status globale (0x00/0x01) senza tracciare quali variabili sono state scritte con successo e quali hanno fallito.

#### File Coinvolti

- `Protocol/Layers/ApplicationLayer/Helpers/CommandHandlers/WriteMemoryAreaHandler.cs` (righe 78-133)

#### Codice Problematico

```csharp
byte status = 0x00;

for (int i = 0; i < nVar && dataOffset < values.Length; i++)
{
    try
    {
        await _variableMap.WriteAsync(currentAddress, singleValue);
    }
    catch
    {
        // Setta status = 0x01 ma non traccia QUALE variabile ha fallito
        status = 0x01;
    }
    currentAddress++;
}

// Risposta: solo status globale
byte[] responseData = [..., status];
```

#### Benefici Attesi

- Debug facilitato per operazioni parzialmente fallite
- Possibilita di retry selettivo

---

### AL-006 - Callback Post-Scrittura Invocato Prima della Costruzione Risposta

**Categoria:** Bug  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

In `WriteLogicalVariableHandler`, il callback post-scrittura viene invocato dopo `WriteAsync()` ma prima di costruire/ritornare la risposta. Se il callback lancia un'eccezione, lo status potrebbe non riflettere correttamente l'operazione.

#### File Coinvolti

- `Protocol/Layers/ApplicationLayer/Helpers/CommandHandlers/WriteLogicalVariableHandler.cs` (righe 76-93)

#### Codice Problematico

```csharp
try
{
    await _variableMap.WriteAsync(address, value);
    status = 0x00;
    
    // Callback invocato DENTRO il try-catch
    var callback = _variableMap.GetWriteCallback(address);
    if (callback != null)
    {
        await callback(value);  // Se fallisce, status diventa 0x01
    }
}
catch (Exception)
{
    status = 0x01;  // Variabile scritta ma status = error
}
```

#### Soluzione Proposta

```csharp
try
{
    await _variableMap.WriteAsync(address, value);
    status = 0x00;
}
catch (Exception)
{
    status = 0x01;
}

// Costruisci risposta PRIMA del callback
var response = new ApplicationMessage { ... };

// Callback DOPO aver preparato la risposta
if (status == 0x00)
{
    try
    {
        var callback = _variableMap.GetWriteCallback(address);
        if (callback != null)
        {
            await callback(value);
        }
    }
    catch (Exception ex)
    {
        // Log ma NON modificare status
    }
}

return response;
```

#### Benefici Attesi

- Status riflette correttamente l'operazione di scrittura
- Callback non influenza la risposta al client

---

### AL-007 - ReadMemoryArea Ignora Errori Silenziosamente

**Categoria:** Bug  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

`ReadMemoryAreaHandler` cattura eccezioni nel loop di lettura ma le ignora completamente. Il client non puo sapere se alcune variabili non sono state lette.

#### File Coinvolti

- `Protocol/Layers/ApplicationLayer/Helpers/CommandHandlers/ReadMemoryAreaHandler.cs` (righe 82-97)

#### Codice Problematico

```csharp
for (int i = 0; i < nVar; i++)
{
    try
    {
        byte[] value = await _variableMap.ReadAsync(currentAddress);
        valuesList.AddRange(value);
    }
    catch
    {
        // Errore completamente ignorato!
        // Il client riceve una risposta "OK" ma con dati incompleti
    }
    currentAddress++;
}
```

#### Benefici Attesi

- Errori di lettura segnalati al client
- Troubleshooting facilitato

---

### AL-008 - ProtocolVersionHandler Non Forza NO_CRYPT Come in C

**Categoria:** Bug  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

In C, `SP_App_GetVer` forza esplicitamente `*tcry = 0` per la risposta. Il `ProtocolVersionHandler` C# ha un commento che indica questa necessita ma non modifica `context.CryptType`.

#### File Coinvolti

- `Protocol/Layers/ApplicationLayer/Helpers/CommandHandlers/ProtocolVersionHandler.cs` (righe 47-65)

#### Codice Problematico

```csharp
public Task<ApplicationMessage?> HandleAsync(ApplicationMessage message, LayerContext context)
{
    var versionBytes = new byte[2];
    versionBytes[0] = (byte)(_protocolVersion >> 8);
    versionBytes[1] = (byte)(_protocolVersion & 0xFF);

    var response = new ApplicationMessage { ... };

    // Commento presente ma NON implementato
    // In C: if(tcry) { *tcry = 0; } - forza risposta non criptata

    return Task.FromResult<ApplicationMessage?>(response);
}
```

#### Soluzione Proposta

```csharp
public Task<ApplicationMessage?> HandleAsync(ApplicationMessage message, LayerContext context)
{
    // ...
    
    // Forza risposta non criptata come in C
    context.CryptType = CryptType.NO_CRYPT;

    return Task.FromResult<ApplicationMessage?>(response);
}
```

#### Benefici Attesi

- Conformita al codice C originale
- Comportamento consistente con altri handler

---

## Priorita Bassa

### AL-010 - Registrazione Handler Sovrascrive Silenziosamente

**Categoria:** Bug  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

`RegisterHandler()` sovrascrive silenziosamente handler esistenti senza warning o opzione per prevenirlo.

#### File Coinvolti

- `Protocol/Layers/ApplicationLayer/Helpers/CommandHandlerRegistry.cs` (righe 60-65)

#### Soluzione Proposta

```csharp
public void RegisterHandler(ICommandHandler handler, bool allowOverwrite = false)
{
    ArgumentNullException.ThrowIfNull(handler);
    
    if (!allowOverwrite && _commandHandlers.ContainsKey(handler.CommandId))
    {
        throw new InvalidOperationException(
            $"Handler for command {handler.CommandId} is already registered.");
    }
    
    _commandHandlers[handler.CommandId] = handler;
}
```

---

### AL-011 - VariableDefinition API Verbosa

**Categoria:** API  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

Definire variabili richiede boilerplate significativo. Un fluent builder potrebbe semplificare l'API.

#### File Coinvolti

- `Protocol/Layers/ApplicationLayer/Models/VariableDefinition.cs`

---

### AL-012 - IVariableMap Manca Operazioni Bulk

**Categoria:** API  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

`IVariableMap` non espone metodi bulk come `RegisterVariables(IEnumerable<VariableDefinition>)`. Per configurazioni con centinaia di variabili, questo puo essere inefficiente.

#### File Coinvolti

- `Protocol/Layers/ApplicationLayer/Interfaces/IVariableMap.cs`
- `Protocol/Layers/ApplicationLayer/Helpers/VariableMap.cs`

---

### AL-014 - CommandHandlerRegistry Non Implementa IDisposable

**Categoria:** Resource Management  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

`CommandHandlerRegistry` potrebbe contenere handler con risorse (connections, timers) ma non implementa `IDisposable` per disporne correttamente.

#### File Coinvolti

- `Protocol/Layers/ApplicationLayer/Helpers/CommandHandlerRegistry.cs`

---

### AL-015 - ApplicationLayerConstants Potrebbe Essere Incompleta

**Categoria:** API  
**Priorità:** Bassa  
**Impatto:** Basso  
**Status:** Parzialmente Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione Parziale:** 2026-02-09
**Branch:** fix/t-011

#### Descrizione

`ApplicationLayerConstants` potrebbe beneficiare di costanti aggiuntive per timeout, retry, etc.

#### File Coinvolti

- `Protocol/Layers/ApplicationLayer/Models/ApplicationLayerConstants.cs`

#### Costanti Aggiunte (T-011)

```csharp
// Aggiunte con T-011
public const int DEFAULT_HANDLER_TIMEOUT_SECONDS = 5;
public const int MIN_HANDLER_TIMEOUT_SECONDS = 1;
public const int MAX_HANDLER_TIMEOUT_SECONDS = 60;
```

#### Costanti Ancora Mancanti

```csharp
public const int MIN_PAYLOAD_SIZE = 2;
public const ushort MAX_VARIABLE_ADDRESS = 0xFFFF;
public const ushort USER_VARIABLE_START = 0x8000;  // Già esiste come USER_ADDRESS_OFFSET
```

---

## Issue Risolte

### AL-017 - ProcessDownstreamAsync Non Valida Data/Context

**Categoria:** Bug  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-02-05  
**Branch:** docs/aggiorna-issues

#### Descrizione

`ProcessUpstreamAsync()` validava esplicitamente che `data != null`, `data.Length > 0` e `context != null`, ma `ProcessDownstreamAsync()` non effettuava le stesse validazioni.

#### Soluzione Implementata

Aggiunte validazioni in `ProcessDownstreamAsync()` (righe 306-330) identiche a `ProcessUpstreamAsync()`:

```csharp
public override Task<LayerResult> ProcessDownstreamAsync(byte[] data, LayerContext context)
{
    ThrowIfDisposed();

    if (!IsInitialized)
        return Task.FromResult(LayerResult.Error("Application layer not initialized"));

    if (data == null)
        return Task.FromResult(LayerResult.Error("Cannot process null data"));

    if (data.Length == 0)
        return Task.FromResult(LayerResult.Error("Cannot process empty data"));

    if (context == null)
        return Task.FromResult(LayerResult.Error("Context cannot be null"));
    // ...
}
```

#### Benefici Ottenuti

- Comportamento consistente tra upstream e downstream
- Fail-fast su input invalidi
- Errori chiari invece di NullReferenceException

---

### AL-016 - ApplicationLayerStatistics.LastMessage Timestamp Non Thread-Safe

**Categoria:** Bug  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-02-03  
**Branch:** fix/t-005  

#### Descrizione

Le proprieta `LastMessageReceivedAt` e `LastMessageSentAt` erano `DateTime?` con setter privati non sincronizzati. Operazioni concorrenti potevano causare torn reads.

#### Soluzione Implementata

Usato `long` (Ticks) con `Interlocked.Read/Exchange` per thread-safety lock-free:

```csharp
private long _lastMessageReceivedAtTicks;

public DateTime? LastMessageReceivedAt
{
    get
    {
        var ticks = Interlocked.Read(ref _lastMessageReceivedAtTicks);
        return ticks == 0 ? null : new DateTime(ticks);
    }
}

public void RecordMessageReceived()
{
    Interlocked.Increment(ref _messagesReceived);
    Interlocked.Exchange(ref _lastMessageReceivedAtTicks, DateTime.UtcNow.Ticks);
}
```

#### Benefici Ottenuti

- Thread-safety garantita
- Lock-free performance
- Consistency con pattern usato in altri layer

---

### AL-018 - VariableMap.ConvertToLong() Non Gestisce Endianness

**Categoria:** Bug  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-30  
**Branch:** fix/al-004  

#### Descrizione

L'issue era basato su una descrizione obsoleta. L'analisi del codice ha confermato che `ConvertToLong()` utilizzava gia big-endian corretto conforme al protocollo STEM.

#### Soluzione Implementata

1. Confermata conformita big-endian
2. Aggiunto bounds checking (`when value.Length >= N`)
3. Documentazione XML migliorata con riferimento esplicito a big-endian

#### Benefici Ottenuti

- Confermata conformita big-endian con protocollo STEM
- Aggiunto bounds checking per robustezza
- Documentazione esplicita sull'endianness

---

### AL-004 - Float Min/Max Validation Non Implementata

**Categoria:** Code Smell  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-30  
**Branch:** fix/al-004  

#### Descrizione

La validazione min/max per variabili di tipo `Float` ritornava sempre `0` nel metodo `ConvertToLong()`, bypassando la validazione.

#### Soluzione Implementata

1. Nuovo metodo `ValidateFloatMinMax()` con parsing big-endian IEEE 754
2. Rifiuta NaN e Infinity automaticamente
3. Bounds checking per evitare `IndexOutOfRangeException`

#### Benefici Ottenuti

- Validazione completa per tutti i tipi numerici
- Protezione contro valori float invalidi
- Big-endian conforme al protocollo STEM

---

### AL-009 - CommandHandlerRegistry Non Traccia Metriche

**Categoria:** Observability  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-29  
**Branch:** fix/t-004  

#### Descrizione

`CommandHandlerRegistry` non tracciava metriche come latenza handler, throughput, o errori per comando.

#### Soluzione Implementata

Aggiunta integrazione con sistema di statistiche esistente (T-004).

---

### AL-013 - Mancanza di Logging Completo

**Categoria:** Observability  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-28  
**Branch:** fix/t-001  

#### Descrizione

Nessun logging strutturato di eventi critici: comandi ricevuti/processati, errori handler, variabili scritte.

#### Soluzione Implementata

Aggiunto parametro `ILogger<T>?` nei costruttori e logging strutturato nelle operazioni critiche.

---

### AL-002 - Mancanza di Timeout per Handler Execution

**Categoria:** Bug  
**Priorita:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-27  
**Branch:** fix/al-002  

#### Descrizione

Nessun timeout configurabile per l'esecuzione degli handler in `CommandHandlerRegistry`. Un handler bloccato poteva bloccare l'intero message processing.

#### Soluzione Implementata

1. Aggiunto campo `_handlerTimeout` (default: 5 secondi)
2. Timeout protection in `ExecuteAsync()` con `Task.WaitAsync(CancellationToken)`
3. Gestione `OperationCanceledException` con ritorno `null` (fail-safe)

#### Test Aggiunti

- `ExecuteAsync_WithTimeout_ReturnsNullOnTimeout`
- `ExecuteAsync_WithSlowHandler_CancelsAfterTimeout`

#### Benefici Ottenuti

- Protezione contro handler bloccati/difettosi
- Timeout configurabile per scenari diversi
- Comportamento fail-safe

---

### AL-001 - ApplicationLayer Non Implementa IDisposable Ma Gestisce Eventi

**Categoria:** Resource Management  
**Priorita:** Alta  
**Impatto:** Critico  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-27  
**Branch:** fix/t-001  

#### Descrizione

Event handler `MessageReceived` e `AckReceived` mai disconnessi, causavano memory leak.

#### Soluzione Implementata

`ApplicationLayer` ora eredita da `ProtocolLayerBase` che implementa `IDisposable`.
Gli eventi vengono rilasciati nel metodo `DisposeResources()`.

Vedi issue trasversale T-001 per dettagli completi.

#### Benefici Ottenuti

- Nessun memory leak
- Pattern Dispose standard
- Supporto using statement
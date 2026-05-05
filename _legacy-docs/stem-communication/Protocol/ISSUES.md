# STEM Communication Protocol - Issue Tracker

> **Ultimo aggiornamento:** 2026-02-26

---

## Riepilogo Globale

| Componente | Aperte | Risolte | Totale |
|------------|--------|---------|--------|
| [ApplicationLayer](./Layers/ApplicationLayer/ISSUES.md) | 10 | 8 | 18 |
| [PresentationLayer](./Layers/PresentationLayer/ISSUES.md) | 8 | 8 | 16 |
| [SessionLayer](./Layers/SessionLayer/ISSUES.md) | 9 | 6 | 15 |
| [TransportLayer](./Layers/TransportLayer/ISSUES.md) | 10 | 7 | 17 |
| [NetworkLayer](./Layers/NetworkLayer/ISSUES.md) | 12 | 8 | 20 |
| [DataLinkLayer](./Layers/DataLinkLayer/ISSUES.md) | 6 | 6 | 12 |
| [PhysicalLayer](./Layers/PhysicalLayer/ISSUES.md) | 6 | 9 | 15 |
| [Base](./Layers/Base/ISSUES.md) | 0 | 2 | 2 |
| [Stack](./Layers/Stack/ISSUES.md) | 10 | 2 | 12 |
| [Infrastructure](./Infrastructure/ISSUES.md) | 3 | 2 | 5 |
| **Totale Protocol** | **74** | **58** | **132** |

### Driver e Client

| Componente | Aperte | Risolte | Totale |
|------------|--------|---------|--------|
| [Drivers.Can](../Drivers.Can/ISSUES.md) | 10 | 7 | 17 |
| [Drivers.Ble](../Drivers.Ble/ISSUES.md) | 3 | 17 | 20 |
| [Client](../Client/ISSUES.md) | 13 | 0 | 13 |
| **Totale Esterno** | **26** | **24** | **50** |

**Totale Progetto:** 99 aperte / 83 risolte / 182 totali

> **Nota:** Le feature request sono tracciate separatamente in [FEATURES.md](FEATURES.md)

---

## Issue Alta Priorità

| ID | Componente | Titolo | Categoria |
|----|------------|--------|-----------|
| **PR-016** | Presentation | CryptoProvider SetKey Race Condition - Reference Counting | Performance |
| **SL-015** | Session | UpdateRemoteDevice Non Gestisce Sessioni Broadcast | Bug |
| **AL-003** | Application | Multi-Device Support Limitato | Design |
| **CAN-003** | Drivers.Can | Race Condition in InitializeAsync | Bug |
| **CAN-017** | Drivers.Can | Timeout Chunk Incompleti Mancante | Bug |
| **CLI-001** | Client | PcanHardware.Dispose() Sincrono | Anti-Pattern |
| **DL-002** | DataLink | Validazione Input in DataLinkFrameBuilder.Build() | Bug |
| **T-014** | Cross-cutting | Unificazione NetInfoCodec tra Driver | Design |
| **T-015** | Cross-cutting | Architettura Chunking Driver vs TransportLayer | Design |

---

## Issue Trasversali (T-xxx)

Issue che impattano multipli layer e sono stati risolti con fix coordinati.

| ID | Titolo | Status | Data |
|----|--------|--------|------|
| **T-014** | Unificazione NetInfoCodec tra Driver CAN e BLE | Aperto | - |
| **T-015** | Architettura Chunking: Driver vs TransportLayer | Aperto | - |
| **T-016** | Usare BinaryPrimitives per Endianness | Aperto | - |
| **T-020** | Standard Null Validation | Aperto | - |
| **T-022** | Immutabilità DTOs (init vs set) | Aperto | - |
| **T-023** | Adozione Record Types per DTOs | Aperto | - |
| **T-025** | Completamento Internal Error Enum per Helper | Aperto | 2026-02-13 |
| **T-019** | ConfigureAwait(false) per Library Code | ✅ Risolto | 2026-02-26 |
| **T-024** | Standard CancellationToken Propagation | ✅ Risolto | 2026-02-26 |
| **T-021** | Standard EventArgs Tipizzati, applicato | ✅ Risolto | 2026-02-25 |
| **T-013** | Lifecycle Helper: Costruttore vs InitializeAsync | ✅ Risolto | 2026-02-18 |
| **T-006** | Rimuovere Shutdown() + UninitializeAsync() | ✅ Risolto | 2026-02-18 |
| **T-012** | Standardizzazione Gestione Errori | ✅ Risolto | 2026-02-13 |
| **T-018** | Standard Commenti XML | ✅ Risolto | 2026-02-12 |
| **T-017** | Standard Visibilità Componenti | ✅ Risolto | 2026-02-12 |
| **T-009** | Header BLE Mancante (NetInfo + RecipientId) | ✅ Risolto | 2026-02-11 |
| **T-010** | Template Standard README per Layer | ✅ Risolto | 2026-02-09 |
| **T-011** | Pattern Constants → Configuration → Layer | ✅ Risolto | 2026-02-09 |
| **T-005** | Thread Safety Standardization | ✅ Risolto | 2026-02-03 |
| **T-008** | Channel-Aware Chunking (CAN NetInfo) | ✅ Risolto | 2026-02-02 |
| **T-004** | Sistema Statistiche Unificato | ✅ Risolto | 2026-01-29 |
| **T-003** | Costanti Internal → Public | ✅ Risolto | 2026-01-29 |
| **T-007** | ThrowIfDisposed() Consistency | ✅ Risolto | 2026-01-28 |
| **T-002** | Logging Strutturato (ILogger) | ✅ Risolto | 2026-01-28 |
| **T-001** | Pattern IDisposable via ProtocolLayerBase | ✅ Risolto | 2026-01-27 |

---

### T-025 - Completamento Internal Error Enum per Helper

**Categoria:** Design / Error Handling  
**Priorità:** Bassa  
**Impatto:** Basso - Completezza, statistiche granulari  
**Status:** Aperto  
**Data Apertura:** 2026-02-13

#### Descrizione

Il pattern **Internal Error Enum** (ERR-030) definisce come helper interni usano enum per errori di protocollo invece di eccezioni. Attualmente esistono:

| Helper | Enum | Valori | Completa? |
|--------|------|--------|-----------|
| `DataLinkFrameParser` | `ParseError` | 2 (BufferTooShort, LengthMismatch) | ✅ Sì |
| `ChunkReassembler` | `ReassemblyError` | 5 (OrphanChunk, UnexpectedFirstChunk, ChunksRemainingMismatch, DuplicateChunk, PayloadTooLarge) | ✅ Sì |

#### Potenziali Nuove Enum

Helper senza enum che potrebbero beneficiarne (se hanno 3+ tipi di errore distinti):

| Helper | Layer | Tipi Errore | Enum Necessaria? |
|--------|-------|-------------|------------------|
| `CryptoProvider` | Presentation | KeyNotSet, InvalidBlockSize, PaddingError | ⚠️ Forse |
| `SessionStateMachine` | Session | InvalidTransition, SessionExpired | ❌ No (solo 2) |
| `RoutingTableManager` | Network | RouteNotFound, MaxHopsExceeded | ❌ No (solo 2) |
| `ApplicationMessageSerializer` | Application | InvalidFormat, PayloadTooLarge, InvalidCommand | ⚠️ Forse |

#### Criteri per Aggiungere Enum (ERR-030)

1. Helper ha **3+ tipi di errore distinti**
2. Servono **statistiche granulari** (`RecordErrorByType`)
3. L'enum rimane **internal** (non esposta)
4. Il layer **mappa** enum → `ProtocolError`

#### Lavoro Fatto (2026-02-13)

- ✅ `ParseError`: Rimosso `InvalidBuffer` (null → `ArgumentNullException`)
- ✅ `ReassemblyError`: Aggiunti `DuplicateChunk` e `PayloadTooLarge`
- ✅ `ChunkReassembler`: Logica detection duplicati e payload overflow
- ✅ `TransportLayerStatistics.RecordReassemblyErrorByType`: Aggiornato

#### Azione Richiesta

Valutare se creare:
- `CryptoError` per `CryptoProvider` (encrypt/decrypt/key errors)
- `SerializationError` per `ApplicationMessageSerializer`

#### Riferimenti

- `Docs/Standards/ERROR_HANDLING_STANDARD.md` - Regole ERR-030 - ERR-033
- `Protocol/Layers/DataLinkLayer/Enums/ParseError.cs`
- `Protocol/Layers/TransportLayer/Enums/ReassemblyError.cs`

---

### T-014 - Unificazione NetInfoCodec tra Driver CAN e BLE

**Categoria:** Design / Refactoring  
**Priorità:** Media  
**Impatto:** Medio - Duplicazione codice, manutenibilità  
**Status:** Aperto  
**Data Apertura:** 2026-02-11

#### Descrizione

NetInfo ha lo **stesso formato** in CAN e BLE:
```
NetInfo (16 bit, Little Endian):
- Bit 0-1:  Version (2 bit)
- Bit 2-4:  PacketId (3 bit, rolling 1-7)
- Bit 5:    SetLength/IsFirstChunk (1 bit)
- Bit 6-15: RemainingChunks (10 bit, countdown)
```

Ma abbiamo **due implementazioni separate**:
- `Drivers.Can/Helpers/NetInfoHelper.cs`
- `Drivers.Ble/Helpers/BleFramingHelper.cs` (metodi `EncodeNetInfo`/`DecodeNetInfo`)

#### Soluzione Proposta

Estrarre `NetInfoCodec` in `Protocol.Infrastructure`:

```csharp
// Protocol/Infrastructure/NetInfoCodec.cs
public static class NetInfoCodec
{
    public static ushort Encode(int packetId, int remainingChunks, bool isFirstChunk, int version = 0);
    public static NetInfoData Decode(ushort netInfo);
    public static byte[] EncodeToBytes(int packetId, int remainingChunks, bool isFirstChunk, int version = 0);
    public static NetInfoData DecodeFromBytes(ReadOnlySpan<byte> data);
}
```

I driver continuano a gestire **quando/come** usare NetInfo (diverso per CAN vs BLE), ma il **codec** è condiviso.

#### File Coinvolti

- Creare: `Protocol/Infrastructure/NetInfoCodec.cs`
- Modificare: `Drivers.Can/Helpers/NetInfoHelper.cs` → delegare a `NetInfoCodec`
- Modificare: `Drivers.Ble/Helpers/BleFramingHelper.cs` → delegare a `NetInfoCodec`

#### Benefici Attesi

- Singola fonte di verità per encoding/decoding NetInfo
- Riduzione duplicazione codice
- Manutenibilità migliorata

---

### T-015 - Architettura Chunking: Driver vs TransportLayer

**Categoria:** Design / Architettura  
**Priorità:** Media  
**Impatto:** Medio - Chiarezza architetturale, performance  
**Status:** Aperto  
**Data Apertura:** 2026-02-11

#### Descrizione

Attualmente esiste **doppio chunking**:

1. **TransportLayer** chunka messaggi grandi in ~200 bytes (costante fissa)
2. **Driver** ri-chunka per il canale fisico:
   - CAN: 6 bytes per frame (8 - NetInfo)
   - BLE: MTU negoziato (es. 182 bytes)

Inoltre, CAN e BLE hanno comportamenti **diversi** per NetInfo:

| Canale | NetInfo | Comportamento |
|--------|---------|---------------|
| **CAN** | In **OGNI** frame fisico | Countdown per ogni frame da 8 bytes |
| **BLE** | **UNA VOLTA** all'inizio | Solo nel primo frame del messaggio |

#### Problemi Attuali

1. **Inefficienza:** Doppio chunking crea overhead
2. **Confusione responsabilità:** PacketId/RemainingChunks sono concetti Transport, ma gestiti nei driver
3. **Chunk size fissa:** TransportLayer usa 200B fissi invece di adattarsi al canale

#### Opzioni Architetturali

| Opzione | Descrizione | Pro | Contro |
|---------|-------------|-----|--------|
| **A) Status quo** | Mantieni doppio chunking | Semplice, funziona | Inefficiente, confuso |
| **B) Solo driver chunking** | TL passa raw, driver chunka tutto | Efficiente | Driver complessi |
| **C) TL chunking adattivo** | TL chiede chunk size al driver | Flessibile | Richiede nuova API |
| **D) Separazione semantica** | TL gestisce PacketId/logica, driver solo fisico | Pulito | Richiede refactoring |

#### Soluzione Raccomandata

**Opzione C + parziale D:**

1. `IChannelDriver` espone `OptimalChunkSize` property
2. TransportLayer usa questa size invece di costante fissa
3. NetInfo encoding rimane nel codec condiviso (T-014)
4. Logica "quando applicare NetInfo" rimane driver-specific

```csharp
public interface IChannelDriver
{
    // Esistente
    ChannelType ChannelType { get; }
    
    // Nuovo
    int OptimalChunkSize { get; } // CAN: 6, BLE: MTU-6
}
```

#### File Coinvolti

- Modificare: `Protocol/Infrastructure/IChannelDriver.cs`
- Modificare: `Drivers.Can/CanChannelDriver.cs`
- Modificare: `Drivers.Ble/BleChannelDriver.cs`
- Modificare: `Protocol/Layers/TransportLayer/TransportLayer.cs`

#### Benefici Attesi

- Chunking efficiente per ogni canale
- Responsabilità più chiare
- Performance migliorate (meno overhead)

---

### T-016 - Usare BinaryPrimitives per Endianness

**Categoria:** Code Smell / Performance  
**Priorità:** Bassa  
**Impatto:** Basso - Leggibilità e manutenibilità  
**Status:** Aperto  
**Data Apertura:** 2026-02-11

#### Descrizione

Il progetto utilizza manipolazione manuale dei bit (`<< 8`, `>> 8`, `& 0xFF`) per gestire l'endianness invece di usare `System.Buffers.Binary.BinaryPrimitives` che è più sicuro, leggibile e performante.

#### File Coinvolti (25+ occorrenze)

- `Protocol/Layers/ApplicationLayer/Helpers/ApplicationMessageSerializer.cs`
- `Protocol/Layers/ApplicationLayer/Helpers/VariableMap.cs`
- `Protocol/Layers/ApplicationLayer/Helpers/CommandHandlers/*.cs`
- `Protocol/Layers/DataLinkLayer/Helpers/DataLinkFrameParser.cs`
- `Protocol/Layers/DataLinkLayer/Helpers/DataLinkFrameSerializer.cs`
- `Protocol/Layers/TransportLayer/Helpers/ChunkSerializer.cs`

#### Codice Problematico

```csharp
// Attuale - manipolazione manuale
ushort value = (ushort)((buffer[0] << 8) | buffer[1]);
buffer[0] = (byte)(value >> 8);
buffer[1] = (byte)(value & 0xFF);

// Dovrebbe essere:
ushort value = BinaryPrimitives.ReadUInt16BigEndian(buffer);
BinaryPrimitives.WriteUInt16BigEndian(buffer, value);
```

#### Soluzione Proposta

1. Aggiungere `using System.Buffers.Binary;` nei file coinvolti
2. Sostituire manipolazioni manuali con `BinaryPrimitives.Read/WriteXxxBigEndian()`
3. Documentare esplicitamente l'endianness nel codice

#### Issue Layer Correlate

- **TL-013** - ChunkSerializer Non Usa BinaryPrimitives (già tracciata)

#### Benefici Attesi

- Codice più leggibile (1 riga invece di 4)
- Endianness esplicita nel nome del metodo
- Performance ottimizzate (JIT può ottimizzare meglio)
- Meno errori di bit manipulation

---

### T-017 - Standard Visibilità Componenti

**Categoria:** Code Quality / API Design  
**Priorità:** Media  
**Impatto:** Medio - Consistenza API, encapsulation  
**Status:** ✅ Risolto  
**Data Apertura:** 2026-02-11  
**Data Risoluzione:** 2026-02-12
**Branch:** fix/t-017

#### Soluzione Implementata

Migrazione completa in 5 sprint:

| Sprint | Descrizione | File Modificati |
|--------|-------------|-----------------|
| 1 | InternalsVisibleTo in Directory.Build.props | 1 |
| 2 | Helpers → internal sealed | ~35 |
| 3 | Layer implementations → internal sealed | 8 |
| 4 | Public classes → sealed | ~35 |
| 5 | Cleanup tipi residui | 9 |

**Risultati:**
- Tipi pubblici: **78 → 55** (riduzione 30%)
- Test: ✅ Tutti passano (2425+)
- Breaking changes controllati: `ProtocolStack.Physical/etc.` ora espone `IProtocolLayer`

**Documentazione:**
- [STANDARD_VISIBILITY.md](STANDARD_VISIBILITY.md) - Standard attivo v2.0

---

### T-018 - Standard Commenti XML

**Categoria:** Documentation / Code Quality  
**Priorità:** Bassa  
**Impatto:** Medio - Documentazione, IntelliSense, generazione docs  
**Status:** ✅ Risolto  
**Data Apertura:** 2026-02-11  
**Data Risoluzione:** 2026-02-12
**Branch:** fix/t-018

#### Descrizione

I commenti XML nella soluzione erano inconsistenti:

1. **Copertura incompleta:** Molti membri pubblici senza XML docs (26+ warning CS1591)
2. **Formato variabile:** Alcuni usano `<para>`, altri no
3. **Lingua mista:** Commenti in italiano e inglese
4. **Tag mancanti:** `<param>`, `<returns>`, `<exception>` spesso assenti

#### Soluzione Implementata

**Standard definito in `STANDARD_COMMENTS.md` v1.1:**

1. **Lingua:** Italiano per tutti i commenti (XML docs e inline)
2. **Copertura:** Tutti i tipi `public`/`protected`/`internal` con XML docs
3. **Tag obbligatori:** `<summary>`, `<param>`, `<returns>`, `<exception>`
4. **Regole formato:**
   - R-005: `<param>` con prima lettera minuscola
   - R-006: `<returns>` per bool con `<c>true</c>`/`<c>false</c>`

**File modificati:**
- ~96 file sorgente in Protocol/, Drivers.Can/, Drivers.Ble/
- ~260+ sostituzioni per allineamento allo standard

**Risultato:**
- ✅ 0 warning CS1591 in build
- ✅ Tutti i progetti (Protocol, Drivers.Can, Drivers.Ble) allineati
- ✅ IntelliSense completo per consumatori API

**Documentazione:**
- [STANDARD_COMMENTS.md](STANDARD_COMMENTS.md) - Standard attivo v1.1

---

### T-019 - ConfigureAwait(false) per Library Code

**Categoria:** Performance / Best Practice  
**Priorità:** Bassa  
**Impatto:** Basso - Performance in contesti UI, deadlock prevention  
**Status:** Aperto  
**Data Apertura:** 2026-02-11

#### Descrizione

Il progetto è una **library** (non un'applicazione), ma non usa `ConfigureAwait(false)` sulle chiamate async. Questo può causare:

1. **Deadlock:** In contesti con SynchronizationContext (WPF, WinForms, ASP.NET legacy)
2. **Performance:** Overhead di context switching non necessario
3. **Best practice:** Microsoft raccomanda `ConfigureAwait(false)` per library code

#### Statistiche Attuali

- **Occorrenze `await`:** ~150+
- **Occorrenze `ConfigureAwait`:** 0

#### Soluzione Proposta

```csharp
// Prima
var result = await SomeAsyncOperation();

// Dopo
var result = await SomeAsyncOperation().ConfigureAwait(false);
```

#### File Coinvolti

Tutti i file `.cs` con metodi async in:
- `Protocol/`
- `Drivers.Can/`
- `Drivers.Ble/`

#### Alternativa (.NET 8+)

Usare `ConfigureAwaitOptions` a livello di progetto o metodo:

```csharp
[AsyncMethodBuilder(typeof(PoolingAsyncValueTaskMethodBuilder))]
public async ValueTask<T> MyMethodAsync() { ... }
```

#### Benefici Attesi

- Zero rischio deadlock
- Performance migliorate in contesti UI
- Conformità best practice Microsoft

---

### T-020 - Standard Null Validation

**Categoria:** Code Quality / Consistency  
**Priorità:** Bassa  
**Impatto:** Basso - Consistenza codice  
**Status:** Aperto  
**Data Apertura:** 2026-02-11

#### Descrizione

La validazione null usa stili misti:

| Stile | Occorrenze | Esempio |
|-------|------------|---------|
| `ArgumentNullException.ThrowIfNull()` | 31 | ✅ Moderno |
| `if (x == null) throw` | 27 | ❌ Legacy |
| `?? throw` | Vari | ⚠️ OK inline |

#### Standard Proposto

```csharp
// ✅ Per parametri metodo - usare sempre ThrowIfNull
public void MyMethod(object param)
{
    ArgumentNullException.ThrowIfNull(param);
}

// ✅ Per stringhe
public void MyMethod(string name)
{
    ArgumentException.ThrowIfNullOrEmpty(name);
    // oppure
    ArgumentException.ThrowIfNullOrWhiteSpace(name);
}

// ✅ Per null coalescing inline
var value = input ?? throw new ArgumentNullException(nameof(input));

// ❌ Evitare
if (param == null)
    throw new ArgumentNullException(nameof(param));
```

#### File Coinvolti

~27 file con pattern legacy da aggiornare

#### Benefici Attesi

- Consistenza del codebase
- Meno boilerplate
- CallerArgumentExpression automatico in .NET 6+

---

### T-021 - Standard EventArgs Tipizzati

**Categoria:** API Design / Type Safety  
**Priorità:** Bassa  
**Impatto:** Basso - Type safety, IntelliSense  
**Status:** ✅ Risolto  
**Data Apertura:** 2026-02-11  
**Data Risoluzione:** 2026-02-25  
**Branch:** fix/t-021

#### Descrizione

Gli eventi usavano EventArgs inconsistenti:

| Pattern | Esempio | Valutazione |
|---------|---------|-------------|
| `EventHandler<CustomEventArgs>` | `SessionEstablishedEventArgs` | ✅ Corretto |
| `EventHandler<uint>` | `SessionHijackAttempted` | ⚠️ Poco espressivo |
| `EventHandler` | `SessionExpired` | ⚠️ Nessun dato |

#### Soluzione Implementata

**Standard creato e applicato:** [EVENTARGS_STANDARD.md](Docs/Standards/EVENTARGS_STANDARD.md) v1.1

**Fase 1 - Definizione Standard (2026-02-24):**
- **EA-001:** Evento con dati → creare EventArgs custom (no `EventHandler<int>`)
- **EA-010:** Nome formato `{Evento}EventArgs`
- **EA-012:** Classe `sealed`
- **EA-020:** Tutte le proprietà readonly
- **EA-022:** Includere `DateTime Timestamp`
- **EA-030:** Validare invarianti nel costruttore

**Fase 2 - Applicazione Standard (2026-02-25):**

| EventArgs Creato | Layer | Invarianti |
|------------------|-------|------------|
| `SessionExpiredEventArgs` | SessionLayer | RemoteDeviceId ≠ 0, Duration ≥ 0 |
| `SessionHijackAttemptedEventArgs` | SessionLayer | AttemptedSenderId ≠ CurrentRemoteId, both ≠ 0 |
| `BuffersTimedOutEventArgs` | TransportLayer | BufferCount > 0, TotalBytesLost ≥ 0 |

**Modifiche aggiuntive:**
- `SessionTerminatedEventArgs` - Aggiunto `Timestamp` (EA-022)

**File modificati:**
- `Protocol/Layers/SessionLayer/Models/EventArgs.cs`
- `Protocol/Layers/TransportLayer/Models/EventArgs.cs` (nuovo)
- `Protocol/Layers/SessionLayer/Helpers/SessionManager.cs`
- `Protocol/Layers/SessionLayer/SessionLayer.cs`
- `Protocol/Layers/TransportLayer/Helpers/ChunkReassembler.cs`
- `Protocol/Layers/TransportLayer/TransportLayer.cs`
- `Protocol/Layers/ApplicationLayer/Models/EventArgs.cs` - Aggiunto Timestamp
- `Protocol/Layers/NetworkLayer/Models/EventArgs.cs` - Aggiunto Timestamp

**Test aggiunti:**
- `Tests/Unit/Protocol/EventArgsTests/EventArgsInvariantsTests.cs` - 20 test totali
- Test aggiornati in `SessionManagerTests.cs` - 2 test per eventi

#### Benefici Ottenuti

- ✅ Standard documentato e applicabile
- ✅ Type-safety per tutti gli eventi principali
- ✅ Invarianti validati nel costruttore
- ✅ **100% conformità EA-022** - Tutti gli EventArgs hanno Timestamp
- ✅ 20 test per invarianti e Timestamp

---

### T-022 - Immutabilità DTOs (init vs set)

**Categoria:** Design / Immutability  
**Priorità:** Bassa  
**Impatto:** Basso - Thread safety, predictability  
**Status:** Aperto  
**Data Apertura:** 2026-02-11

#### Descrizione

I DTOs e Configuration classes usano mix di `set` e `init`:

| Pattern | Occorrenze | Valutazione |
|---------|------------|-------------|
| `{ get; set; }` | 89 | ⚠️ Mutabile |
| `{ get; init; }` | 47 | ✅ Immutabile |
| `{ get; }` (readonly) | Vari | ✅ Immutabile |

#### Problemi con Mutabilità

```csharp
// Problema: StackConfiguration modificabile dopo Build()
var config = new StackConfiguration { LocalDeviceId = 123 };
var stack = builder.Build();

config.LocalDeviceId = 456;  // ⚠️ Modifica post-build!
```

#### Standard Proposto

| Tipo Classe | Accessor | Esempio |
|-------------|----------|---------|
| **DTOs/Models** | `init` | `ApplicationMessage`, `LayerResult` |
| **Configuration** | `init` | `StackConfiguration`, `*LayerConfiguration` |
| **Mutable State** | `set` (privato) | Solo per campi interni gestiti |
| **EventArgs** | `init` o readonly | `SessionEstablishedEventArgs` |

```csharp
// ✅ Configurazione immutabile
public class StackConfiguration
{
    public uint LocalDeviceId { get; init; }
    public ChannelType ChannelType { get; init; }
}
```

#### Benefici Attesi

- Thread safety implicita
- Stato predicibile
- Bug di modifica accidentale impossibili

---

### T-023 - Adozione Record Types per DTOs

**Categoria:** Modernization / C# Features  
**Priorità:** Bassa  
**Impatto:** Basso - Boilerplate reduction, equality semantics  
**Status:** Aperto  
**Data Apertura:** 2026-02-11

#### Descrizione

Il progetto non usa `record` types nonostante target .NET 10. I record offrono:

- Immutabilità by default
- Value equality automatica
- `with` expressions per cloning
- Deconstruction
- ToString() automatico

#### Candidati per Conversione a Record

| Classe Attuale | Tipo Suggerito |
|----------------|----------------|
| `LayerResult` | `record struct` |
| `ApplicationMessage` | `record class` |
| `ChunkMetadata` | `record struct` |
| `DataLinkFrame` | `record class` |
| `*EventArgs` | `record class` |
| `ReassemblyResult` | `record struct` |

#### Esempio Conversione

```csharp
// Prima - 50+ righe
public class ApplicationMessage
{
    public CommandId Command { get; set; }
    public byte[] Data { get; set; }
    public bool IsAcknowledgment { get; set; }

    // + Equals, GetHashCode, ToString...
}

// Dopo - 1 riga
public record ApplicationMessage(CommandId Command, byte[] Data, bool IsAcknowledgment);
```

#### Considerazioni

- **Breaking change:** Cambio semantica equality per classi esistenti
- **Serialization:** Verificare compatibilità con JSON/Binary serializers
- **Arrays in records:** `byte[]` non ha value equality, considerare `ImmutableArray<byte>`

#### Benefici Attesi

- 80% meno boilerplate per DTOs
- Equality semantics corretta
- Pattern matching migliorato
- `with` expressions per modifiche immutabili

---

### T-024 - Standard CancellationToken Propagation

**Categoria:** API Design / Async Best Practice  
**Priorità:** Media  
**Impatto:** Medio - Cancellazione operazioni, responsive UI, resource cleanup  
**Status:** Aperto  
**Data Apertura:** 2026-02-11

#### Descrizione

Il progetto ha un uso **inconsistente** di `CancellationToken`:

| Livello | Ha CancellationToken? | Problema |
|---------|----------------------|----------|
| **IChannelDriver** | ✅ Sì | OK |
| **IProtocolLayer** | ❌ No | Non cancellabile |
| **ICommandHandler** | ❌ No | Handler non interrompibili |
| **IVariableMap** | ❌ No | I/O non cancellabile |
| **ProtocolStack** | ❌ No | Operazioni bloccanti |

#### Statistiche Attuali

- **Metodi async SENZA CT:** ~50+
- **Metodi async CON CT:** ~40
- **ThrowIfCancellationRequested():** 1 sola occorrenza
- **CT propagato internamente:** Parziale

#### Problemi Concreti

```csharp
// ❌ Attuale - non cancellabile
public interface IProtocolLayer
{
    Task<LayerResult> ProcessUpstreamAsync(byte[] data, LayerContext context);
}

// ❌ Attuale - handler può bloccare indefinitamente
public interface ICommandHandler
{
    Task<ApplicationMessage?> HandleAsync(ApplicationMessage message, LayerContext context);
}

// ❌ Attuale - I/O potenzialmente lungo senza cancellazione
public interface IVariableMap
{
    Task<byte[]> ReadAsync(ushort address);
    Task WriteAsync(ushort address, byte[] value);
}
```

#### Standard Proposto

**1. Tutte le API async pubbliche DEVONO accettare CancellationToken:**

```csharp
// ✅ Proposto
public interface IProtocolLayer
{
    Task<LayerResult> ProcessUpstreamAsync(
        byte[] data, 
        LayerContext context, 
        CancellationToken cancellationToken = default);
}

public interface ICommandHandler
{
    Task<ApplicationMessage?> HandleAsync(
        ApplicationMessage message, 
        LayerContext context,
        CancellationToken cancellationToken = default);
}
```

**2. CT deve essere propagato a tutti i livelli:**

```csharp
// Stack → Layer → Handler → VariableMap → Driver
public async Task<LayerResult> SendAsync(byte[] data, uint dest, CancellationToken ct = default)
{
    // Propaga a ogni livello
    var result = await _applicationLayer.ProcessDownstreamAsync(data, context, ct);
    // ...
}
```

**3. Usare ThrowIfCancellationRequested in loop lunghi:**

```csharp
foreach (var chunk in chunks)
{
    cancellationToken.ThrowIfCancellationRequested();
    await ProcessChunkAsync(chunk, cancellationToken);
}
```

**4. Pattern per timeout + cancellation:**

```csharp
using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
linkedCts.CancelAfter(TimeSpan.FromSeconds(5));

await OperationAsync(linkedCts.Token);
```

#### Interfacce da Modificare

| Interfaccia | Metodi da Aggiornare |
|-------------|---------------------|
| `IProtocolLayer` | `ProcessUpstreamAsync`, `ProcessDownstreamAsync`, `InitializeAsync` |
| `ICommandHandler` | `HandleAsync` |
| `IAckHandler` | `HandleAckAsync` |
| `IVariableMap` | `ReadAsync`, `WriteAsync` |
| `ProtocolStack` | `SendAsync`, `ReceiveAsync`, `ProcessUpstreamAsync`, `ProcessDownstreamAsync` |

#### Breaking Change

⚠️ **Questo è un BREAKING CHANGE** per chi implementa le interfacce.

**Mitigazione:**
- Aggiungere CT come parametro opzionale con `= default`
- Fornire overload senza CT che chiamano la versione con CT

```csharp
// Backward compatible
Task<LayerResult> ProcessUpstreamAsync(byte[] data, LayerContext context)
    => ProcessUpstreamAsync(data, context, CancellationToken.None);

Task<LayerResult> ProcessUpstreamAsync(byte[] data, LayerContext context, CancellationToken ct);
```

#### Benefici Attesi

- Operazioni cancellabili (responsive UI)
- Timeout implementabili correttamente
- Graceful shutdown possibile
- Resource cleanup su cancellazione
- Conformità async best practices

---

### T-009 - Header BLE Mancante (NetInfo + RecipientId)

**Categoria:** Bug  
**Priorità:** Alta  
**Impatto:** Critico - Comunicazione BLE non funziona con firmware STEM  
**Status:** ✅ Risolto  
**Data Apertura:** 2026-02-11  
**Data Risoluzione:** 2026-02-11

#### Soluzione Implementata

Creato `BleFramingHelper` per wrap/unwrap frame BLE:
- **TX:** `WrapForTransmit()` aggiunge header `NetInfo(2) + Address(4)` prima del payload
- **RX:** `UnwrapReceived()` rimuove header e restituisce il DataLinkFrame puro

Modifiche a `BleChannelDriver`:
- `WriteAsync()` - chiama `BleFramingHelper.WrapForTransmit()` prima di inviare
- `OnDataReceived()` - chiama `BleFramingHelper.UnwrapReceived()` per estrarre il payload

**Test aggiunti:** 33 test in `BleFramingHelperTests.cs` + aggiornamenti a test esistenti

**Test skippati (10):** Scenari di chunking MTU che spezza l'header BLE - richiedono accumulo buffer pre-unwrap. Vedi **BLE-019**.

---

## Distribuzione per Priorità

```
Critica:     0
Alta:        5
Media:      39
Bassa:      59
────────────
Totale:    103 aperte
```

---

## Top 10 Issue Critiche da Risolvere

| # | ID | Componente | Impatto | Effort |
|---|-----|------------|---------|--------|
| 1 | **DL-002** | DataLink | Build() senza validazione | S |
| 2 | **AL-003** | Application | Multi-device limitato | L |
| 3 | **TL-004** | Transport | Validazione input mancante | S |
| 4 | **BLE-003** | Drivers.Ble | Memory leak buffer RX | M |
| 5 | **CAN-003** | Drivers.Can | Race condition InitializeAsync | M |
| 6 | **CAN-017** | Drivers.Can | Timeout chunk incompleti | S |
| 7 | **CLI-001** | Client | PcanHardware.Dispose() sincrono | S |
| 8 | **PL-003** | Physical | Config buffer size ignorata | S |
| 9 | **STK-001** | Stack | Race condition Init/Shutdown | M |
| 10 | **NL-001** | Network | RoutingTable non thread-safe | M |

**Effort:** S = 1-2h, M = 4-8h, L = 2-3 giorni

---

## Metriche Qualità

| Aspetto | Stato | Note |
|---------|-------|------|
| Thread Safety | 95% | Pattern T-005 applicato |
| Resource Management | 95% | IDisposable via ProtocolLayerBase |
| Observability | 90% | Logging + Statistiche |
| Input Validation | 70% | Alcuni metodi mancano bounds check |
| Performance | 80% | PR-001/PR-002 risolti, rimangono allocazioni minori |
| Test Coverage | 96% | 2363 test passano |

---

## Come Contribuire

1. Seleziona issue da priorità alta
2. Crea branch: `fix/{issue-id}` (es. `fix/pr-001`)
3. Implementa soluzione proposta nel file ISSUES.md del layer
4. Aggiungi test
5. Aggiorna status issue a "Risolto" con data e branch
6. Pull Request

---

## Links

- [ISSUES_TEMPLATE.md](./Docs/ISSUES_TEMPLATE.md) - Template per nuove issue
- [THREAD_SAFETY.md](./Docs/THREAD_SAFETY.md) - Pattern thread safety
- [STATISTICS.md](./Docs/STATISTICS.md) - Sistema statistiche
- [LOGGING.md](./Docs/LOGGING.md) - Linee guida logging

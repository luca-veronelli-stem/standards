# PresentationLayer - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunita di refactoring e violazioni di best practice per il componente **PresentationLayer**.  

> **Ultimo aggiornamento:** 2026-02-25

---

## Riepilogo

| Priorita | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 1 | 3 |
| **Media** | 3 | 3 |
| **Bassa** | 4 | 2 |

**Totale aperte:** 8  
**Totale risolte:** 8

---

## Indice Issue Aperte

- [PR-016 - CryptoProvider SetKey Race Condition - Reference Counting](#pr-016---cryptoprovider-setkey-race-condition---reference-counting)
- [PR-004 - Magic Strings nei Metadata di LayerResult](#pr-004---magic-strings-nei-metadata-di-layerresult)
- [PR-005 - Validazione Input Mancante o Inconsistente](#pr-005---validazione-input-mancante-o-inconsistente)
- [PR-006 - Validazione Chiave Duplicata tra PresentationLayer e CryptoProvider](#pr-006---validazione-chiave-duplicata-tra-presentationlayer-e-cryptoprovider)
- [PR-008 - DefaultCryptType Configurazione Non Utilizzata](#pr-008---defaultcrypttype-configurazione-non-utilizzata)
- [PR-009 - PaddingHelper.RemovePadding Hardcoda Limite 16](#pr-009---paddinghelplerremovepadding-hardcoda-limite-16)
- [PR-011 - Migrazione da ECB a Modalita Crittografica Piu Sicura](#pr-011---migrazione-da-ecb-a-modalita-crittografica-piu-sicura)
- [PR-012 - Chiave AES di Default Hardcoded nel Codice Sorgente](#pr-012---chiave-aes-di-default-hardcoded-nel-codice-sorgente)

## Indice Issue Risolte

- [PR-001 - Performance Cache dei DataEncryptor](#pr-001---performance-cache-dei-dataencryptor)
- [PR-002 - Eliminare Clonazione Inutile della Chiave](#pr-002---eliminare-clonazione-inutile-della-chiave)
- [PR-015 - ProcessDownstreamAsync Non Registra Statistiche di Cifratura](#pr-015---processdownstreamasync-non-registra-statistiche-di-cifratura)
- [PR-014 - PresentationLayerStatistics Timestamp Non Thread-Safe](#pr-014---presentationlayerstatistics-timestamp-non-thread-safe)
- [PR-010 - Mancanza di Statistiche per Monitoraggio](#pr-010---mancanza-di-statistiche-per-monitoraggio)
- [PR-013 - Mancanza di Logging per Operazioni Crittografiche](#pr-013---mancanza-di-logging-per-operazioni-crittografiche)
- [PR-007 - PresentationLayer Non Supporta Dependency Injection per Logger](#pr-007---presentationlayer-non-supporta-dependency-injection-per-logger)
- [PR-003 - PresentationLayer Implementa IDisposable Correttamente](#pr-003---presentationlayer-implementa-idisposable-correttamente)

---

## Priorita Alta

### PR-016 - CryptoProvider SetKey Race Condition - Reference Counting

**Categoria:** Performance / Thread Safety  
**Priorita:** Alta  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-02-24  
**Workaround Attivo:** Si (deferred disposal via GC)

#### Descrizione

Il metodo `SetKey()` in `CryptoProvider` presentava una race condition: quando un thread chiamava `SetKey()` per cambiare chiave, il `DataEncryptor` cachato veniva disposto immediatamente. Tuttavia, altri thread che avevano già ottenuto un riferimento all'encryptor da `GetOrCreateEncryptor()` potevano continuare ad usarlo, causando `NullReferenceException` nel codice nativo BCrypt.

#### File Coinvolti

- `Protocol/Layers/PresentationLayer/Helpers/CryptoProvider.cs`

#### Workaround Implementato (Strategia A)

Rimosso il `Dispose()` immediato dell'encryptor in `SetKey()`. L'encryptor viene solo rimosso dalla cache e sarà rilasciato dal GC quando tutti i thread avranno terminato di usarlo.

```csharp
// Prima (race condition):
if (_encryptorCache.TryGetValue(cryptType, out var oldEncryptor))
{
    oldEncryptor.Dispose();  // BUG: altri thread potrebbero usarlo!
    _encryptorCache.Remove(cryptType);
}

// Dopo (workaround):
if (_encryptorCache.Remove(cryptType))
{
    // Non disporre: GC lo rilascerà quando non ci sono più riferimenti
}
```

#### Soluzione Definitiva Proposta (Strategia B)

Implementare **reference counting** per dispose deterministico:

1. Wrappare `DataEncryptor` in una classe `RefCountedEncryptor`
2. `GetOrCreateEncryptor()` incrementa il contatore
3. Ogni operazione di encrypt/decrypt decrementa alla fine
4. `SetKey()` marca come "obsoleto" e dispone solo quando count = 0
5. Pattern simile a `SafeHandle` in .NET

```csharp
internal sealed class RefCountedEncryptor : IDisposable
{
    private readonly DataEncryptor _encryptor;
    private int _refCount = 1;
    private bool _obsolete;

    public IDisposable Acquire()
    {
        Interlocked.Increment(ref _refCount);
        return new ReleaseHandle(this);
    }

    private void Release()
    {
        if (Interlocked.Decrement(ref _refCount) == 0 && _obsolete)
            _encryptor.Dispose();
    }

    public void MarkObsolete()
    {
        _obsolete = true;
        Release(); // Decrementa il count iniziale
    }
}
```

#### Trade-offs

| Aspetto | Workaround (A) | Soluzione Definitiva (B) |
|---------|----------------|-------------------------|
| Thread Safety | ✅ Garantita | ✅ Garantita |
| Dispose deterministico | ❌ Dipende da GC | ✅ Immediato quando possibile |
| Complessità | ✅ Minima | ⚠️ Media |
| Memory footprint | ⚠️ Encryptor rimane finché GC | ✅ Rilascio preciso |

#### Benefici Attesi (Strategia B)

- Dispose deterministico delle risorse crittografiche native
- Nessun ritardo dovuto al GC
- Pattern riutilizzabile per altre cache con risorse disposable

#### Note

Il workaround è accettabile perché:
1. `SetKey()` non dovrebbe essere chiamato frequentemente (idealmente solo all'init)
2. Gli encryptor sono piccoli (~100 bytes managed + handle nativo)
3. Il GC .NET è efficiente per oggetti con finalizer

---

## Priorita Media

### PR-004 - Magic Strings nei Metadata di LayerResult

**Categoria:** Code Smell  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

I metadata di `LayerResult` utilizzano stringhe hardcoded come chiavi, senza compile-time checking.

#### File Coinvolti

- `Protocol/Layers/PresentationLayer/PresentationLayer.cs` (righe 161-165)

#### Codice Problematico

```csharp
return Task.FromResult(LayerResult.Success(decrypted, new Dictionary<string, object>
{
    ["EncryptedSize"] = data.Length,
    ["DecryptedSize"] = decrypted.Length,
    ["CryptType"] = context.CryptType
}));
```

#### Soluzione Proposta

```csharp
public static class MetadataKeys
{
    public const string EncryptedSize = nameof(EncryptedSize);
    public const string DecryptedSize = nameof(DecryptedSize);
    public const string OriginalSize = nameof(OriginalSize);
    public const string CryptType = nameof(CryptType);
}
```

#### Benefici Attesi

- Compile-time checking
- IntelliSense support
- Riduzione errori typo

---

### PR-005 - Validazione Input Mancante o Inconsistente

**Categoria:** Bug  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

Validazione input inconsistente tra i vari metodi: DataEncryptor restituisce array vuoto per input null/vuoto invece di lanciare eccezione.

#### File Coinvolti

- `Protocol/Layers/PresentationLayer/Helpers/DataEncryptor.cs`

#### Benefici Attesi

- Comportamento prevedibile e documentato
- Fail-fast su input invalidi

---

### PR-006 - Validazione Chiave Duplicata tra PresentationLayer e CryptoProvider

**Categoria:** Code Smell  
**Priorita:** Media  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

Validazione della lunghezza chiave AES in due posti: `PresentationLayer` la valida silenziosamente e fa fallback su default, `CryptoProvider` lancia eccezione. Violazione DRY.

#### File Coinvolti

- `Protocol/Layers/PresentationLayer/PresentationLayer.cs` (righe 69-80)
- `Protocol/Layers/PresentationLayer/Helpers/CryptoProvider.cs` (righe 120-127)

#### Benefici Attesi

- DRY rispettato
- Errori espliciti invece di silent fallback

---

## Priorita Bassa

### PR-008 - DefaultCryptType Configurazione Non Utilizzata

**Categoria:** Code Smell  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

La proprieta `DefaultCryptType` in `PresentationLayerConfiguration` e' definita ma mai letta o utilizzata.

#### File Coinvolti

- `Protocol/Layers/PresentationLayer/Models/PresentationLayerConfiguration.cs`

#### Benefici Attesi

- Rimozione dead code o implementazione funzionalita

---

### PR-009 - PaddingHelper.RemovePadding Hardcoda Limite 16

**Categoria:** Code Smell  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

Il metodo `RemovePadding()` usa il valore hardcoded `16` per la validazione del padding invece di usare un parametro.

#### File Coinvolti

- `Protocol/Layers/PresentationLayer/Helpers/PaddingHelper.cs`

#### Benefici Attesi

- Nessun magic number
- Estensibile a blocchi di dimensioni diverse

---

### PR-011 - Migrazione da ECB a Modalita Crittografica Piu Sicura

**Categoria:** Security  
**Priorita:** Bassa  
**Impatto:** Medio  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

AES in modalita ECB e' considerato insicuro per dati > 1 blocco perche pattern identici nel plaintext producono pattern identici nel ciphertext.

#### File Coinvolti

- `Protocol/Layers/PresentationLayer/Helpers/AesEncryptor.cs`

#### Problema Specifico

- Compatibilita con implementazione C firmware richiede ECB
- BREAKING CHANGE se si cambia modalita

#### Benefici Attesi

- Sicurezza crittografica migliorata (lungo termine)
- Conformita best practices moderne

#### Note

Breve termine: Documentare il rischio, mantenere ECB per compatibilita.
Lungo termine: Pianificare migrazione in Protocol v3.

---

### PR-012 - Chiave AES di Default Hardcoded nel Codice Sorgente

**Categoria:** Security  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Aperto  
**Data Apertura:** 2026-01-26  

#### Descrizione

La chiave AES di default e' hardcoded nel codice sorgente e visibile nel repository. Se usata in produzione, compromette la sicurezza.

#### File Coinvolti

- `Protocol/Layers/PresentationLayer/Models/PresentationLayerConstants.cs`

#### Benefici Attesi

- Migliore security posture
- Protezione contro uso accidentale in produzione

---

## Issue Risolte

### PR-001 - Performance Cache dei DataEncryptor

**Categoria:** Performance  
**Priorita:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-02-06  
**Branch:** fix/pr-001  

#### Descrizione

Ad ogni operazione di encrypt/decrypt veniva creato un nuovo `DataEncryptor` + `AesEncryptor` + 2 `ICryptoTransform`. Per 1000 messaggi = 1000+ allocazioni + GC pressure elevata.

#### File Coinvolti

- `Protocol/Layers/PresentationLayer/Helpers/CryptoProvider.cs`

#### Soluzione Implementata

**Cache dei DataEncryptor con double-checked locking:**

1. Aggiunto campo `_encryptorCache` (`Dictionary<CryptType, DataEncryptor>`)
2. Implementato metodo `GetOrCreateEncryptor()` con pattern:
   - Fast path: ReadLock per cache hit
   - Slow path: WriteLock per creazione encryptor
   - Double-check dopo acquisizione WriteLock
3. `SetKey()` invalida e dispone encryptor cachato quando chiave cambia
4. `Dispose()` dispone tutti gli encryptor cachati
5. Rimosso metodo `GetKeyThreadSafe()` (non piu necessario)

**Codice implementato:**

```csharp
private DataEncryptor GetOrCreateEncryptor(CryptType cryptType)
{
    _keyLock.EnterReadLock();
    try
    {
        if (_encryptorCache.TryGetValue(cryptType, out var cached))
            return cached;
    }
    finally { _keyLock.ExitReadLock(); }

    _keyLock.EnterWriteLock();
    try
    {
        if (_encryptorCache.TryGetValue(cryptType, out var existing))
            return existing;

        var key = _keys[cryptType];
        var encryptor = new DataEncryptor(key);
        _encryptorCache[cryptType] = encryptor;
        return encryptor;
    }
    finally { _keyLock.ExitWriteLock(); }
}
```

#### Test Aggiunti

**Unit Tests - `CryptoProviderTests.cs` (7 test):**
- `Encrypt_MultipleCalls_ShouldReuseEncryptor`
- `SetKey_ShouldInvalidateCachedEncryptor`
- `Dispose_ShouldDisposeAllCachedEncryptors`
- `Encrypt_ConcurrentCalls_ShouldBeThreadSafe`
- `EncryptDecrypt_ConcurrentMixedCalls_ShouldBeThreadSafe`
- `SetKey_DuringConcurrentEncrypt_ShouldNotCrash`
- `SetKey_MultipleTimes_ShouldAlwaysUseLatestKey`

#### Benefici Ottenuti

- Riuso encryptor invece di ricrearli
- Riduzione allocazioni ~99% (da 624 bytes/op a ~0)
- Throughput migliorato per operazioni ad alta frequenza
- Minore GC pressure
- Thread-safety garantita con ReaderWriterLockSlim

---

### PR-002 - Eliminare Clonazione Inutile della Chiave

**Categoria:** Performance  
**Priorita:** Alta  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-02-06  
**Branch:** fix/pr-001  
**Dipendenze:** Risolto insieme a PR-001

#### Descrizione

La chiave veniva clonata ad ogni operazione di encrypt/decrypt tramite `GetKeyThreadSafe()`, creando allocazioni inutili (16 bytes per chiamata).

#### Soluzione Implementata

Il fix di PR-001 risolve implicitamente anche PR-002:
- Il metodo `GetKeyThreadSafe()` che faceva la clonazione e stato rimosso
- La chiave ora e usata solo una volta quando si crea l'encryptor cached
- Gli accessi successivi usano l'encryptor gia creato, senza toccare la chiave

#### Benefici Ottenuti

- Eliminazione allocazioni ripetute (16 bytes per chiamata)
- Codice piu semplice (meno metodi)

---

### PR-015 - ProcessDownstreamAsync Non Registra Statistiche di Cifratura

**Categoria:** Bug  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-02-05  
**Branch:** docs/aggiorna-issues  

#### Descrizione

`ProcessDownstreamAsync()` non registrava statistiche mentre `ProcessUpstreamAsync()` si.

#### Soluzione Implementata

Aggiunta registrazione statistiche in `ProcessDownstreamAsync()` (riga 247):

```csharp
var stopwatch = System.Diagnostics.Stopwatch.StartNew();
var encrypted = _cryptoProvider.Encrypt(data, context.CryptType);
stopwatch.Stop();

_statistics.RecordEncryption(encrypted.Length, stopwatch.ElapsedMilliseconds);
```

#### Benefici Ottenuti

- Statistiche complete per encrypt e decrypt
- Monitoring accurato

---

### PR-014 - PresentationLayerStatistics Timestamp Non Thread-Safe

**Categoria:** Bug  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-02-03  
**Branch:** fix/t-005  

#### Descrizione

Le proprieta `LastEncryptionAt`, `LastDecryptionAt` e `StartTime` erano `DateTime?` non atomiche.

#### Soluzione Implementata

Usato `long` (Ticks) con `Interlocked.Read/Exchange` per thread-safety lock-free. Conforme a pattern T-005.

#### Benefici Ottenuti

- Zero torn reads
- Lock-free performance
- Consistency con altri layer

---

### PR-010 - Mancanza di Statistiche per Monitoraggio

**Categoria:** Observability  
**Priorita:** Bassa  
**Impatto:** Basso  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-29  
**Branch:** fix/t-004  

#### Descrizione

Il PresentationLayer non tracciava alcuna statistica.

#### Soluzione Implementata

Creata classe `PresentationLayerStatistics` con metriche complete: DataEncrypted, DataDecrypted, BytesEncrypted, BytesDecrypted, timing, errori.

#### Benefici Ottenuti

- Monitoraggio performance
- Identificazione problemi

---

### PR-013 - Mancanza di Logging per Operazioni Crittografiche

**Categoria:** Observability  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-28  
**Branch:** fix/t-002  

#### Descrizione

Nessun logging di eventi critici per troubleshooting.

#### Soluzione Implementata

Logging strutturato aggiunto in tutti i metodi critici con livelli appropriati (Trace, Debug, Info, Warning, Error).

#### Benefici Ottenuti

- Troubleshooting facilitato
- Debugging semplificato

---

### PR-007 - PresentationLayer Non Supporta Dependency Injection per Logger

**Categoria:** Design  
**Priorita:** Media  
**Impatto:** Medio  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-28  
**Branch:** fix/t-002  

#### Descrizione

Il costruttore non accettava `ILogger`, rendendo impossibile il logging.

#### Soluzione Implementata

Aggiunto parametro `ILogger<PresentationLayer>?` nel costruttore (riga 54). Il logger viene passato anche a `CryptoProvider`.

#### Benefici Ottenuti

- Logging strutturato abilitato
- Testabilita migliorata

---

### PR-003 - PresentationLayer Implementa IDisposable Correttamente

**Categoria:** Resource Management  
**Priorita:** Alta  
**Impatto:** Alto  
**Status:** Risolto  
**Data Apertura:** 2026-01-26  
**Data Risoluzione:** 2026-01-27  
**Branch:** fix/t-001  

#### Descrizione

Mancata implementazione IDisposable causava potenziali resource leak.

#### Soluzione Implementata

`PresentationLayer` ora eredita da `ProtocolLayerBase` che implementa `IDisposable`. Il metodo `DisposeResources()` dispone correttamente il `CryptoProvider`.

Vedi issue trasversale T-001 per dettagli.

#### Benefici Ottenuti

- Dispose pattern completo
- Nessun resource leak

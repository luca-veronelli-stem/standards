# Standard Constants Configuration - Pattern Constants → Configuration → Layer

> **Versione:** 1.0  
> **Data:** 2026-02-13  
> **Riferimento Issue:** T-011  
> **Stato:** Active

---

## Scopo

Questo standard definisce il pattern architetturale per gestire costanti e configurazioni nei layer del protocollo, garantendo:

- **Consistenza** nel rapporto tra valori compile-time e runtime
- **Prevedibilità** nel comportamento dei default e override
- **Validazione** fail-fast dei parametri configurati

Si applica a: tutti i layer del protocollo con parametri configurabili.

---

## Principi Guida

1. **Separazione responsabilità:** Constants (compile-time) vs Configuration (runtime) vs Layer (uso)
2. **Default espliciti:** Ogni configurazione DEVE avere un default da costante
3. **Validazione obbligatoria:** Ogni Configuration DEVE avere `Validate()` con limiti da Constants
4. **Immutabilità post-init:** I valori nel layer sono immutabili dopo `InitializeAsync()`
5. **Fail-fast:** Validazione DEVE avvenire prima dell'uso dei valori

---

## Pattern Architetturale

```
┌──────────────────────────────────────────────────────────────────┐
│  COMPILE-TIME                         RUNTIME                    │
│                                                                  │
│  LayerConstants          LayerConfiguration          Layer       │
│  ┌─────────────┐         ┌─────────────────┐    ┌────────────┐   │
│  │ DEFAULT_*   │────────▶│ Property = DEF  │───▶│ _field     │   │
│  │ MAX_*       │         │                 │    │            │   │
│  │ MIN_*       │         │ Validate()      │    │            │   │
│  └─────────────┘         └─────────────────┘    └────────────┘   │
│                                                                  │
│  Immutabili              Mutabili pre-init      Immutabili       │
│  Valori default          Override opzionale     post-init        │
│  Limiti validazione                                              │
└──────────────────────────────────────────────────────────────────┘
```

---

## Regole

### Constants (`{Layer}Constants`)

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| CC-001 | ✅ DEVE | Usare `public const` o `public static readonly` |
| CC-002 | ✅ DEVE | Naming: `DEFAULT_*` per valori default |
| CC-003 | ✅ DEVE | Naming: `MAX_*`/`MIN_*` per limiti validazione |
| CC-004 | ✅ DEVE | Documentazione XML per ogni costante |
| CC-005 | ⚠️ DOVREBBE | Separare in due sezioni: Default e Limiti |

### Configuration (`{Layer}Configuration`)

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| CC-010 | ✅ DEVE | Ereditare da `LayerConfiguration` |
| CC-011 | ✅ DEVE | Ogni proprietà usa `DEFAULT_*` come valore iniziale |
| CC-012 | ✅ DEVE | Implementare metodo `Validate()` |
| CC-013 | ✅ DEVE | Validazione usa `MAX_*`/`MIN_*` da Constants |
| CC-014 | ⚠️ DOVREBBE | Usare `{ get; set; }` per mutabilità pre-init |

### Layer (uso configurazione)

| Regola | Livello | Descrizione |
|--------|---------|-------------|
| CC-020 | ✅ DEVE | `InitializeAsync` accetta `config` nullable |
| CC-021 | ✅ DEVE | Creare config default se `null` |
| CC-022 | ✅ DEVE | Chiamare `Validate()` prima di usare |
| CC-023 | ✅ DEVE | Copiare valori in campi privati (immutabilità post-init) |
| CC-024 | ❌ NON DEVE | Mai usare costanti direttamente nel layer dopo init |

---

## Esempi

### ✅ Uso Corretto - Constants

```csharp
public static class PhysicalLayerConstants
{
    // ═══════════════════════════════════════════════════════════════
    // VALORI DEFAULT - Usati se non specificato in configurazione
    // ═══════════════════════════════════════════════════════════════
    
    /// <summary>Dimensione default buffer TX.</summary>
    public const int DEFAULT_TX_BUFFER_SIZE = 1100;
    
    /// <summary>Dimensione default buffer RX.</summary>
    public const int DEFAULT_RX_BUFFER_SIZE = 1100;
    
    /// <summary>Timeout default per lettura canale (ms).</summary>
    public const int DEFAULT_READ_TIMEOUT_MS = 1000;
    
    // ═══════════════════════════════════════════════════════════════
    // LIMITI VALIDAZIONE - Non sovrascrivibili, usati per bounds check
    // ═══════════════════════════════════════════════════════════════
    
    /// <summary>Dimensione massima assoluta buffer.</summary>
    public const int MAX_BUFFER_SIZE = 65535;
    
    /// <summary>Dimensione minima buffer.</summary>
    public const int MIN_BUFFER_SIZE = 64;
    
    /// <summary>Timeout minimo (ms).</summary>
    public const int MIN_TIMEOUT_MS = 100;
    
    /// <summary>Timeout massimo (ms).</summary>
    public const int MAX_TIMEOUT_MS = 30000;
}
```

### ✅ Uso Corretto - Configuration con Validate()

```csharp
/// <summary>
/// Configurazione per il PhysicalLayer.
/// </summary>
/// <remarks>
/// Le proprietà usano i valori di default da <see cref="PhysicalLayerConstants"/>.
/// Modificare prima di chiamare <see cref="PhysicalLayer.InitializeAsync"/>.
/// </remarks>
public class PhysicalLayerConfiguration : LayerConfiguration
{
    /// <summary>Dimensione buffer TX in bytes.</summary>
    public int TxBufferSize { get; set; } = PhysicalLayerConstants.DEFAULT_TX_BUFFER_SIZE;
    
    /// <summary>Dimensione buffer RX in bytes.</summary>
    public int RxBufferSize { get; set; } = PhysicalLayerConstants.DEFAULT_RX_BUFFER_SIZE;
    
    /// <summary>Timeout lettura canale in millisecondi.</summary>
    public int ReadTimeoutMs { get; set; } = PhysicalLayerConstants.DEFAULT_READ_TIMEOUT_MS;
    
    /// <summary>
    /// Valida la configurazione.
    /// </summary>
    /// <exception cref="ArgumentOutOfRangeException">Se un valore è fuori dai limiti.</exception>
    public void Validate()
    {
        if (TxBufferSize < PhysicalLayerConstants.MIN_BUFFER_SIZE ||
            TxBufferSize > PhysicalLayerConstants.MAX_BUFFER_SIZE)
        {
            throw new ArgumentOutOfRangeException(
                nameof(TxBufferSize),
                TxBufferSize,
                $"Must be between {PhysicalLayerConstants.MIN_BUFFER_SIZE} " +
                $"and {PhysicalLayerConstants.MAX_BUFFER_SIZE}");
        }
        
        if (ReadTimeoutMs < PhysicalLayerConstants.MIN_TIMEOUT_MS ||
            ReadTimeoutMs > PhysicalLayerConstants.MAX_TIMEOUT_MS)
        {
            throw new ArgumentOutOfRangeException(
                nameof(ReadTimeoutMs),
                ReadTimeoutMs,
                $"Must be between {PhysicalLayerConstants.MIN_TIMEOUT_MS} " +
                $"and {PhysicalLayerConstants.MAX_TIMEOUT_MS}");
        }
    }
}
```

### ✅ Uso Corretto - Layer InitializeAsync

```csharp
public class PhysicalLayer : ProtocolLayerBase
{
    // Campi privati - immutabili dopo InitializeAsync
    private int _txBufferSize;
    private int _rxBufferSize;
    private int _readTimeoutMs;
    
    public override async Task<bool> InitializeAsync(LayerConfiguration? config = null)
    {
        ThrowIfDisposed();
        
        // 1. Ottieni configurazione (default se null)
        var layerConfig = config as PhysicalLayerConfiguration 
            ?? new PhysicalLayerConfiguration();
        
        // 2. Valida
        layerConfig.Validate();
        
        // 3. Copia in campi privati (immutabili dopo questo punto)
        _txBufferSize = layerConfig.TxBufferSize;
        _rxBufferSize = layerConfig.RxBufferSize;
        _readTimeoutMs = layerConfig.ReadTimeoutMs;
        
        // 4. Inizializza risorse usando i valori configurati
        _txBuffer = new ProtocolTxBuffer(_txBufferSize);
        _rxBuffer = new ProtocolRxBuffer(_rxBufferSize);
        
        IsInitialized = true;
        return true;
    }
}
```

### ✅ Uso Corretto - Scenari utente

```csharp
// Scenario 1: Tutti i default
var stack = new ProtocolStackBuilder()
    .WithChannelDriver(driver)
    .Build();
await stack.InitializeAsync();
// → TxBufferSize = 1100 (da DEFAULT_TX_BUFFER_SIZE)

// Scenario 2: Override parziale
var stack = new ProtocolStackBuilder()
    .WithChannelDriver(driver)
    .WithPhysicalLayerConfiguration(new PhysicalLayerConfiguration
    {
        TxBufferSize = 2048,  // Override esplicito
        // RxBufferSize = 1100 (default)
        // ReadTimeoutMs = 1000 (default)
    })
    .Build();

// Scenario 3: Valore invalido → eccezione chiara
var config = new PhysicalLayerConfiguration
{
    TxBufferSize = 999999  // Supera MAX_BUFFER_SIZE
};
config.Validate(); 
// → ArgumentOutOfRangeException: "TxBufferSize must be between 64 and 65535"
```

### ❌ Uso Scorretto - Costanti senza sezioni

```csharp
public static class BadConstants
{
    // ❌ Manca separazione DEFAULT vs LIMITS
    public const int BUFFER_SIZE = 1100;      // È un default? Un limite?
    public const int TIMEOUT = 1000;          // Confuso
    
    // ❌ Manca documentazione XML
    public const int MAX_SIZE = 65535;
}
```

### ❌ Uso Scorretto - Configuration senza Validate

```csharp
public class BadConfiguration : LayerConfiguration
{
    public int BufferSize { get; set; } = 1100;
    
    // ❌ Manca Validate() - valori invalidi non rilevati!
}
```

### ❌ Uso Scorretto - Layer usa costanti direttamente

```csharp
public override Task<bool> InitializeAsync(LayerConfiguration? config)
{
    // ❌ Ignora completamente la configurazione passata!
    _txBuffer = new ProtocolTxBuffer(PhysicalLayerConstants.DEFAULT_TX_BUFFER_SIZE);
    return Task.FromResult(true);
}
```

---

## Stato Attuale per Layer

| Layer | Constants | Configuration | Validate() | InitializeAsync | Status |
|-------|:---------:|:-------------:|:----------:|:---------------:|:------:|
| PhysicalLayer | ⚠️ | ⚠️ | ❌ | ⚠️ | Da fixare |
| DataLinkLayer | ❌ | ❌ | ❌ | ✅ | Da creare |
| NetworkLayer | ✅ | ✅ | ❌ | ⚠️ | Manca Validate |
| TransportLayer | ✅ | ✅ | ❌ | ⚠️ | Manca Validate |
| SessionLayer | ✅ | ✅ | ❌ | ⚠️ | Manca Validate |
| PresentationLayer | ⚠️ | ✅ | ❌ | ⚠️ | Manca Validate |
| ApplicationLayer | ✅ | ✅ | ❌ | ⚠️ | Manca Validate |

**Legenda:** ✅ Conforme | ⚠️ Parziale | ❌ Manca

---

## Checklist per Layer

Per ogni layer, verificare:

**Constants:**
- [ ] Sezione `DEFAULT_*` con tutti i valori default
- [ ] Sezione `MAX_*`/`MIN_*` con limiti validazione
- [ ] Documentazione XML per ogni costante

**Configuration:**
- [ ] Eredita da `LayerConfiguration`
- [ ] Ogni proprietà usa `DEFAULT_*` come valore iniziale
- [ ] Metodo `Validate()` implementato
- [ ] Validazione usa `MAX_*`/`MIN_*`

**Layer:**
- [ ] `InitializeAsync` accetta `config` nullable
- [ ] Crea config default se `null`
- [ ] Chiama `Validate()` prima di usare
- [ ] Copia valori in campi privati

---

## Eccezioni

| Componente | Eccezione | Motivazione |
|------------|-----------|-------------|
| `DataLinkLayer` | Nessuna Configuration | Parametri fissi da specifica protocollo (CRC, header size) |
| Constants di protocollo | Non sovrascrivibili | Frame format, CRC polynomial - definiti da specifica |

---

## Enforcement

- [ ] **Code Review:** Verificare pattern Constants → Configuration → Layer
- [ ] **Code Review:** Ogni Configuration ha `Validate()`
- [ ] **Test:** Test parametrizzati con config custom verificano applicazione
- [ ] **Test:** Test con valori fuori range verificano eccezione da Validate()

---

## Riferimenti

- `Protocol/Layers/Base/LayerConfiguration.cs` - Classe base configurazione
- `Protocol/Layers/*/Constants/` - Classi costanti per layer
- `Protocol/Layers/*/Configuration/` - Classi configurazione per layer
- `Protocol/HELPER_LIFECYCLE.md` - Pattern correlato per helper

---

## Changelog

| Data | Versione | Descrizione |
|------|----------|-------------|
| 2026-02-13 | 1.0 | Conversione da issue T-011 a standard attivo |
| 2026-02-06 | 0.1 | Bozza iniziale come issue T-011 |

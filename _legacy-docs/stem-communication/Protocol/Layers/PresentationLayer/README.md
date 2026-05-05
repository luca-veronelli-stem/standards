# Presentation Layer (Layer 6)

## Panoramica

Il **Presentation Layer** è il sesto livello dello stack protocollare STEM, corrispondente al Layer 6 del modello OSI. Si occupa della crittografia e decrittografia dei dati, della gestione delle chiavi e della trasformazione del formato dei dati per garantire la confidenzialità delle comunicazioni.

> **Ultimo aggiornamento:** 2026-02-25

---

## Responsabilità

- **Crittografia AES-128** in modalità ECB con padding PKCS7
- **Decrittografia** e rimozione automatica del padding
- **Gestione chiavi** per diversi tipi di crittografia (CryptType)
- **Passthrough** per comunicazioni non crittografate (NO_CRYPT)
- **Cache encryptor** per ottimizzazione performance (PR-001)
- **Raccolta statistiche** su operazioni crittografiche, bytes e performance

---

## Architettura

```
PresentationLayer/
├── PresentationLayer.cs                    # Implementazione principale del layer
├── Helpers/
│   ├── CryptoProvider.cs                   # Gestione chiavi e cache encryptor
│   ├── DataEncryptor.cs                    # Crittografia/decrittografia multi-blocco
│   ├── AesEncryptor.cs                     # Encryptor AES-128 ECB singolo blocco
│   └── PaddingHelper.cs                    # Helper padding PKCS7
└── Models/
    ├── PresentationLayerConfiguration.cs   # Configurazione runtime
    ├── PresentationLayerConstants.cs       # Costanti AES
    └── PresentationLayerStatistics.cs      # Statistiche aggregate
```

---

## Formato Dati

### Trasformazione Crittografica

```
┌─────────────────────────────────────────────────────────────┐
│                    Plaintext (N bytes)                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ Padding PKCS7
┌─────────────────────────────────────────────────────────────┐
│              Plaintext + Padding (multiplo di 16)           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ AES-128 ECB
┌─────────────────────────────────────────────────────────────┐
│                   Ciphertext (multiplo di 16)               │
└─────────────────────────────────────────────────────────────┘
```

### Padding PKCS7

| Input Size | Padding Bytes | Esempio |
|------------|---------------|---------|
| 14 bytes | 2 bytes `[0x02, 0x02]` | `[data...][0x02][0x02]` |
| 15 bytes | 1 byte `[0x01]` | `[data...][0x01]` |
| 16 bytes | 16 bytes `[0x10 × 16]` | `[data...][0x10...]` |
| 17 bytes | 15 bytes `[0x0F × 15]` | `[data...][0x0F...]` |

**Nota:** Il padding viene **sempre** aggiunto, anche quando i dati sono già multipli di 16 bytes.

---

## Componenti Principali

### PresentationLayer

Classe principale che eredita da `ProtocolLayerBase`. Orchestra il `CryptoProvider` per gestire crittografia e decrittografia.

```csharp
public class PresentationLayer : ProtocolLayerBase
{
    public override string LayerName => "Presentation";
    public override int LayerLevel => 6;
}
```

**Metodi pubblici aggiuntivi:**
- `SetKey(CryptType, byte[])` - Imposta chiave per tipo di crittografia
- `HasKey(CryptType)` - Verifica se una chiave è configurata

### Helper: CryptoProvider

Gestisce le chiavi di crittografia e mantiene una cache di `DataEncryptor` per performance ottimali.

**Metodi principali:**
- `SetKey(CryptType, byte[])` - Configura chiave (invalida cache)
- `Encrypt(CryptType, byte[])` - Cripta dati
- `Decrypt(CryptType, byte[])` - Decripta dati
- `HasKey(CryptType)` - Verifica disponibilità chiave

**Pattern PR-001:** Cache con `ReaderWriterLockSlim` per double-checked locking.

### Helper: DataEncryptor

Gestisce crittografia/decrittografia multi-blocco con padding PKCS7.

**Metodi principali:**
- `Encrypt(byte[])` - Aggiunge padding e cripta
- `Decrypt(byte[])` - Decripta e rimuove padding

### Helper: AesEncryptor

Wrapper per `System.Security.Cryptography.Aes` in modalità ECB.

**Metodi principali:**
- `EncryptBlock(byte[])` - Cripta singolo blocco 16 bytes
- `DecryptBlock(byte[])` - Decripta singolo blocco 16 bytes

### Helper: PaddingHelper

Helper statico per gestione padding PKCS7.

**Metodi principali:**
- `AddPadding(byte[], int)` - Aggiunge padding
- `RemovePadding(byte[])` - Rimuove e valida padding

---

## Configurazione

Classe: `PresentationLayerConfiguration`

| Proprietà | Tipo | Default | Descrizione |
|-----------|------|---------|-------------|
| `DefaultCryptType` | `CryptType` | `NO_CRYPT` | Tipo crittografia predefinito |
| `AesKey` | `byte[]?` | `null` | Chiave AES personalizzata (16 bytes) |

### Validazione

Il metodo `Validate()` verifica:
- `AesKey` (se fornita) deve essere esattamente 16 bytes
- `DefaultCryptType` deve essere un valore valido dell'enum

### Esempio

```csharp
var config = new PresentationLayerConfiguration
{
    DefaultCryptType = CryptType.AES128,
    AesKey = new byte[] { 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
                          0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F }
};
config.Validate(); // Lancia ArgumentException se AesKey.Length != 16
```

---

## Costanti

Classe: `PresentationLayerConstants`

### Costanti Protocollo (Standard AES)

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `AES_BLOCK_SIZE` | `16` | Dimensione blocco AES in bytes |
| `AES_KEY_SIZE` | `16` | Dimensione chiave AES-128 in bytes |

### Valori Default

| Costante | Tipo | Descrizione |
|----------|------|-------------|
| `DEFAULT_AES_KEY` | `byte[16]` | Chiave AES predefinita (solo sviluppo!) |

**⚠️ Attenzione:** La chiave di default deve essere sostituita in produzione.

---

## Flusso Dati

### Downstream (Trasmissione - Crittografia)

```
ApplicationLayer (Layer 7)
      │
      ▼
┌──────────────────────────────┐
│   ProcessDownstreamAsync     │
│   ─────────────────────────  │
│   1. Verifica CryptType      │
│   2. [NO_CRYPT] → Passthrough│
│   3. [AES128] → Padding      │
│   4. [AES128] → Encrypt      │
│   5. Aggiorna statistiche    │
└──────────────────────────────┘
      │
      ▼
SessionLayer (Layer 5)
```

### Upstream (Ricezione - Decrittografia)

```
SessionLayer (Layer 5)
      │
      ▼
┌──────────────────────────────┐
│   ProcessUpstreamAsync       │
│   ─────────────────────────  │
│   1. Verifica CryptType      │
│   2. [NO_CRYPT] → Passthrough│
│   3. [AES128] → Decrypt      │
│   4. [AES128] → Remove pad   │
│   5. Aggiorna statistiche    │
└──────────────────────────────┘
      │
      ▼
ApplicationLayer (Layer 7)
```

---

## Statistiche

Classe: `PresentationLayerStatistics`

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `DataEncrypted` | `long` | Operazioni di crittografia eseguite |
| `DataDecrypted` | `long` | Operazioni di decrittografia eseguite |
| `BytesEncrypted` | `long` | Totale bytes crittografati |
| `BytesDecrypted` | `long` | Totale bytes decrittografati |
| `EncryptionErrors` | `long` | Errori durante crittografia |
| `DecryptionErrors` | `long` | Errori durante decrittografia |
| `PaddingErrors` | `long` | Errori di padding PKCS7 |
| `TotalEncryptionTimeMs` | `long` | Tempo totale crittografia (ms) |
| `TotalDecryptionTimeMs` | `long` | Tempo totale decrittografia (ms) |
| `LastEncryptionAt` | `DateTime?` | Timestamp ultima crittografia |
| `LastDecryptionAt` | `DateTime?` | Timestamp ultima decrittografia |

### Accesso

```csharp
var stats = (PresentationLayerStatistics)layer.Statistics;
Console.WriteLine($"Bytes crittografati: {stats.BytesEncrypted}");
Console.WriteLine($"Errori padding: {stats.PaddingErrors}");
```

---

## Esempi di Utilizzo

### Inizializzazione Base (Senza Crittografia)

```csharp
var layer = new PresentationLayer();
await layer.InitializeAsync();

// La chiave di default viene utilizzata, ma DefaultCryptType = NO_CRYPT
```

### Con Crittografia AES Abilitata

```csharp
var customKey = new byte[] { 
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F 
};

var config = new PresentationLayerConfiguration
{
    DefaultCryptType = CryptType.AES128,
    AesKey = customKey
};

var layer = new PresentationLayer();
await layer.InitializeAsync(config);
```

### Impostazione Chiave Runtime

```csharp
var layer = new PresentationLayer();
await layer.InitializeAsync();

// Imposta chiave dopo inizializzazione
layer.SetKey(CryptType.AES128, mySecureKey);

// Verifica disponibilità
if (layer.HasKey(CryptType.AES128))
{
    Console.WriteLine("Chiave AES configurata");
}
```

### Processamento Dati

```csharp
// Crittografia (downstream)
var context = new LayerContext 
{ 
    Direction = FlowDirection.Downstream,
    Metadata = new MessageMetadata { CryptType = CryptType.AES128 }
};
var result = await layer.ProcessDownstreamAsync(plaintext, context);

// Decrittografia (upstream)
context.Direction = FlowDirection.Upstream;
var decrypted = await layer.ProcessUpstreamAsync(ciphertext, context);
```

---

## Algoritmo AES-128 ECB

### Caratteristiche

| Parametro | Valore |
|-----------|--------|
| **Algoritmo** | AES (Advanced Encryption Standard) |
| **Dimensione chiave** | 128 bit (16 bytes) |
| **Dimensione blocco** | 128 bit (16 bytes) |
| **Modalità** | ECB (Electronic Codebook) |
| **Padding** | PKCS7 |

### Perché ECB?

La modalità **ECB** è utilizzata per compatibilità con l'implementazione C del firmware:

- Ogni blocco viene crittografato indipendentemente
- Nessun vettore di inizializzazione (IV) richiesto
- Comportamento deterministico (stesso input → stesso output)

**Mitigazione rischi ECB:**
- I chunk dal TransportLayer contengono già metadati variabili (PacketId, RemainingChunks)
- Ogni messaggio ha timestamp e counter unici
- Pattern ripetitivi sono rari nel protocollo STEM

---

## Limitazioni Note

### PR-016: SetKey durante operazioni concorrenti

Chiamare `SetKey()` mentre altri thread eseguono operazioni di crittografia è **thread-safe** ma con un trade-off:

- L'encryptor invalidato **non viene disposto immediatamente** per evitare race condition
- Le risorse native vengono rilasciate dal **GC** quando non ci sono più riferimenti
- Questo può causare un **ritardo nel rilascio** delle risorse crittografiche

**Raccomandazione:** Impostare le chiavi durante l'inizializzazione, prima di iniziare operazioni concorrenti.

**Roadmap:** Vedi [PR-016](./ISSUES.md#pr-016---cryptoprovider-setkey-race-condition---reference-counting) per implementazione futura con reference counting.

---

## Issue Correlate

→ [PresentationLayer/ISSUES.md](./ISSUES.md)

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| Alta | 1 | 3 |
| Media | 3 | 3 |
| Bassa | 4 | 2 |
| **Totale** | **8** | **8** |

### Issue Aperte Principali

| ID | Titolo | Priorità |
|----|--------|----------|
| PR-016 | CryptoProvider SetKey Race Condition - Reference Counting | Alta |
| PR-005 | Validazione Input Mancante o Inconsistente | Media |
| PR-006 | Validazione Chiave Duplicata | Media |
| PR-008 | DefaultCryptType Configurazione Non Utilizzata | Media |
| PR-011 | Migrazione da ECB a Modalità Più Sicura | Bassa |

### Issue Risolte Recenti

| ID | Titolo | Data |
|----|--------|------|
| PR-001 | GC Pressure da Allocazioni Ripetute | 2026-02-06 |
| PR-002 | DataEncryptor Non Riutilizzato | 2026-02-06 |
| PR-015 | ProcessDownstreamAsync Non Registra Statistiche | 2026-02-05 |

---

## Riferimenti Firmware C

| Componente C# | File C | Struttura/Funzione |
|---------------|--------|-------------------|
| `PresentationLayer` | `SP_Crypt.c` | `SP_Crypt_Encrypt/Decrypt()` |
| `AesEncryptor` | `SP_Crypt.c` | `SP_Crypt_AES128_ECB()` |
| `DEFAULT_AES_KEY` | `SP_Crypt.h` | `ChiaveAES[]` |
| `AES_BLOCK_SIZE` | `SP_Crypt.h` | `AES_BLOCK_SIZE` |

**Repository:** `stem-fw-protocollo-seriale-stem/` (read-only)

---

## Links

- [Stack README](../Stack/README.md) - Orchestrazione layer
- [Base README](../Base/README.md) - Interfacce e classi base

# Standard Commenti - Documentazione XML e Inline

> **Versione:** 1.1  
> **Data:** 2026-02-12  
> **Riferimento Issue:** T-018  
> **Stato:** Active

---

## Scopo

Questo standard definisce le regole per la documentazione del codice nel progetto STEM Communication Protocol, garantendo:

1. **Zero warning CS1591** (missing XML comment) in build Release
2. **Documentazione IntelliSense** completa per consumatori API
3. **Consistenza** nello stile e nella lingua dei commenti
4. **Manutenibilità** con commenti che spiegano il "perché", non il "cosa"

**Si applica a:** Protocol, Drivers.Can, Drivers.Ble, Client

**Riferimenti industriali:**
- [Microsoft XML Documentation Comments](https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/xmldoc/)
- [StyleCop SA1600-SA1650 Documentation Rules](https://github.com/DotNetAnalyzers/StyleCopAnalyzers/blob/master/documentation/DocumentationRules.md)
- [Framework Design Guidelines - Documentation](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/documentation-guidelines)

---

## Principi Guida

1. **Document What, Explain Why:** XML docs descrivono cosa fa il codice; commenti inline spiegano perché
2. **Italian for All:** Tutta la documentazione in italiano
3. **Complete but Concise:** Ogni tag necessario, nessuna verbosità inutile
4. **Living Documentation:** Aggiornare docs quando cambia il codice

---

## Regole

### R-001: Copertura Obbligatoria

| Visibilità | Copertura | Livello |
|------------|-----------|---------|
| `public` types/members | ✅ DEVE avere XML docs completi | Obbligatorio |
| `protected` members | ✅ DEVE avere XML docs | Obbligatorio |
| `internal` types/members | ⚠️ DOVREBBE avere `<summary>` | Raccomandato |
| `private` members | 💡 PUÒ avere commenti inline | Opzionale |

### R-002: Tag XML Obbligatori

| Contesto | Tag Richiesti | Livello |
|----------|--------------|---------|
| Tutti i tipi | `<summary>` | ✅ DEVE |
| Metodi con parametri | `<summary>`, `<param>` per ogni parametro | ✅ DEVE |
| Metodi non-void | `<returns>` | ✅ DEVE |
| Metodi che lanciano eccezioni | `<exception cref="">` | ⚠️ DOVREBBE |
| Tipi complessi | `<remarks>` con contesto aggiuntivo | ⚠️ DOVREBBE |
| API con esempi utili | `<example>` | 💡 PUÒ |
| Membri obsoleti | `<see cref="">` al replacement | ✅ DEVE |

### R-003: Lingua

| Contesto | Lingua | Livello |
|----------|--------|---------|
| XML docs su API `public`/`protected` | Italiano | ✅ DEVE |
| XML docs su API `internal` | Italiano | ✅ DEVE |
| Commenti inline (`//`) | Italiano | ✅ DEVE |
| TODO/FIXME/HACK | Italiano | ✅ DEVE |

### R-004: Formato `<summary>`

| Regola | Livello |
|--------|---------|
| Prima lettera maiuscola | ✅ DEVE |
| Termina con punto | ✅ DEVE |
| Una sola frase (max 2) | ⚠️ DOVREBBE |
| Non iniziare con "Questo metodo/classe..." | ⚠️ DOVREBBE |
| Usare terza persona ("Ottiene", "Imposta", "Inizializza") | ⚠️ DOVREBBE |

### R-005: Formato `<param>`

| Regola | Livello |
|--------|---------|
| Prima lettera minuscola (è continuazione) | ⚠️ DOVREBBE |
| Descrizione concisa del parametro | ✅ DEVE |
| Indicare valori speciali (`null`, default) | ⚠️ DOVREBBE |
| Usare `<paramref name="">` per riferirsi ad altri parametri | 💡 PUÒ |

### R-006: Formato `<returns>`

| Regola | Livello |
|--------|---------|
| Descrizione del valore restituito | ✅ DEVE |
| Indicare `null` se possibile | ✅ DEVE |
| Per `bool`: spiegare cosa significa `true`/`false` | ✅ DEVE |
| Per `Task<T>`: documentare `T`, non `Task` | ⚠️ DOVREBBE |

### R-007: `<remarks>` per Contesto

Usare `<remarks>` per:
- Thread-safety notes
- Performance considerations
- Side effects
- Relazioni con altri componenti
- Riferimenti a issue/pattern (`T-005`, `PL-016`)

```xml
/// <remarks>
/// <para>Thread-safe: usa Interlocked per i contatori.</para>
/// <para><b>Pattern T-005:</b> DateTime memorizzato come Ticks.</para>
/// </remarks>
```

### R-008: Commenti Inline

| Tipo | Uso | Formato |
|------|-----|---------|
| `//` | Spiegazioni brevi | `// Motivo della scelta` |
| `// TODO:` | Lavoro futuro | `// TODO: T-014 - Unificare codec` |
| `// HACK:` | Workaround temporaneo | `// HACK: BLE-019 - Buffer accumulo` |
| `// FIXME:` | Bug noto | `// FIXME: CAN-003 - Race condition` |
| `// NOTE:` | Informazione importante | `// NOTE: Big Endian come da protocollo C` |

### R-009: Cosa NON Commentare

| Anti-Pattern | Livello |
|--------------|---------|
| Commenti ovvi (`// Incrementa il contatore`) | ❌ NON DEVE |
| Codice commentato | ❌ NON DEVE |
| Commenti non aggiornati | ❌ NON DEVE |
| Changelog nei commenti | ❌ NON DEVE (usare Git) |

### R-010: Escaping Caratteri Speciali XML

I seguenti caratteri devono essere escaped nei commenti XML:

| Carattere | Escape | Alternativa |
|-----------|--------|-------------|
| `<` | `&lt;` | Usare `<code>` block |
| `>` | `&gt;` | Usare `<code>` block |
| `&` | `&amp;` | Usare `<code>` block |
| `->` | `-&gt;` | Scrivere in `<code>` |
| `<<` | N/A | Usare `shl` |
| `>>` | N/A | Usare `shr` |
| `& ~()` | N/A | Usare `AND NOT()` |

**Esempio codice C nei remarks:**
```xml
/// <remarks>
/// <para>In C corrisponde a:</para>
/// <code>
/// adr = rec-&gt;addr;
/// OSwordSwap(&amp;adr);
/// </code>
/// </remarks>
```

### R-011: Riferimenti `cref` Fully Qualified

Usare nomi fully qualified per `<see cref="...">` se il tipo non è importato con `using`:

| Caso | Esempio | Livello |
|------|---------|---------|
| Tipo non importato | `<see cref="Base.Enums.LayerStatus.Success"/>` | ✅ DEVE |
| Tipo importato | `<see cref="LayerStatus.Success"/>` | ✅ DEVE |
| Tipo ambiguo (overload) | Usare `<c>Volatile.Read</c>` | ⚠️ DOVREBBE |

---

## Template

### Template Classe/Interface

```csharp
/// <summary>
/// Breve descrizione di cosa fa la classe/interfaccia.
/// </summary>
/// <remarks>
/// <para>Contesto aggiuntivo sull'utilizzo o comportamento.</para>
/// <para><b>Thread-safety:</b> [Thread-safe | Non thread-safe | Descrizione].</para>
/// <para><b>Pattern:</b> [Nome pattern se applicabile].</para>
/// </remarks>
/// <example>
/// <code>
/// var instance = new MyClass();
/// instance.FaiQualcosa();
/// </code>
/// </example>
public class MyClass
```

### Template Metodo

```csharp
/// <summary>
/// Breve descrizione di cosa fa il metodo.
/// </summary>
/// <param name="param1">descrizione del primo parametro.</param>
/// <param name="param2">descrizione del secondo parametro, oppure <c>null</c> per default.</param>
/// <returns>Descrizione del valore restituito, oppure <c>null</c> se condizione.</returns>
/// <exception cref="ArgumentNullException">Quando <paramref name="param1"/> è null.</exception>
/// <exception cref="InvalidOperationException">Quando non inizializzato.</exception>
/// <remarks>
/// <para>Contesto aggiuntivo se necessario.</para>
/// </remarks>
public ResultType MethodName(ParamType param1, ParamType? param2 = null)
```

### Template Proprietà

```csharp
/// <summary>
/// Ottiene [o imposta] la descrizione della proprietà.
/// </summary>
/// <remarks>Thread-safe: usa Volatile.Read.</remarks>
public PropertyType PropertyName { get; }
```

### Template Enum

```csharp
/// <summary>
/// Descrive cosa rappresenta questo enum.
/// </summary>
public enum MyEnum
{
    /// <summary>Descrizione del valore None.</summary>
    None = 0,

    /// <summary>Descrizione del primo valore.</summary>
    PrimoValore = 1,

    /// <summary>Descrizione del secondo valore.</summary>
    SecondoValore = 2
}
```

### Template Eccezione

```csharp
/// <summary>
/// Eccezione lanciata quando [condizione].
/// </summary>
/// <remarks>
/// <para><see cref="IsRecoverable"/> indica se è possibile riprovare.</para>
/// </remarks>
public class MyException : Exception
{
    /// <summary>
    /// Inizializza una nuova istanza con il messaggio specificato.
    /// </summary>
    /// <param name="message">descrizione dell'errore.</param>
    public MyException(string message) : base(message) { }
}
```

---

## Esempi

### ✅ Uso Corretto

```csharp
/// <summary>
/// Calcola il checksum CRC16 usando il polinomio Modbus.
/// </summary>
/// <param name="data">buffer dati su cui calcolare il checksum.</param>
/// <returns>Valore CRC a 16 bit in formato big-endian.</returns>
/// <remarks>
/// <para>Usa polinomio 0xA001 con valore iniziale 0xFFFF.</para>
/// <para><b>Thread-safe:</b> Nessuno stato condiviso, sicuro per uso concorrente.</para>
/// </remarks>
internal static ushort CalculateCrc16(ReadOnlySpan<byte> data)
{
    // Algoritmo Modbus standard - compatibile con firmware C
    ushort crc = 0xFFFF;

    foreach (byte b in data)
    {
        crc ^= b;
        for (int i = 0; i < 8; i++)
        {
            // Shift e XOR condizionale
            crc = (crc & 1) != 0 ? (ushort)((crc >> 1) ^ 0xA001) : (ushort)(crc >> 1);
        }
    }

    return crc;
}

/// <summary>
/// Ottiene lo stato corrente della connessione.
/// </summary>
/// <remarks>Thread-safe: usa Volatile.Read secondo T-005.</remarks>
public bool IsConnected => Volatile.Read(ref _isConnected);

/// <summary>
/// Invia dati al dispositivo destinatario specificato.
/// </summary>
/// <param name="data">payload da inviare (max 1000 bytes).</param>
/// <param name="destinationId">SRID del dispositivo target, oppure <see cref="StemDevice.BROADCAST"/> per tutti.</param>
/// <param name="cancellationToken">token per cancellare l'operazione.</param>
/// <returns><c>true</c> se inviato con successo; <c>false</c> se il canale non è disponibile.</returns>
/// <exception cref="ArgumentNullException">Quando <paramref name="data"/> è null.</exception>
/// <exception cref="ArgumentException">Quando <paramref name="data"/> supera la dimensione massima.</exception>
/// <exception cref="ChannelNotConnectedException">Quando il canale non è connesso.</exception>
public async Task<bool> SendAsync(
    byte[] data, 
    uint destinationId, 
    CancellationToken cancellationToken = default)
```

### ❌ Uso Scorretto

```csharp
// ❌ XML docs mancanti su membro pubblico
public bool IsConnected { get; }

// ❌ Commento ovvio - aggiunge zero valore
/// <summary>
/// Ottiene il conteggio.
/// </summary>
public int Count { get; }  // Dovrebbe spiegare "conteggio di cosa"

// ❌ Commento che ripete il codice
// Incrementa _counter di 1
Interlocked.Increment(ref _counter);

// ❌ Commento non aggiornato
// Ritorna sempre true  <-- Ma il codice può ritornare false!
public bool TryConnect() { return _channel?.IsOpen ?? false; }

// ❌ Tag <param> mancanti
/// <summary>
/// Inizializza il driver.
/// </summary>
public Task InitializeAsync(uint baudrate, string devicePath) // ❌ No <param>

// ❌ Inizia con "Questo metodo"
/// <summary>
/// Questo metodo calcola il checksum.  <-- Rimuovere "Questo metodo"
/// </summary>

// ❌ Descrizione <returns> mancante per bool
/// <summary>
/// Si connette al dispositivo.
/// </summary>
/// <returns>True o false.</returns>  <-- NON spiega cosa significano
public Task<bool> ConnectAsync()
```

---

## Eccezioni

| Componente | Eccezione | Motivazione |
|------------|-----------|-------------|
| Test classes | No XML docs richiesti | Non sono API pubbliche |
| `[Obsolete]` members | Minimal docs OK | Verranno rimossi |
| Generated code | No docs richiesti | Generato automaticamente |
| Primary constructors | `<param>` nel tipo | C# 12 syntax |

---

## Enforcement

### EditorConfig

```ini
# .editorconfig - Documentation rules
[*.cs]
# Require XML docs for public members
dotnet_diagnostic.CS1591.severity = warning

# In Test projects, suppress CS1591
[**/Tests/**/*.cs]
dotnet_diagnostic.CS1591.severity = none
```

### Directory.Build.props (per Release)

```xml
<PropertyGroup Condition="'$(Configuration)' == 'Release'">
  <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  <!-- Oppure solo per CS1591 -->
  <WarningsAsErrors>CS1591</WarningsAsErrors>
</PropertyGroup>
```

### Suppressione Locale (quando necessario)

```csharp
#pragma warning disable CS1591 // Missing XML comment
public void LegacyMethod() { }  // TODO: Documentare in T-018
#pragma warning restore CS1591
```

### Code Review Checklist

- [ ] Tutti i membri `public`/`protected` hanno `<summary>`?
- [ ] Tutti i parametri hanno `<param>`?
- [ ] Metodi non-void hanno `<returns>` descrittivo?
- [ ] `<returns>` per `bool` spiega true/false?
- [ ] Eccezioni lanciate hanno `<exception>`?
- [ ] Documentazione in italiano?
- [ ] Nessun commento ovvio o ridondante?
- [ ] Commenti inline spiegano il "perché"?

---

## Piano di Remediation

### Fase 1: Configurazione (Day 1)

1. Aggiungere regole `.editorconfig` per CS1591
2. Configurare suppress per Tests
3. Documentare tipi più visibili (interfacce)

### Fase 2: Core Protocol (Week 1)

| Priorità | Path | Warning Stimati |
|----------|------|-----------------|
| 1 | `Protocol/Infrastructure/` | ~20 |
| 2 | `Protocol/Layers/Stack/` | ~30 |
| 3 | `Protocol/Layers/Base/` | ~40 |
| 4 | `Protocol/Layers/*/Models/` | ~100 |

### Fase 3: Layers (Week 2)

| Priorità | Path | Warning Stimati |
|----------|------|-----------------|
| 5 | `Protocol/Layers/ApplicationLayer/` | ~50 |
| 6 | `Protocol/Layers/*/Helpers/` | ~200 (internal) |
| 7 | Altri layer | ~200 |

### Fase 4: Drivers (Week 3)

| Priorità | Path | Warning Stimati |
|----------|------|-----------------|
| 8 | `Drivers.Can/` | ~100 |
| 9 | `Drivers.Ble/` | ~50 |
| 10 | `Client/` | ~30 |

### Target

| Milestone | Target Warning | Data |
|-----------|---------------|------|
| M1 | < 800 | Week 1 |
| M2 | < 400 | Week 2 |
| M3 | < 100 | Week 3 |
| M4 | 0 | Week 4 |

---

## Riferimenti

### Standard Esterni

- [Microsoft C# XML Documentation](https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/xmldoc/)
- [StyleCop Documentation Rules](https://github.com/DotNetAnalyzers/StyleCopAnalyzers/blob/master/documentation/DocumentationRules.md)
- [NDoc XML Comment Reference](http://ndoc.sourceforge.net/)

### File Correlati

- [STANDARD_VISIBILITY.md](STANDARD_VISIBILITY.md) - API pubbliche da documentare

### Warning Codes

| Code | Descrizione | Causa Comune |
|------|-------------|--------------|
| CS1591 | Missing XML comment for publicly visible type or member | Manca `<summary>` |
| CS1570 | XML comment has badly formed XML | Caratteri non escaped (`<`, `>`, `&`) |
| CS1573 | Parameter has no matching param tag | Manca `<param>` per un parametro |
| CS1572 | XML comment has param tag but parameter doesn't exist | `<param>` per parametro rimosso |
| CS1574 | XML comment has cref that could not be resolved | `cref` senza namespace completo |
| CS1584 | XML comment has syntactically incorrect cref | Sintassi `cref` errata |
| CS1734 | XML comment has a paramref tag but there is no parameter by that name | `<paramref>` su classe invece di metodo |
| CS0419 | Ambiguous reference in cref attribute | Overload ambiguo (es. `Volatile.Read`) |
| CS1658 | Warning is overriding an error | Conflitto severity |

---

## Changelog

| Data | Versione | Descrizione |
|------|----------|-------------|
| 2026-02-12 | 1.1 | Aggiunte R-010 (XML escaping), R-011 (cref qualified), warning codes completi |
| 2026-02-12 | 1.0 | Versione iniziale - standard documentazione XML |

# API Surface Template - Struttura Standard per Documentazione API

> **Versione:** 1.0  
> **Data:** 2026-02-25  
> **Stato:** Active

---

## Scopo

Questo template definisce la struttura standard per il file `API_SURFACE.md`, che documenta l'API pubblica della libreria per facilitare l'integrazione in applicazioni client.

**Obiettivi:**
- **Completezza** - Tutti i tipi pubblici documentati
- **Usabilità** - Quick start ed esempi pratici
- **Manutenibilità** - Sincronizzato con CHANGELOG
- **Navigabilità** - Indice e link interni

---

## Convenzioni

| Elemento | Formato | Esempio |
|----------|---------|---------|
| **Versione** | Semantic Versioning | `0.5.3` |
| **Data** | ISO 8601 | `2026-02-25` |
| **Namespace** | Code block | `` `using X.Y.Z;` `` |
| **Signature** | Code block C# | Metodi con tipi |
| **Tabelle** | Markdown tables | Per proprietà/configurazione |
| **Breaking Changes** | Prima/Dopo code | Migrazione chiara |

---

## Struttura Template

```markdown
# API Surface - {NomeLibreria}

> **Versione:** {X.Y.Z}  
> **Ultimo aggiornamento:** {YYYY-MM-DD}

{Descrizione breve della libreria e suo scopo.}

---

## Indice                                    [OBBLIGATORIO]

- [Quick Start](#quick-start)
- [Componenti Principali](#componenti-principali)
- [Eventi](#eventi)
- [Tipi Comuni](#tipi-comuni)
- [Breaking Changes](#breaking-changes-vxyz)

---

## Quick Start                               [OBBLIGATORIO]

Esempio minimo funzionante che mostra il flusso tipico:

```csharp
using {Namespace.Principale};

// 1. Setup
// 2. Configurazione
// 3. Uso
// 4. Cleanup
``

---

## {Componente Principale}                   [OBBLIGATORIO - per ogni componente]

### Namespace
```csharp
using {Full.Namespace};
``

### Creazione / Factory
```csharp
// Pattern di creazione raccomandato
``

### Proprietà

| Proprietà | Tipo | Descrizione |
|-----------|------|-------------|
| `{Nome}` | `{Tipo}` | {Descrizione} |

### Metodi Principali

```csharp
// Signature con commenti
{ReturnType} {MethodName}({params});
``

### Eventi

| Evento | Tipo | Descrizione |
|--------|------|-------------|
| `{Nome}` | `EventHandler<{EventArgs}>` | {Descrizione} |

---

## Eventi e EventArgs                        [OBBLIGATORIO - se presenti eventi]

### {NomeEventArgs}

```csharp
public sealed class {NomeEventArgs} : EventArgs
{
    public {Tipo} {Proprietà} { get; }
    // ...
    public DateTime Timestamp { get; }  // Sempre presente (EA-022)
}
``

**Invarianti:** (se presenti)
- {Invariante 1}
- {Invariante 2}

### Esempio Sottoscrizione

```csharp
component.{Evento} += (sender, e) =>
{
    // Gestione evento
};
``

---

## Configurazione                            [OBBLIGATORIO - per ogni config class]

### {NomeConfiguration}

| Proprietà | Tipo | Default | Range | Descrizione |
|-----------|------|---------|-------|-------------|
| `{Nome}` | `{Tipo}` | `{Default}` | `{Min-Max}` | {Descrizione} |

---

## Tipi Comuni                               [OBBLIGATORIO]

### Enums

```csharp
public enum {NomeEnum}
{
    {Value1} = {n},   // {Descrizione}
    {Value2} = {m}    // {Descrizione}
}
``

### Structs/Records

```csharp
public readonly struct {NomeStruct}
{
    // Proprietà principali
}
``

---

## Breaking Changes v{X.Y.Z}                 [OBBLIGATORIO - se presenti]

### {Titolo Breaking Change}

**Chi è impattato:** {Descrizione chi deve fare modifiche}

**Prima (v{precedente}):**
```csharp
// Codice vecchio
``

**Dopo (v{nuova}):**
```csharp
// Codice nuovo con migrazione
``

---

## Requisiti                                 [OBBLIGATORIO]

- **{Runtime}** versione X.Y o superiore
- **{Dipendenza hardware/software}**

### Pacchetti NuGet

```xml
<PackageReference Include="{Package}" Version="{Version}" />
``

---

## Links                                     [OBBLIGATORIO]

- [README principale](../README.md)
- [CHANGELOG](../CHANGELOG.md)
- [{Componente} README]({path}/README.md)
```

---

## Sezioni per Tipo di API

### Per Library di Comunicazione (es. STEM Protocol)

| Sezione | Obbligatoria | Note |
|---------|--------------|------|
| Quick Start | ✅ | Connect → Send → Receive → Disconnect |
| Connection Events | ✅ | ConnectionState, EventArgs |
| Driver/Transport | ✅ | Per ogni driver supportato |
| Configurazione | ✅ | Tabella con default e range |
| Breaking Changes | ⚠️ | Solo se presenti nella versione |

### Per Library Utility

| Sezione | Obbligatoria | Note |
|---------|--------------|------|
| Quick Start | ✅ | Esempio uso più comune |
| API Reference | ✅ | Metodi principali |
| Extension Methods | ⚠️ | Se presenti |
| Breaking Changes | ⚠️ | Solo se presenti |

---

## Regole

| ID | Livello | Regola |
|----|---------|--------|
| API-001 | ✅ DEVE | Includere Quick Start funzionante |
| API-002 | ✅ DEVE | Documentare tutti i tipi pubblici |
| API-003 | ✅ DEVE | Includere namespace per ogni componente |
| API-004 | ✅ DEVE | Tabella proprietà per configuration classes |
| API-005 | ✅ DEVE | Documentare EventArgs con proprietà e invarianti |
| API-006 | ⚠️ DOVREBBE | Includere esempio per ogni evento |
| API-007 | ⚠️ DOVREBBE | Documentare breaking changes con Prima/Dopo |
| API-008 | ⚠️ DOVREBBE | Link a README dettagliati per approfondimenti |
| API-009 | 💡 PUÒ | Includere diagrammi di sequenza per flussi complessi |
| API-010 | ✅ DEVE | Sincronizzare versione con CHANGELOG |

---

## Sincronizzazione

### Con CHANGELOG

Ogni release che modifica l'API pubblica deve:
1. Aggiornare `Versione` e `Ultimo aggiornamento` in API_SURFACE.md
2. Documentare nuovi tipi/eventi/metodi
3. Aggiornare sezione Breaking Changes se necessario

### Con XML Documentation

L'API_SURFACE.md è complementare, non sostitutivo, degli XML docs:
- **XML docs** → IntelliSense, generazione automatica
- **API_SURFACE.md** → Visione d'insieme, esempi, getting started

---

## Sezioni Obbligatorie vs Opzionali

| # | Sezione | Obbligatoria | Condizione |
|---|---------|--------------|------------|
| 1 | Header (Versione, Data) | ✅ | Sempre |
| 2 | Indice | ✅ | Sempre |
| 3 | Quick Start | ✅ | Sempre |
| 4 | Componenti Principali | ✅ | Per ogni componente pubblico |
| 5 | Eventi e EventArgs | ✅ | Se la libreria espone eventi |
| 6 | Configurazione | ✅ | Per ogni configuration class |
| 7 | Tipi Comuni | ✅ | Sempre (enum, struct, etc.) |
| 8 | Breaking Changes | ⚠️ | Solo se presenti nella versione |
| 9 | Requisiti | ✅ | Sempre |
| 10 | Links | ✅ | Sempre |

---

## Checklist

Prima di pubblicare un aggiornamento a `API_SURFACE.md`, verificare:

- [ ] Header aggiornato (Versione e Data)
- [ ] Indice sincronizzato con le sezioni
- [ ] Quick Start compila e funziona
- [ ] Tutti i tipi pubblici documentati
- [ ] Tutti gli EventArgs hanno proprietà e invarianti
- [ ] Tabelle configurazione con Default e Range
- [ ] Breaking Changes documentati (se presenti)
- [ ] Links funzionanti
- [ ] Versione sincronizzata con CHANGELOG

---

## Esempio Completo

Vedi: [`Docs/API_SURFACE.md`](../../API_SURFACE.md)

---

## Changelog

| Data | Versione | Descrizione |
|------|----------|-------------|
| 2026-02-25 | 1.0 | Versione iniziale |

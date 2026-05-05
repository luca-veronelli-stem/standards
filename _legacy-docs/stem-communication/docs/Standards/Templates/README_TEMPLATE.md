# README Template - Struttura Standard per README

> **Versione:** 2.0  
> **Data:** 2026-02-13  
> **Stato:** Active

---

## Scopo

Questo template definisce la struttura standard per tutti i file `README.md` del progetto:

- **README Layer** - Per i layer del protocollo (`Protocol/Layers/*/README.md`)
- **README Progetto** - Per i progetti della soluzione (`Protocol/`, `Drivers.*`, `Tests/`, `Client/`)
- **README Root** - Per il README principale della soluzione

L'obiettivo è garantire **consistenza**, **completezza** e **navigabilità** in tutta la documentazione.

---

## Convenzioni

| Elemento | Formato | Esempio |
|----------|---------|---------|
| **Data** | ISO 8601 | `2026-02-13` |
| **Encoding** | UTF-8 | - |
| **Link** | Relativi | `./ISSUES.md`, `../Base/README.md` |
| **Diagrammi** | Box-drawing Unicode | `┌─┐ │ └─┘` |
| **Alberi directory** | Unicode | `├── └── │` |

---

## Tipo di README

### Identificazione

| Tipo | Applicabile a | Sezioni Specifiche |
|------|---------------|-------------------|
| **Layer** | `Protocol/Layers/*/README.md` | Formato Dati, Flusso Dati, Riferimenti Firmware C |
| **Progetto** | `Protocol/`, `Drivers.*`, `Tests/`, `Client/` | Caratteristiche, API/Componenti |
| **Root** | `README.md` (root soluzione) | Badge, Quick Start globale |

---

## Template Completo - Layer

Per i README dei layer del protocollo (`Protocol/Layers/*/README.md`):

```markdown
# {LayerName} (Layer {N})

## Panoramica                              [OBBLIGATORIA]

Il **{LayerName}** è il {N}° livello dello stack protocollare STEM, 
corrispondente al Layer {N} del modello OSI. Si occupa di {responsabilità principale}.

> **Ultimo aggiornamento:** YYYY-MM-DD

---

## Responsabilità                          [OBBLIGATORIA]

- **{Verbo sostantivato}** tramite {come}
- **{Verbo sostantivato}** con {meccanismo}
- **Raccolta statistiche** su metriche rilevanti

---

## Architettura                            [OBBLIGATORIA]

``
{LayerName}/
├── {LayerName}.cs                    # Implementazione principale
├── {LayerName}Constants.cs           # Costanti del layer
├── Helpers/
│   ├── Helper1.cs                    # Descrizione breve
│   └── Helper2.cs                    # Descrizione breve
├── Models/
│   ├── {LayerName}Configuration.cs   # Configurazione runtime
│   ├── {LayerName}Statistics.cs      # Statistiche aggregate
│   └── OtherModel.cs                 # Descrizione
├── Enums/                            # (se presenti)
│   └── SomeEnum.cs
└── Interfaces/                       # (se presenti)
    └── ISomeInterface.cs
``

---

## Formato Dati                            [Opzionale - se definisce formato binario]

### Struttura {Frame/Messaggio/Chunk}

``
┌──────────┬──────────┬──────────┬──────────┐
│  Campo1  │  Campo2  │  Campo3  │  Campo4  │
│  1 byte  │  4 bytes │  2 bytes │  N bytes │
└──────────┴──────────┴──────────┴──────────┘
``

| Campo | Offset | Size | Endianness | Descrizione |
|-------|--------|------|------------|-------------|
| `Campo1` | 0 | 1 byte | - | Descrizione |
| `Campo2` | 1 | 4 bytes | Big-Endian | Descrizione |

---

## Componenti Principali                   [OBBLIGATORIA]

### {LayerName}

Classe principale che implementa `ProtocolLayerBase`. {Breve descrizione}.

```csharp
public class {LayerName} : ProtocolLayerBase
{
    public override string LayerName => "{Name}";
    public override int LayerLevel => {N};
}
``

### Helper: {HelperName}

{Descrizione del ruolo - 1-2 frasi}

**Metodi principali:**
- `MetodoA()` - descrizione
- `MetodoB()` - descrizione

---

## Configurazione                          [OBBLIGATORIA]

Classe: `{LayerName}Configuration`

| Proprietà | Tipo | Default | Min | Max | Descrizione |
|-----------|------|---------|-----|-----|-------------|
| `TimeoutMs` | `int` | `1000` | `100` | `60000` | Timeout in ms |

### Esempio

```csharp
var config = new {LayerName}Configuration
{
    TimeoutMs = 2000
};
config.Validate();
``

---

## Costanti                                [OBBLIGATORIA]

Classe: `{LayerName}Constants`

### Costanti Protocollo

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `HEADER_SIZE` | `7` | Dimensione header in bytes |

### Valori Default

| Costante | Valore | Usato da |
|----------|--------|----------|
| `DEFAULT_TIMEOUT_MS` | `1000` | `Configuration.TimeoutMs` |

---

## Flusso Dati                             [Opzionale - consigliato per layer complessi]

### Downstream (Trasmissione)

``
Layer Superiore
      │
      ▼
┌─────────────────────────┐
│   ProcessDownstreamAsync │
│   1. Validazione input   │
│   2. Elaborazione        │
│   3. Output              │
└─────────────────────────┘
      │
      ▼
Layer Inferiore
``

---

## Statistiche                             [Opzionale - se ha statistiche]

Classe: `{LayerName}Statistics`

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `BytesReceived` | `long` | Totale bytes ricevuti |

---

## Esempi di Utilizzo                      [OBBLIGATORIA]

### Inizializzazione Base

```csharp
var layer = new {LayerName}();
await layer.InitializeAsync();
``

### Con Configurazione

```csharp
var config = new {LayerName}Configuration { TimeoutMs = 5000 };
var layer = new {LayerName}();
await layer.InitializeAsync(config);
``

---

## Issue Correlate                         [OBBLIGATORIA]

→ [{LayerName}/ISSUES.md](./ISSUES.md)

---

## Riferimenti Firmware C                  [Opzionale - se esiste equivalente]

| Componente C# | File C | Struttura/Funzione |
|---------------|--------|-------------------|
| `{Classe}` | `{file}.c` | `{STRUCT_t}` |

---

## Links                                   [OBBLIGATORIA]

- [Stack README](../Stack/README.md)
- [Base README](../Base/README.md)
```

---

## Template Completo - Progetto

Per i README dei progetti (`Protocol/`, `Drivers.*`, `Tests/`, `Client/`):

```markdown
# {NomeProgetto}

> **{Descrizione breve in 1-2 righe}**  
> **Ultimo aggiornamento:** YYYY-MM-DD

---

## Panoramica                              [OBBLIGATORIA]

{Descrizione del progetto: cosa fa, perché esiste, ruolo nella soluzione}

---

## Caratteristiche                         [Opzionale - per librerie]

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **Feature 1** | ✅ | Descrizione breve |
| **Feature 2** | ⚠️ | In sviluppo |

---

## Requisiti                               [OBBLIGATORIA]

- **.NET 10.0** o superiore
- {Altri requisiti specifici}

### Dipendenze

| Package | Versione | Uso |
|---------|----------|-----|
| {Package} | {Version} | {Descrizione} |

---

## Quick Start                             [OBBLIGATORIA]

```csharp
// Esempio minimale di utilizzo
``

---

## Struttura                               [Opzionale - se complessa]

``
{NomeProgetto}/
├── {Cartella1}/
├── {Cartella2}/
└── {File.cs}
``

---

## API / Componenti                        [Opzionale - per librerie]

{Descrizione API principali, interfacce, classi chiave}

---

## Configurazione                          [Opzionale - per applicazioni]

{Parametri di configurazione, file config, variabili ambiente}

---

## Esecuzione / Testing                    [Opzionale - per test/app]

```bash
# Comandi per eseguire
dotnet test
``

---

## Issue Correlate                         [OBBLIGATORIA]

→ [{NomeProgetto}/ISSUES.md](./ISSUES.md)

---

## Links                                   [OBBLIGATORIA]

- [Documento correlato](./path/to/doc.md)

---

## Licenza                                 [OBBLIGATORIA - sempre ultima]

- **Proprietario:** STEM E.m.s.
- **Autore:** Luca Veronelli (l.veronelli@stem.it)
- **Licenza:** Proprietaria - Tutti i diritti riservati
```

---

## Template Completo - Root

Per il README principale della soluzione:

```markdown
# {NomeSoluzione}

> **{Descrizione breve}**

[![.NET](https://img.shields.io/badge/.NET-10.0-512BD4)](https://dotnet.microsoft.com/)
[![Tests](https://img.shields.io/badge/tests-{N}%20passing-brightgreen)](./Tests/)
[![License](https://img.shields.io/badge/license-Proprietary-red)](#licenza)

> **Ultimo aggiornamento:** YYYY-MM-DD

---

## Panoramica                              [OBBLIGATORIA]

{Descrizione della soluzione}

---

## Caratteristiche                         [OBBLIGATORIA]

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| **Feature 1** | ✅ | Descrizione |

---

## Requisiti                               [OBBLIGATORIA]

- **.NET 10.0** o superiore

---

## Quick Start                             [OBBLIGATORIA]

```csharp
// Esempio minimale
``

---

## Struttura Soluzione                     [OBBLIGATORIA]

``
Solution/
├── Protocol/           # Core library
├── Drivers.Can/        # CAN driver
├── Drivers.Ble/        # BLE driver
├── Client/             # Example application
└── Tests/              # Unit & integration tests
``

---

## Documentazione                          [OBBLIGATORIA]

- [Protocol README](./Protocol/README.md)
- [Standards](./Docs/Standards/)

---

## Issue Correlate                         [OBBLIGATORIA]

→ [Protocol/ISSUES.md](./Protocol/ISSUES.md)

---

## Licenza                                 [OBBLIGATORIA - sempre ultima]

{Dettagli licenza}
```

---

## Sezioni Obbligatorie vs Opzionali

### README Layer

| # | Sezione | Obbl. | Condizione |
|---|---------|:-----:|------------|
| 1 | Panoramica | ✅ | Sempre |
| 2 | Responsabilità | ✅ | Sempre |
| 3 | Architettura | ✅ | Sempre |
| 4 | Formato Dati | ⚪ | Solo se definisce formato binario |
| 5 | Componenti Principali | ✅ | Sempre |
| 6 | Configurazione | ✅ | Sempre (anche se vuota) |
| 7 | Costanti | ✅ | Sempre |
| 8 | Flusso Dati | ⚪ | Consigliato per layer complessi |
| 9 | Statistiche | ⚪ | Solo se ha statistiche |
| 10 | Esempi di Utilizzo | ✅ | Sempre |
| 11 | Issue Correlate | ✅ | Sempre |
| 12 | Riferimenti Firmware C | ⚪ | Solo se esiste equivalente |
| 13 | Links | ✅ | Sempre |

### README Progetto

| # | Sezione | Obbl. | Condizione |
|---|---------|:-----:|------------|
| 1 | Panoramica | ✅ | Sempre |
| 2 | Caratteristiche | ⚪ | Per librerie |
| 3 | Requisiti | ✅ | Sempre |
| 4 | Quick Start | ✅ | Sempre |
| 5 | Struttura | ⚪ | Se complessa |
| 6 | API / Componenti | ⚪ | Per librerie |
| 7 | Configurazione | ⚪ | Per applicazioni |
| 8 | Esecuzione / Testing | ⚪ | Per test/app |
| 9 | Issue Correlate | ✅ | Sempre |
| 10 | Links | ✅ | Sempre |
| 11 | Licenza | ✅ | Sempre (ultima) |

### README Root

| # | Sezione | Obbl. |
|---|---------|:-----:|
| 1 | Titolo + Badge | ✅ |
| 2 | Panoramica | ✅ |
| 3 | Caratteristiche | ✅ |
| 4 | Requisiti | ✅ |
| 5 | Quick Start | ✅ |
| 6 | Struttura Soluzione | ✅ |
| 7 | Documentazione | ✅ |
| 8 | Issue Correlate | ✅ |
| 9 | Licenza | ✅ |

---

## Note Specifiche per Layer

| Layer | Note |
|-------|------|
| **PhysicalLayer** | Include sezione driver/canali supportati |
| **DataLinkLayer** | Formato frame obbligatorio, riferimenti CRC |
| **NetworkLayer** | Sezione routing/broadcast, topologia |
| **TransportLayer** | Formato chunk/NetInfo, chunking per canale |
| **SessionLayer** | State machine, heartbeat |
| **PresentationLayer** | Algoritmi crittografia, gestione chiavi |
| **ApplicationLayer** | Tabella comandi, handler registry |
| **Stack** | Orchestrazione, builder pattern |
| **Base** | Interfacce, pattern condivisi |

---

## Checklist Validazione

### README Layer

- [ ] Panoramica: ≤3 frasi, data aggiornata
- [ ] Responsabilità: lista ordinata per importanza
- [ ] Architettura: tree aggiornato
- [ ] Formato Dati: presente se applicabile
- [ ] Componenti: classe principale + helper
- [ ] Configurazione: tabella completa
- [ ] Costanti: divise per categoria
- [ ] Esempi: almeno 2 funzionanti
- [ ] Issue: link a ISSUES.md
- [ ] Links: riferimenti correlati

### README Progetto

- [ ] Template corretto usato
- [ ] Data aggiornata
- [ ] Sezioni obbligatorie presenti
- [ ] Link funzionanti
- [ ] Licenza presente come ultima sezione

### README Root

- [ ] Badge presenti e aggiornati
- [ ] Quick Start funzionante
- [ ] Struttura soluzione aggiornata

---

## Changelog

| Data | Versione | Descrizione |
|------|----------|-------------|
| 2026-02-13 | 2.0 | Unificazione README_TEMPLATE.md e PROJECT_README_TEMPLATE.md |
| 2026-02-09 | 1.1 | Aggiunte note specifiche per layer |
| 2026-02-09 | 1.0 | Versione iniziale (due file separati) |

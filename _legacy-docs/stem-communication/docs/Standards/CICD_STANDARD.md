# Standard CI/CD - Pipeline Bitbucket Best Practices

> **Versione:** 1.0  
> **Data:** 2026-02-26  
> **Riferimento Issue:** -  
> **Stato:** Active

---

## Scopo e Ambito

Questo standard definisce le best practices per la scrittura di pipeline Bitbucket nel progetto Stem.Communication.

**Obiettivi:**
- Ridurre duplicazioni tramite YAML anchors e definitions
- Garantire leggibilità e manutenibilità
- Ottimizzare tempi di build tramite caching e parallelismo
- Assicurare corretto passaggio artifacts tra step

---

## Principi Guida

1. **DRY (Don't Repeat Yourself)** - Usare anchors e definitions per codice ripetuto
2. **Fail Fast** - Validazioni all'inizio della pipeline
3. **Explicit over Implicit** - Percorsi artifacts espliciti e consistenti
4. **Minimal Scope** - Ogni step fa una sola cosa

---

## Regole

### CI-001: Struttura File

| Regola | Descrizione |
|--------|-------------|
| ✅ **DEVE** | Usare `definitions` per step riutilizzabili |
| ✅ **DEVE** | Raggruppare anchors YAML in `definitions` |
| ⚠️ **DOVREBBE** | Separare script complessi (>20 righe) in file `.sh` esterni |
| ❌ **NON DEVE** | Duplicare blocchi di codice identici |

### CI-002: YAML Anchors

| Regola | Descrizione |
|--------|-------------|
| ✅ **DEVE** | Usare anchors (`&nome`) per script ripetuti |
| ✅ **DEVE** | Nominare anchors in snake_case descrittivo |
| ⚠️ **DOVREBBE** | Raggruppare anchors correlati con commenti |

### CI-003: Artifacts tra Step

| Regola | Descrizione |
|--------|-------------|
| ✅ **DEVE** | Usare percorsi **espliciti e fissi** (es. `./artifacts/`) |
| ✅ **DEVE** | Evitare glob pattern ambigui come `**/` per artifacts critici |
| ✅ **DEVE** | Verificare esistenza file prima di usarli (`[ -f file ]`) |
| ❌ **NON DEVE** | Assumere che artifacts siano in working directory root |

**Nota importante:** In Bitbucket, gli artifacts sono passati automaticamente tra step **sequenziali** nella stessa pipeline. I path sono preservati relativi alla working directory.

### CI-004: Caching

| Regola | Descrizione |
|--------|-------------|
| ✅ **DEVE** | Definire cache NuGet: `dotnetcore: ~/.nuget/packages` |
| ⚠️ **DOVREBBE** | Usare cache in tutti gli step che fanno restore |

### CI-005: Conditional Execution

| Regola | Descrizione |
|--------|-------------|
| ✅ **DEVE** | Usare file marker (es. `VERSION.txt`) per flow control |
| ✅ **DEVE** | Check esistenza file con sintassi POSIX: `[ -f file ]` |
| ⚠️ **DOVREBBE** | Preferire `condition:` nativo quando possibile |

### CI-006: Indentazione

| Regola | Descrizione |
|--------|-------------|
| ✅ **DEVE** | Usare 2 spazi per indentazione YAML |
| ✅ **DEVE** | Allineare consistentemente tutti gli step |
| ❌ **NON DEVE** | Mescolare tab e spazi |

---

## Esempi

### ✅ Uso Corretto - Anchors e Definitions

```yaml
definitions:
  caches:
    dotnetcore: ~/.nuget/packages
  
  scripts:
    # Anchor per skip condizionale
    - script: &skip_if_no_version |
        if [ ! -f ./artifacts/VERSION.txt ]; then
          echo "Nessuna nuova versione - skip"
          exit 0
        fi
  
  steps:
    # Step riutilizzabile
    - step: &build_step
        name: Build
        caches:
          - dotnetcore
        script:
          - dotnet restore Solution.slnx
          - dotnet build Solution.slnx --no-restore -c Release

pipelines:
  default:
    - step: *build_step  # Riuso tramite alias
```

### ✅ Uso Corretto - Artifacts Espliciti

```yaml
- step:
    name: Pack
    script:
      - mkdir -p ./artifacts
      - dotnet pack -o ./artifacts
      - cp ./VERSION.txt ./artifacts/
    artifacts:
      - artifacts/**  # Path esplicito e consistente

- step:
    name: Push
    script:
      - cat ./artifacts/VERSION.txt  # Stesso path
```

### ❌ Uso Scorretto - Duplicazione

```yaml
# NON FARE: stesso blocco ripetuto
- step:
    script:
      - if [ ! -f ./VERSION.txt ]; then exit 0; fi
      - dotnet restore
- step:
    script:
      - if [ ! -f ./VERSION.txt ]; then exit 0; fi  # Duplicato!
      - dotnet pack
```

### ❌ Uso Scorretto - Artifacts Ambigui

```yaml
# NON FARE: glob troppo ampio
artifacts:
  - "**/*"  # Cattura troppo, lento e fragile

# NON FARE: path inconsistenti tra step
- step:
    artifacts:
      - VERSION.txt  # Root
- step:
    script:
      - cat ./artifacts/VERSION.txt  # Path diverso!
```

---

## Eccezioni

| Contesto | Eccezione | Motivazione |
|----------|-----------|-------------|
| Pipeline semplici | Anchors non richiesti | Se non c'è duplicazione |
| Step singolo | Definitions non richieste | Overhead non giustificato |

---

## Enforcement

- **Code Review:** Verificare assenza duplicazioni
- **Linting:** Usare `yamllint` con regole indentazione
- **Test manuale:** Verificare artifacts passano correttamente

---

## Riferimenti

- [Bitbucket Pipelines YAML Anchors](https://support.atlassian.com/bitbucket-cloud/docs/yaml-anchors/)
- [Bitbucket Artifacts Documentation](https://support.atlassian.com/bitbucket-cloud/docs/use-artifacts-in-steps/)
- [YAML 1.2 Specification - Anchors](https://yaml.org/spec/1.2/spec.html#id2765878)

---

## Changelog

| Data | Versione | Descrizione |
|------|----------|-------------|
| 2026-02-26 | 1.0 | Versione iniziale |

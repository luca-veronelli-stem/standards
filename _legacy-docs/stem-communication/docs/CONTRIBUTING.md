# Contributing - STEM Communication Protocol

Guida per contribuire al progetto STEM Communication Protocol.

> **Ultimo aggiornamento:** 2026-02-26

---

## Indice

- [Struttura Progetto](#struttura-progetto)
- [Sviluppo Locale](#sviluppo-locale)
- [Pubblicazione Pacchetti NuGet](#pubblicazione-pacchetti-nuget)
- [CI/CD Pipeline](#cicd-pipeline)
- [Workflow Release](#workflow-release)
- [Convenzioni](#convenzioni)

---

## Struttura Progetto

```
StemCommunicationProtocol/
├── Protocol/                    # Stem.Protocol (NuGet)
├── Drivers.Can/                 # Stem.Drivers.Can (NuGet)
├── Drivers.Ble/                 # Stem.Drivers.Ble (NuGet)
├── Client/                      # App console esempio (non pubblicata)
├── Tests/                       # Test xUnit (non pubblicato)
├── Docs/                        # Documentazione
├── Scripts/                     # Script di automazione
│   ├── Release.ps1              # Step 1: Preparazione release
│   └── Tag.ps1                  # Step 3: Creazione tag dopo merge
├── Directory.Build.props        # Metadati NuGet condivisi
├── CHANGELOG.md                 # Storico versioni
└── LICENSE                      # Licenza proprietaria
```

---

## Sviluppo Locale

### Prerequisiti

- .NET 10.0 SDK
- Visual Studio 2022 17.12+ oppure VS Code con C# Dev Kit
- Windows 10/11 (per driver PCAN)

### Build e Test

```powershell
# Build completo
dotnet build

# Esegui tutti i test
dotnet test

# Test specifico layer
dotnet test --filter "FullyQualifiedName~NetworkLayer"

# Build Release
dotnet build -c Release
```

---

## Pubblicazione Pacchetti NuGet

### Pacchetti Generati

| Pacchetto | Progetto | Descrizione |
|-----------|----------|-------------|
| `Stem.Protocol` | Protocol/ | Stack protocollare 7 layer OSI |
| `Stem.Drivers.Can` | Drivers.Can/ | Driver CAN (PEAK PCAN) |
| `Stem.Drivers.Ble` | Drivers.Ble/ | Driver BLE (Plugin.BLE) |

### Configurazione

| Aspetto | Valore |
|---------|--------|
| **Versione** | Definita in `Directory.Build.props` |
| **Output (locale)** | `./nupkg` |
| **Output (CI)** | `./artifacts` |
| **Symbols** | Inclusi (`.snupkg`) |
| **License** | Inclusa (`LICENSE`) |
| **README** | Incluso per ogni pacchetto |
| **Destinazione** | Azure DevOps Artifacts |

### Progetti Esclusi

I seguenti progetti **NON** generano pacchetti NuGet:

| Progetto | Motivo |
|----------|--------|
| `Tests` | `IsPackable=false` esplicito |
| `Client` | `IsPackable=false` (applicazione) |

### Comandi

```powershell
# Genera tutti i pacchetti
dotnet pack -c Release

# Verifica pacchetti generati
Get-ChildItem ./nupkg/Stem.*.nupkg

# Pack singolo progetto
dotnet pack Protocol/Protocol.csproj -c Release
```

---

## CI/CD Pipeline

Il progetto utilizza **Bitbucket Pipelines** per automazione CI/CD.

### Pipeline Default (tutti i branch)

Ogni push triggera automaticamente:

1. **Build** - Restore e build in Release
2. **Test** - Esecuzione test con report TRX

### Pipeline Main (release automatica)

Quando viene fatto merge su `main`, la pipeline:

1. **Check Version** - Verifica se la versione in `Directory.Build.props` ha un tag esistente
2. **Build & Test** - Solo se nuova versione
3. **Pack NuGet** - Genera pacchetti `.nupkg` e `.snupkg`
4. **Create Tag** - Crea tag Git `vX.Y.Z` automaticamente
5. **Push to Azure** - Pubblica su Azure DevOps Artifacts

### Variabili Repository Richieste

| Variabile | Descrizione |
|-----------|-------------|
| `NUGET_FEED_URL` | URL del feed Azure Artifacts |
| `NUGET_FEED_PAT` | Personal Access Token per autenticazione |

> **Nota:** Le variabili devono essere configurate in **Repository Settings → Pipelines → Variables**

### Skip Release

Se il tag `vX.Y.Z` esiste già, la pipeline salta tutti gli step di release.
Per rilasciare una nuova versione, è sufficiente aggiornare `Version` in `Directory.Build.props`.

---

## Workflow Release

Il processo di release è diviso in **3 fasi** distinte:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  1. RELEASE     │ --> │  2. MERGE (PR)  │ --> │  3. AUTOMATIC   │
│  (locale)       │     │  (Bitbucket)    │     │  (CI Pipeline)  │
│  Release.ps1    │     │  Pull Request   │     │  Tag + Publish  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

---

### Step 1: Preparazione Release (locale)

Esegui `Scripts/Release.ps1` per preparare la release:

```powershell
# Release completa
.\Scripts\Release.ps1 -Version "0.5.1"

# Senza test (hotfix veloce)
.\Scripts\Release.ps1 -Version "0.5.1" -SkipTests

# Senza push automatico (per review prima del push)
.\Scripts\Release.ps1 -Version "0.5.1" -SkipPush

# Dry run (mostra cosa farebbe senza modificare nulla)
.\Scripts\Release.ps1 -Version "0.5.1" -DryRun
```

Lo script esegue automaticamente:
1. Validazione versione SemVer
2. Verifica Git status
3. Aggiornamento versione in `Directory.Build.props`
4. Build Release
5. Esecuzione test
6. Creazione pacchetti NuGet
7. Commit delle modifiche
8. Push del branch su origin

---

### Step 2: Merge su Bitbucket

Dopo che lo script ha pushato il branch:

1. Vai su **Bitbucket** → Repository → **Pull Requests**
2. Crea una **Pull Request** da `release/vX.Y.Z` verso `main`
3. Attendi review/approvazione se richiesta
4. Esegui il **Merge** della PR
5. (Opzionale) Elimina il branch `release/vX.Y.Z` dopo il merge

---

### Step 3: Tag e Pubblicazione (automatico)

> **✅ Questo step è ora automatizzato dalla CI/CD Pipeline**

Dopo il merge su `main`, Bitbucket Pipelines esegue automaticamente:

1. Verifica versione in `Directory.Build.props`
2. Build e test
3. Generazione pacchetti NuGet
4. Creazione tag Git `vX.Y.Z`
5. Push pacchetti su Azure DevOps Artifacts

#### Fallback Manuale

Se la pipeline fallisce o per casi speciali, puoi usare `Scripts/Tag.ps1`:

```powershell
# Crea tag e pusha
.\Scripts\Tag.ps1 -Version "0.5.1"

# Dry run (verifica senza modifiche)
.\Scripts\Tag.ps1 -Version "0.5.1" -DryRun
```

---

### Workflow Manuale

Se preferisci eseguire i passaggi manualmente:

#### 1. Preparazione

```powershell
# Crea branch di release
git checkout -b release/vX.Y.Z

# Verifica che i test passino
dotnet test
```

#### 2. Aggiornamento Versione

Modifica `Directory.Build.props`:

```xml
<Version>X.Y.Z</Version>
```

#### 3. Aggiornamento CHANGELOG

Modifica `CHANGELOG.md`:

```markdown
## [Unreleased]

## [X.Y.Z] - YYYY-MM-DD

### Added
- Nuova funzionalità...

### Fixed
- Bug corretto...
```

Aggiungi link in fondo:

```markdown
[Unreleased]: https://bitbucket.org/.../compare/HEAD..vX.Y.Z
[X.Y.Z]: https://bitbucket.org/.../compare/vX.Y.Z..vX.Y.Z-1
```

#### 4. Generazione Pacchetti

```powershell
dotnet pack -c Release
```

#### 5. Commit e Push

```powershell
git add .
git commit -m "release: vX.Y.Z"
git push origin release/vX.Y.Z
```

#### 6. Merge su Bitbucket

Crea e completa la Pull Request su Bitbucket.

#### 7. Tag

```powershell
git checkout main
git pull origin main
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

---

## Convenzioni

### Semantic Versioning

Il progetto segue [Semantic Versioning 2.0.0](https://semver.org/):

| Tipo | Quando |
|------|--------|
| **MAJOR** (X.0.0) | Breaking changes API |
| **MINOR** (0.X.0) | Nuove funzionalità backward-compatible |
| **PATCH** (0.0.X) | Bug fix backward-compatible |

### Versione 0.x.x

Finché siamo in `0.x.x`:
- L'API può cambiare senza preavviso
- MINOR = nuove funzionalità O breaking changes
- PATCH = bug fix

### Branch Naming

| Pattern | Uso |
|---------|-----|
| `feature/nome-feature` | Nuove funzionalità |
| `fix/nome-bug` | Bug fix |
| `release/vX.Y.Z` | Preparazione release |
| `hotfix/vX.Y.Z` | Fix urgenti su main |

### Commit Messages

```
tipo: descrizione breve

[corpo opzionale]

[footer opzionale]
```

Tipi: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `release`

---

## Contatti

- **Autore:** Luca Veronelli (l.veronelli@stem.it)
- **Azienda:** STEM E.m.s.

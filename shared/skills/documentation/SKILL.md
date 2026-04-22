---
name: "documentation"
description: "Documentation conventions for STEM repos: README structure, XML docs, CHANGELOG, per-subproject README."
---

# Documentation

STEM repos follow a consistent shape. This skill captures the conventions — use it when adding a new README, updating an existing one, or writing XML doc comments.

## Language rule

- Code identifiers (class/method/variable/enum names) in **English**.
- Every other piece of documentation — README, XML docs, markdown in `Docs/`, CHANGELOG, inline comments, GUI strings, commit bodies — in **Italian**.

Commit summaries follow conventional-commits in English (`feat:`, `fix:`); the body can switch to Italian.

## Top-level README

Structure (Italian body, English code fences/commands):

```markdown
# <Repo name>

[![.NET](https://img.shields.io/badge/.NET-10.0-512BD4)](https://dotnet.microsoft.com/)
[![Tests](https://img.shields.io/badge/tests-N-brightgreen)](./Tests/)
[![License](https://img.shields.io/badge/license-Proprietary-red)](#licenza)

> **Applicativo ... per ...**
> **Ultimo aggiornamento:** YYYY-MM-DD

---

## Panoramica

<1–3 paragraphs: cosa fa, per chi, perché.>

## Caratteristiche

| Feature | Stato | Descrizione |
|---------|-------|-------------|
| ... | ✅ | ... |

## Requisiti

- **.NET 10.0** ...
- **Visual Studio 2022+** ...

### Dipendenze

| Package | Versione | Uso |
|---------|----------|-----|

## Quick Start

```bash
dotnet build
dotnet test
dotnet run --project GUI.Windows/GUI.Windows.csproj
```

## Struttura Soluzione

<tree>

## Documentazione

- link to subproject READMEs
- link to `Docs/`
- link to CHANGELOG

## Licenza

- **Proprietario:** STEM E.m.s.
- **Autore:** <name>
- **Data di Creazione:** YYYY-MM-DD
- **Licenza:** Proprietaria - Tutti i diritti riservati
```

## Per-subproject README

Each `.csproj` that's not purely a test harness gets a `README.md` in its folder, describing:

- Purpose (1 paragraph).
- Dependencies (only external / cross-project, not NuGet minutiae).
- Key types (with file:line links).
- Usage example if the subproject is a library.

Format matches the top-level but trimmed.

## XML documentation comments

On every public type and member:

```csharp
/// <summary>
/// Decodifica un pacchetto STEM applicando CRC16 e chunking inverso.
/// </summary>
/// <param name="raw">Pacchetto grezzo ricevuto dal canale.</param>
/// <param name="cancellationToken">Token di cancellazione della richiesta.</param>
/// <returns>Il <see cref="AppLayerDecodedEvent"/> risultante, o <c>null</c> se il pacchetto è incompleto.</returns>
/// <exception cref="CrcMismatchException">Se il CRC non corrisponde.</exception>
```

Required tags: `<summary>`, `<param>` for each parameter, `<returns>` when non-`void`, `<exception>` for each documented throw. Italian prose. Use `<see cref="...">` and `<paramref name="...">` for cross-references.

Private members don't need XML docs unless the logic is non-obvious.

## CHANGELOG

Follows [Keep a Changelog](https://keepachangelog.com/) format, Italian prose.

```markdown
# Changelog

## [Unreleased]

### Added
- Nuovo canale BLE per la telemetria fast.

### Changed
- Refactor di `Form1` in `ConnectionManager`.

### Fixed
- Race condition in `TelemetryService.StartFastTelemetryAsync`.

## [2.15.0] - 2026-04-20

...
```

## Docs folder

Non-trivial repos have a `Docs/` directory with deeper technical documents:

- `PROTOCOL.md` — protocol internals (layering, CRC, chunking).
- `REFACTOR_PLAN.md` — architectural roadmap, phase-by-phase.
- `Standards/*.md` — reusable standards (THREAD_SAFETY, CANCELLATION, LOGGING, …).
- `Diagrams/*.puml` — PlantUML sources for sequence / state / class diagrams.

Reference them from the top-level README's "Documentazione" section.

## Links in documentation

Always prefer GitHub-blob URLs with line ranges (`…/blob/<sha>/path/File.cs#L12-L42`) over file paths when linking from READMEs that will be viewed on GitHub. For local-only markdown (Docs/*.md), relative paths are fine.

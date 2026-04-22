---
name: "documentation"
description: "Documentation conventions for STEM repos: README structure, XML docs, CHANGELOG, per-subproject README."
---

# Documentation

STEM repos follow a consistent shape. This skill captures the conventions — use it when adding a new README, updating an existing one, or writing XML doc comments.

## Language rule

Everything in **English** by default — README, XML docs, markdown in `Docs/`, CHANGELOG, inline comments, GUI strings, commit summaries and bodies. Switch to Italian only when Luca explicitly asks for it on a specific artifact (e.g. "put these GUI strings in Italian for the end users").

Commit summaries follow conventional-commits (`feat:`, `fix:`, …); body, if present, is English.

## Top-level README

```markdown
# <Repo name>

[![.NET](https://img.shields.io/badge/.NET-10.0-512BD4)](https://dotnet.microsoft.com/)
[![Tests](https://img.shields.io/badge/tests-N-brightgreen)](./Tests/)
[![License](https://img.shields.io/badge/license-Proprietary-red)](#license)

> **<Application> for <purpose>.**
> **Last updated:** YYYY-MM-DD

---

## Overview

<1–3 paragraphs: what it does, who it's for, why.>

## Features

| Feature | Status | Description |
|---------|--------|-------------|
| ... | ✅ | ... |

## Requirements

- **.NET 10.0** ...
- **Visual Studio 2022+** ...

### Dependencies

| Package | Version | Use |
|---------|---------|-----|

## Quick Start

```bash
dotnet build
dotnet test
dotnet run --project GUI.Windows/GUI.Windows.csproj
```

## Solution Structure

<tree>

## Documentation

- link to subproject READMEs
- link to `Docs/`
- link to CHANGELOG

## License

- **Owner:** STEM E.m.s.
- **Author:** <name>
- **Creation Date:** YYYY-MM-DD
- **License:** Proprietary — All rights reserved
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
/// Decodes a STEM packet by applying CRC16 validation and reverse chunking.
/// </summary>
/// <param name="raw">The raw packet received from the channel.</param>
/// <param name="cancellationToken">Cancellation token for the request.</param>
/// <returns>The resulting <see cref="AppLayerDecodedEvent"/>, or <c>null</c> if the packet is incomplete.</returns>
/// <exception cref="CrcMismatchException">Thrown when the CRC does not match.</exception>
```

Required tags: `<summary>`, `<param>` for each parameter, `<returns>` when non-`void`, `<exception>` for each documented throw. English prose. Use `<see cref="...">` and `<paramref name="...">` for cross-references.

Private members don't need XML docs unless the logic is non-obvious.

## CHANGELOG

Follows [Keep a Changelog](https://keepachangelog.com/) format, English prose.

```markdown
# Changelog

## [Unreleased]

### Added
- New BLE channel for fast telemetry.

### Changed
- Refactored `Form1` into `ConnectionManager`.

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

Reference them from the top-level README's "Documentation" section.

## Links in documentation

Always prefer GitHub-blob URLs with line ranges (`…/blob/<sha>/path/File.cs#L12-L42`) over file paths when linking from READMEs that will be viewed on GitHub. For local-only markdown (Docs/*.md), relative paths are fine.

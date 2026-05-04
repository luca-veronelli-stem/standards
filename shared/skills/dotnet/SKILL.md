---
name: "dotnet"
description: "Work with .NET 10 / F# / C# projects: build, test, EF Core migrations, NuGet. Load when touching .slnx/.csproj/.fsproj/appsettings."
---

# .NET Skill

Hands-on commands for .NET 10 work in STEM repos. Pairs with:

- The `dotnet` rule file — coding-style invariants (nullability, async, DI, etc.).
- The v1 standards in `docs/Standards/` (or upstream `shared/standards/`) — repo layout, language defaults, central package management, testing strategy. **Read those before adding projects or restructuring.**

## Build & test

Adopted v1 repos use `src/` and `tests/` subfolders, with `Stem.<App>.slnx` at the root.

```powershell
# Build whole solution (Debug)
dotnet build

# Release build (CI does this)
dotnet build -c Release

# All tests (single project default — see TESTING standard)
dotnet test

# Cross-platform leg only (matches CI Linux runner)
dotnet test --framework net10.0

# Single class
dotnet test --filter "FullyQualifiedName~<ClassName>"

# Single method
dotnet test --filter "FullyQualifiedName~<ClassName>.<MethodName>"

# Run the GUI project (archetype A)
dotnet run --project src/<App>.GUI
```

If a project multi-targets (`net10.0;net10.0-windows`, typical for `Drivers.Windows.*`), pass `--framework net10.0` on Linux to skip the Windows leg. The CI standard gates this with `runner.os == 'Linux'`.

## Solution file format

Modern `.slnx` (XML), not legacy `.sln`. To migrate a legacy repo:

```powershell
dotnet sln <Repo>.sln migrate   # writes <Repo>.slnx
```

## Project layout & module separation

See the v1 standards. **Don't invent a layout** — pick the archetype A or B template and follow its tree.

- Archetype A (desktop app): `src/<App>.{Core,Services,Infrastructure,GUI}` + `tests/<App>.Tests` + `specs/`.
- Archetype B (library): `src/Stem.<Lib>.{Abstractions,Protocol,Drivers.<Plat>.<Bus>}` (+ optional `DependencyInjection`) + `tests/`.

Banned-API enforcement happens at the project level — drop a `BannedSymbols.txt` next to the `.fsproj` / `.csproj` of pure layers (`Core`, `Services`, `Abstractions`, `Protocol`). The `Directory.Build.props` template auto-picks it up.

## Central Package Management

`Directory.Packages.props` at the solution root is the single source of truth for NuGet versions. Project files reference packages by name only:

```xml
<!-- in <App>.GUI.fsproj -->
<PackageReference Include="Avalonia.FuncUI" />        <!-- no Version= -->

<!-- in Directory.Packages.props -->
<PackageVersion Include="Avalonia.FuncUI" Version="1.5.1" />
```

Bumping a package: edit `Directory.Packages.props` only. Dependabot is wired to do this weekly (see the CI standard).

## EF Core migrations

For archetype A repos with persistence:

```powershell
# Add a migration
dotnet ef migrations add <Name> -p src/<App>.Infrastructure -s src/<App>.GUI

# Apply migrations to the local DB
dotnet ef database update -p src/<App>.Infrastructure -s src/<App>.GUI

# Undo last migration (before applying)
dotnet ef migrations remove -p src/<App>.Infrastructure -s src/<App>.GUI

# Rollback to a specific migration
dotnet ef database update <PreviousMigrationName> -p src/<App>.Infrastructure -s src/<App>.GUI

# Generate SQL script for review
dotnet ef migrations script -p src/<App>.Infrastructure -s src/<App>.GUI -o migration.sql
```

Conventions:
- Migration names follow `<Verb><Noun>` (PascalCase): `AddDeviceBleMacAddress`.
- Don't edit a migration after it's been applied on anyone else's machine — add a new one.
- Use soft-delete columns (`IsDeleted` + `DeletedAt`) — STEM convention, no physical deletes.

## NuGet sources

Public NuGet (`nuget.org`) is configured by default. Private packages live on **Azure Artifacts**; per-repo `nuget.config` points at the feed:

```xml
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
    <add key="stem-azure" value="https://pkgs.dev.azure.com/<org>/_packaging/<feed>/nuget/v3/index.json" />
  </packageSources>
  <packageSourceCredentials>
    <stem-azure>
      <add key="Username" value="luca" />
      <add key="ClearTextPassword" value="%AZURE_ARTIFACTS_PAT%" />
    </stem-azure>
  </packageSourceCredentials>
</configuration>
```

PAT goes in an env var, never committed:

```powershell
[Environment]::SetEnvironmentVariable('AZURE_ARTIFACTS_PAT', '<pat>', 'User')
```

For archetype B libraries, the v1 release flow publishes to **GitHub Packages** (see CI standard). Azure Artifacts is for legacy/internal packages only.

## Directory.Build.props (root)

Owned by the v1 BUILD_CONFIG standard. Template at `<llm-settings>/shared/templates/Directory.Build.props`. The rollout script writes this on first run; bumps refresh it. Don't hand-edit per-repo unless adding a repo-specific override (then keep the override minimal).

## appsettings

- `appsettings.json` — shared defaults, committed.
- `appsettings.Development.json` — dev overrides, committed.
- `appsettings.Production.json` — production secrets, **never committed** (in `.gitignore` + blocked in `settings.json` deny list).
- Override at runtime with env vars: `Dictionary__ApiKey`, `Device__Variant`, etc. (use `__` for colon in section names).

Per the PORTABILITY standard, `appsettings.json` + `IOptions<T>` replaces `Microsoft.Win32.Registry` for any cross-platform configuration store.

## Tests project — F# in single project default

Per the TESTING standard, the default is one F# `tests/<App>.Tests/` project covering every layer of the repo via project references. Split only when justified; the standard documents the criteria.

For F# tests:

```fsharp
module <App>.Tests.BlePacketDecoderTests

open Xunit
open FsCheck.Xunit

[<Fact>]
let ``Decode truncated payload throws CrcMismatch`` () =
    // ...
    ()

[<Property>]
let ``Decode is the inverse of Encode`` (payload: byte[]) =
    // ...
    true
```

GUI tests run headless via `Avalonia.Headless.XUnit` and `[<AvaloniaFact>]`.

## Troubleshooting

- **"The type or namespace 'Windows' could not be found"** — code that needs WinForms/WPF/Win32 is in a `net10.0` project. Either move it to a `net10.0-windows` project, gate with `#if WINDOWS` in a multi-targeted project, or refactor through a port (see PORTABILITY).
- **"dotnet ef is not recognized"** — `dotnet tool install --global dotnet-ef`.
- **"NU1301: package source unreachable"** — Azure Artifacts PAT expired; refresh it and re-set `AZURE_ARTIFACTS_PAT`.
- **`dotnet format --verify-no-changes` fails** — run `dotnet format` to fix, commit the result. Husky.NET pre-commit catches this; CI is the backstop.
- **Test output is missing** — `dotnet test -v normal` for more verbose output; `dotnet test --logger "console;verbosity=detailed"` for per-test output.
- **`PackageVersion` warning during build** — the package is referenced by name in a project but not declared in `Directory.Packages.props`. Add the `<PackageVersion>` entry there.

---
name: "dotnet"
description: "Work with .NET 10 / C# projects: build, test, dual TFM, EF Core migrations, NuGet, solution files. Load when touching .cs/.csproj/.slnx/appsettings."
---

# .NET Skill

Conventions and commands for working in STEM's .NET 10 / C# repos. Pairs with the `dotnet` rule file (coding style) and the `github-actions` / `bitbucket-pipelines` skills (CI).

## Build & test

```powershell
# Build (default = Debug, all projects in the .slnx)
dotnet build <Repo>.slnx

# Release build with Windows-targeting flag (needed when building WPF/WinForms on Linux CI)
dotnet build <Repo>.slnx -c Release -p:EnableWindowsTargeting=true

# Run all tests (dual TFM — both net10.0 and net10.0-windows)
dotnet test Tests/Tests.csproj

# Cross-platform tests only (matches CI)
dotnet test Tests/Tests.csproj --framework net10.0

# Single class
dotnet test Tests/Tests.csproj --filter "FullyQualifiedName~<ClassName>"

# Single method
dotnet test Tests/Tests.csproj --filter "FullyQualifiedName~<ClassName>.<MethodName>"

# Run the GUI project
dotnet run --project GUI.Windows/GUI.Windows.csproj
```

## Solution file format

Use `.slnx` (modern XML format), not legacy `.sln`. If a repo still has `.sln`, migrate when convenient:

```powershell
dotnet sln <Repo>.sln migrate  # writes <Repo>.slnx
```

## Multi-project layout (canonical)

```
Core/                       net10.0, zero deps     — domain models + interfaces
Infrastructure.Persistence/ net10.0                — data providers (EF, API, Excel)
Infrastructure.Protocol/    net10.0;net10.0-windows — HW adapters (BLE/CAN/Serial)
Services/                   net10.0                — pure business logic
GUI.Windows/                net10.0-windows        — WinForms / WPF entry point
Tests/                      dual TFM               — xUnit
Specs/                      Lean 4                 — formal invariants
```

Dependencies flow downward: `GUI.Windows → {Infrastructure.*, Services} → Core`. `Tests` depends on everything.

## Dual TFM testing

The `Tests.csproj` targets **both** `net10.0` and `net10.0-windows`:

```xml
<TargetFrameworks>net10.0;net10.0-windows</TargetFrameworks>
```

Tests that depend on WinForms/WPF types are gated with a `WINDOWS` compilation symbol defined only in the Windows TFM:

```xml
<PropertyGroup Condition="'$(TargetFramework)' == 'net10.0-windows'">
  <DefineConstants>$(DefineConstants);WINDOWS</DefineConstants>
</PropertyGroup>
```

```csharp
#if WINDOWS
public class MainWindowViewModelTests { ... }
#endif
```

CI runs `--framework net10.0` only (Linux). Local runs cover both.

## EF Core migrations

```powershell
# Add a migration
dotnet ef migrations add <Name> -p Infrastructure.Persistence -s GUI.Windows

# Apply migrations to the local DB
dotnet ef database update -p Infrastructure.Persistence -s GUI.Windows

# Undo last migration (before applying)
dotnet ef migrations remove -p Infrastructure.Persistence -s GUI.Windows

# Rollback to a specific migration
dotnet ef database update <PreviousMigrationName> -p Infrastructure.Persistence -s GUI.Windows

# Generate SQL script for review
dotnet ef migrations script -p Infrastructure.Persistence -s GUI.Windows -o migration.sql
```

Conventions:
- Migration names follow `<Verb><Noun>` (PascalCase): `AddDeviceBleMacAddress`, `ExtendPhaseAssignedAssembler`.
- Don't edit a migration after it's been applied on anyone else's machine — add a new one.
- Use soft-delete columns (`IsDeleted` + `DeletedAt`) — STEM convention, no physical deletes.

## NuGet

Private packages live on **Azure Artifacts**. Each work repo has a `nuget.config` at the root pointing at the feed:

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

Set the PAT as an env var (not committed):

```powershell
[Environment]::SetEnvironmentVariable('AZURE_ARTIFACTS_PAT', '<pat>', 'User')
```

## Directory.Build.props (solution root)

```xml
<Project>
  <PropertyGroup>
    <Version>2.15.0</Version>
    <Authors>Luca Veronelli, Michele Pignedoli</Authors>
    <Copyright>STEM E.m.s.</Copyright>
    <Nullable>enable</Nullable>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>
</Project>
```

All projects inherit these. Per-project `.csproj` files only override when they need to.

## appsettings

- `appsettings.json` — shared defaults, committed.
- `appsettings.Development.json` — dev overrides, committed.
- `appsettings.Production.json` — production secrets, **never committed** (in `.gitignore` + blocked in `settings.json` deny list).
- Override at runtime with env vars: `Dictionary__ApiKey`, `Device__Variant`, etc. (use `__` for colon in section names).

## Troubleshooting

- **"The type or namespace 'Windows' could not be found"** — you're compiling WinForms/WPF code under `net10.0`. Wrap it in `#if WINDOWS` or move it to a `net10.0-windows`-only file.
- **"dotnet ef is not recognized"** — `dotnet tool install --global dotnet-ef`.
- **"NU1301: package source unreachable"** — Azure Artifacts PAT expired or not set; refresh it and re-set `AZURE_ARTIFACTS_PAT`.
- **"WpfResource target missing"** on CI — need `-p:EnableWindowsTargeting=true`.
- **Test output is missing** — `dotnet test -v normal` for more verbose output; `dotnet test --logger "console;verbosity=detailed"` for per-test output.

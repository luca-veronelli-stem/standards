# API Surface — {LibraryName}

<!--
Per-library API surface document. Lives at the repo's Docs/API_SURFACE.md
in archetype B (library) repos. Apps don't have an API surface — this
template is for libraries only.

The document captures the public-facing contract of the library: the
types a consumer constructs, calls, subscribes to, or configures.
Internal types belong in code, not here.

Purpose: orient an integrator who has the package reference and is
about to write the first call. Not a substitute for XML doc — the
XML doc is the per-member reference; this document is the entry-point
narrative.

Section legend:
  REQUIRED — every API surface doc has this section.
  OPTIONAL — include only when the section earns its keep.

Delete the comment blocks and the "[REQUIRED]" / "[OPTIONAL]" labels
before submitting.
-->

> **Library version:** {X.Y.Z} — track via `git describe` or the package version, not a string typed here.

One-paragraph statement of what this library is and the kinds of consumer it serves.

## Quick start                                                [REQUIRED]

A minimal, runnable example that walks the typical flow: construct, configure, call, dispose. Five to fifteen lines — long enough to be real, short enough to fit on screen.

```csharp
using {Library.Namespace};

await using var component = new ComponentBuilder()
    .WithDriver(driver)
    .WithConfiguration(new ComponentConfiguration { TimeoutMs = 2000 })
    .Build();

await component.InitializeAsync(cancellationToken);
var result = await component.ProcessAsync(input, cancellationToken);
```

## Public types — by kind                                     [REQUIRED]

Group by what consumers do with them, not by namespace. Five kinds, in this order:

### Entry points

The types a consumer constructs to use the library. Usually one or two: a facade and a builder.

| Type | Kind | Purpose |
| --- | --- | --- |
| `Component` | `public sealed class` | top-level facade; lifecycle owner |
| `ComponentBuilder` | `public sealed class` | fluent construction |

### Interfaces

The abstractions consumers see in entry-point signatures.

| Type | Purpose |
| --- | --- |
| `IComponentDriver` | injection point for the underlying transport |
| `ICommandHandler` | extensibility hook for custom command processing |

### Configuration

Per the CONFIGURATION standard.

| Type | Purpose |
| --- | --- |
| `ComponentConfiguration` | runtime parameters with `Validate()` |
| `ComponentConstants` | defaults and validation bounds |

### Events / event payloads

Per the EVENTARGS standard. Either `sealed class : EventArgs` or `sealed record`.

| Event | Payload | Raised when |
| --- | --- | --- |
| `Component.StateChanged` | `StateChangedEventArgs` | the lifecycle state transitions |
| `Component.MessageReceived` | `MessageReceived` (record) | a frame is decoded |

### Exceptions and enums

| Type | Kind | Purpose |
| --- | --- | --- |
| `ComponentException` | `public class : Exception` | base for library-thrown exceptions |
| `ComponentTimeoutException` | `public sealed class : ComponentException` | operation exceeded its timeout |
| `ComponentState` | `public enum` | lifecycle state used in events and properties |

## Per-type details                                           [REQUIRED]

For each entry-point type and each interface, a brief section: what it is, how it's constructed (or implemented), and the methods a consumer reaches for. Don't duplicate the XML docs — link to them when the per-member detail matters.

### `Component`

The library's top-level type. Owns the lifecycle (`InitializeAsync` / `DisposeAsync`) and exposes the operations a consumer needs.

```csharp
public sealed class Component : IAsyncDisposable
{
    public Task<bool> InitializeAsync(CancellationToken cancellationToken = default);
    public Task<ProcessResult> ProcessAsync(byte[] input, CancellationToken cancellationToken = default);
    public ComponentState State { get; }
    public event EventHandler<StateChangedEventArgs>? StateChanged;
}
```

### `ComponentBuilder`

…

### `IComponentDriver`

The consumer implements (or selects from `Drivers.*`) the driver that actually moves bytes.

```csharp
public interface IComponentDriver : IAsyncDisposable
{
    Task<bool> ConnectAsync(CancellationToken cancellationToken = default);
    Task SendAsync(byte[] data, CancellationToken cancellationToken = default);
    event EventHandler<DataReceivedEventArgs>? DataReceived;
}
```

## Versioning and breaking changes                            [REQUIRED]

The library follows SemVer. Major bumps include a "Breaking changes" section in `CHANGELOG.md` with a migration recipe. This document tracks the *current* surface; historical surfaces are reachable through git tags.

When breaking changes ship, add a section here matching the latest major:

### Breaking changes — v{N+1}.0.0                            [OPTIONAL]

**Affected consumers:** anyone using {old API}.

**Before (v{N}.x):**

```csharp
component.OldMethod(arg1, arg2);
```

**After (v{N+1}.0):**

```csharp
component.NewMethod(new RequestPayload { Arg1 = arg1, Arg2 = arg2 });
```

Rationale: one or two sentences on why the change was needed.

## Requirements                                               [REQUIRED]

- **.NET runtime:** as declared in `global.json` / project `TargetFramework`.
- **Platform:** any (the `PORTABILITY` standard governs this — Windows-only requirements are confined to clearly-named driver projects).
- **Hardware / external dependencies:** {list, or "none"}.

### Package references

```xml
<ItemGroup>
  <PackageReference Include="{LibraryName}" Version="{X.Y.Z}" />
</ItemGroup>
```

Transitive dependencies are governed by `Directory.Packages.props`; consumers normally need only the library reference itself.

## See also                                                   [OPTIONAL]

- [`README.md`](../README.md) — project overview.
- [`CHANGELOG.md`](../CHANGELOG.md) — version history.
- Per-component READMEs under `<Component>/README.md` for implementation detail.

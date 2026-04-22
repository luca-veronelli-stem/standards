---
paths:
  - "**/*.cs"
  - "**/*.csproj"
  - "**/*.slnx"
  - "**/Directory.Build.props"
  - "**/appsettings*.json"
---

# .NET coding rules (STEM style)

**Language.** Everything in **English** by default — code identifiers, XML comments, markdown, GUI strings, commit bodies, inline comments, CHANGELOG entries. Switch to Italian only on explicit request for a specific artifact.

**Nullability.** `Nullable=enable` everywhere. Never return `null` to signal failure — throw a typed exception or use a discriminated result. Methods that *can* legitimately return nothing use `T?`.

**Async.** Every async method accepts a `CancellationToken` as the last parameter and propagates it. `ConfigureAwait(false)` in libraries; omit it in GUI/app code.

**Thread safety.** Use `Lock` (.NET 9+) or a dedicated `lock` object for critical sections, `Volatile.Read/Write` for lockless flag access, `Interlocked` for counters. No `volatile` keyword on fields.

**Function hygiene.** Prefer functions < 15 LOC. Early returns, not nested `if/else`. Soft limit 100–110 columns, hard limit 120.

**Dependency injection.** Manual DI in the composition root (typically `Program.cs` / `MainWindow` ctor). No `Microsoft.Extensions.DependencyInjection` container unless the project already uses one. Interfaces only where they earn their keep — usually for testability against hardware/IO boundaries, not for future-proofing.

**Mocking.** No mocking libraries. Write manual fakes under `Tests/Integration/Presenter/Mocks/` (or similar). Fakes are normal classes implementing the interface.

**Test layout.** xUnit. Dual TFM: `net10.0` (cross-platform, runs on CI Linux) + `net10.0-windows` (WinForms/WPF-dependent, Windows-only). Gate WinForms/WPF test code with `#if WINDOWS`. Test naming: `{ClassName}Tests` + `{Method}_{Scenario}_{ExpectedResult}`. `[Fact]` for singles, `[Theory]` + `[InlineData]` for parametrized.

**Solution files.** Prefer the modern `.slnx` format, not `.sln`. One `Directory.Build.props` at the solution root carrying `Version`, `Authors`, `Copyright`, and common properties.

**Project shape (typical).**
```
Core/                       net10.0, zero deps     — domain models + interfaces
Infrastructure.Persistence/ net10.0                — data providers (EF, API, Excel…)
Infrastructure.Protocol/    net10.0;net10.0-windows — HW adapters (BLE/CAN/Serial)
Services/                   net10.0                — pure business logic
GUI.Windows/                net10.0-windows        — WinForms / WPF entry point
Tests/                      dual TFM               — xUnit
Specs/                      Lean 4                 — formal invariants
```

**Refactor discipline.** Discuss the plan before implementing. Pragmatic beats elegant. Don't introduce interfaces, generic helpers, or abstractions without a concrete second caller or testability need.

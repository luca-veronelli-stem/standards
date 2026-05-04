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

**Test layout.** xUnit. Single F# tests project per repo by default (`tests/<App>.Tests/`, `net10.0`); split only when the C# surface justifies it. See the TESTING standard. Test naming: `{ClassName}Tests` + `{Method}_{Scenario}_{ExpectedResult}`. `[Fact]` for singles, `[Theory]` + `[InlineData]` for parametrized; `[<Property>]` (FsCheck) for property tests.

**Solution files.** Prefer the modern `.slnx` format, not `.sln`. `Directory.Build.props` and `Directory.Packages.props` (Central Package Management) live at the solution root — see the BUILD_CONFIG standard.

**Project shape and module separation.** Adopted STEM repos follow the v1 standards' archetype layouts (onion for archetype A, hexagonal for archetype B). See `docs/Standards/REPO_STRUCTURE.md` and `docs/Standards/MODULE_SEPARATION.md` inside the repo, or `shared/standards/` upstream in `llm-settings`.

**Language defaults.** F# is the default for new projects per the LANGUAGE standard. Existing C# code stays C# unless there's a separate migration phase. Mixed F#/C# solutions work without ceremony — project references are language-agnostic.

**Refactor discipline.** Discuss the plan before implementing. Pragmatic beats elegant. Don't introduce interfaces, generic helpers, or abstractions without a concrete second caller or testability need.

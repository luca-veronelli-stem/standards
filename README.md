# standards

STEM cross-repo engineering standards: how a STEM .NET repo is shaped, what language and idioms its code follows, what its build and CI look like, and how it migrates between standard versions.

## What's here

Nineteen versioned standards plus the toolchain to apply them to a work repo.

- **Eight structural standards** (`v1.0.0`): `REPO_STRUCTURE`, `LANGUAGE`, `MODULE_SEPARATION`, `PORTABILITY`, `BUILD_CONFIG`, `TESTING`, `CI`, `MIGRATION`. Govern repo shape, build configuration, and the rollout process.
- **Eight content standards** (`v1.2.0`): `CANCELLATION`, `COMMENTS`, `CONFIGURATION`, `ERROR_HANDLING`, `EVENTARGS`, `LOGGING`, `THREAD_SAFETY`, `VISIBILITY`. Govern code-level idiom within adopted repos.
- **Three GUI standards** (`v1.5.0`): `GUI` (Avalonia + FuncUI + Elmish-MVU shape for archetype A apps, with a legacy WinForms/WPF carve-out), `DESIGN_SYSTEM` (Stem brand palette and typography realised, Fluent theme with light default, 4-pt spacing scale, Fluent System Icons, F# strings-module i18n, four error-and-progress surfaces), and `APP_SHELL` (canonical view catalogue + typed `ShellSlots` pattern; Navigation locked to a left sidebar).

Each standard is a single markdown file under [`shared/standards/`](./shared/standards/). Templates that the rollout copies into adopted repos live under [`shared/templates/`](./shared/templates/). The rollout script is [`eng/apply-repo-standard.ps1`](./eng/apply-repo-standard.ps1). Adoption is tracked in [`state/repos.md`](./state/repos.md).

## Layout

```
shared/
  standards/      nineteen standards as markdown files
  templates/      Directory.Build.props, Directory.Packages.props,
                  .github/workflows/, archetype-specific overlays, doc templates
eng/
  apply-repo-standard.ps1  rollout / bump script
state/
  repos.md        adoption tracker (which repo follows which Standard version)
CHANGELOG.md      Keep-a-Changelog history of versioned releases
```

## Archetypes

| Archetype | Shape | Example |
| --- | --- | --- |
| A | Desktop app — onion layering (`Core`/`Services`/`Infrastructure`/`GUI`) | `stem-device-manager`, `stem-button-panel-tester` |
| B | Library — hexagonal layering (`Abstractions`/`Protocol`/`Drivers.*`) | `stem-communication` |
| C | Meta/config — no `src/`, `tests/`, `specs/`. Layout depends on purpose | `standards` (this repo), `llm-settings` |
| D | Reserved — triggers a `new-archetype` design session before adoption |

See [`shared/standards/REPO_STRUCTURE.md`](./shared/standards/REPO_STRUCTURE.md) for the full archetype shapes.

## The standards

| Standard | Since | Purpose |
| --- | --- | --- |
| `REPO_STRUCTURE` | v1.0 | Root layout, archetype trees, naming rules |
| `LANGUAGE` | v1.0 | F# default; layer-default table; deviation policy |
| `MODULE_SEPARATION` | v1.0 | Onion (A) and hexagonal (B) layering; banned APIs |
| `PORTABILITY` | v1.0 | `net10.0` default; TFM-conditional drivers; cross-platform replacements |
| `BUILD_CONFIG` | v1.0 | `Directory.Build.props`, `Directory.Packages.props`, `global.json`, `.editorconfig` |
| `TESTING` | v1.0 | xUnit + FsCheck + Avalonia.Headless; single F# tests project default |
| `CI` | v1.0 | GitHub Actions: `ci.yml`, `mirror-bitbucket.yml`, `release.yml`; matrix legs |
| `MIGRATION` | v1.0 | Per-repo adoption phases; major/minor/patch bump procedures |
| `EVENTARGS` | v1.2 | Two valid event-payload shapes (`sealed class : EventArgs` or `sealed record`); banned primitives |
| `VISIBILITY` | v1.2 | Archetype-aware default-internal (B) / default-public (A); seal-by-default (CA1852) |
| `LOGGING` | v1.2 | `ILogger<T>` (optional in B, required in A); structured-only; `Console.WriteLine` banned |
| `THREAD_SAFETY` | v1.2 | Decision order (immutability → `Channel<T>` → primitives); .NET 10 `Lock`; sync-over-async banned |
| `CANCELLATION` | v1.2 | `CancellationToken` propagation; linked-CTS timeout; OCE handling |
| `COMMENTS` | v1.2 | XML doc coverage by visibility; English by default; `<inheritdoc/>` |
| `ERROR_HANDLING` | v1.2 | Try-pattern / Result type / exception decision tree; BCL throw helpers |
| `CONFIGURATION` | v1.2 | Constants → Configuration → Service pattern; library + app delivery mechanisms |
| `GUI` | v1.5 | Avalonia + FuncUI + Elmish-MVU; `<App>.GUI/` layout; composition root; legacy WinForms/WPF carve-out |
| `DESIGN_SYSTEM` | v1.5 | Fluent theme + light default (brand-aligned); 4-pt spacing scale; Fluent System Icons; Poppins typography; Stem brand palette (Blu Stem + Cool Gray + RossoAlert + division identity colors); F# strings module for i18n; toast/banner/inline/modal error surfaces |
| `APP_SHELL` | v1.5 | Canonical view catalogue (Settings / About / LanguagePicker / NotificationCenter / ConnectionStatus); typed `ShellSlots` pattern; Navigation locked to left sidebar |

## Adopting these standards in a repo

First-time bootstrap:

```powershell
& '<standards>/eng/apply-repo-standard.ps1' `
    -RepoPath <work-repo> `
    -App <Name> -Archetype A `
    -Owner <user> -LucaUser <user> `
    -StandardVersion v1.3.3
```

Subsequent bumps read `.stem-standard.json` from the work repo, so only `-StandardVersion` needs to change. See [`MIGRATION.md`](./shared/standards/MIGRATION.md) for the full procedure.

The rollout writes inline copies of the standards under the work repo's `docs/Standards/`. Those copies are regenerated by the script — don't hand-edit them; edit the upstream files in `shared/standards/` here instead.

## Versioning

Tags are git tags (`v1.0.0`, `v1.1.0`, …). Each adopted repo pins to a specific version via the `**Standard version:**` line in its top-level `CLAUDE.md`; [`state/repos.md`](./state/repos.md) mirrors those pins. Bump rules:

- **Major** — breaking change to a standard or template that forces adopters to migrate or pin an older version.
- **Minor** — new standard, new template, or non-breaking change to an existing one.
- **Patch** — bug fixes, typos, clarifications, internal refactors. No change to documented contracts.

See [`MIGRATION.md`](./shared/standards/MIGRATION.md) for the per-version bump procedure.

## Related repos

This repo holds the standards themselves. Agent-side wiring (the Claude Code rules and skills that operationalize these standards) lives in [`luca-veronelli-stem/llm-settings`](https://github.com/luca-veronelli-stem/llm-settings).

## History

This repo started as the `shared/standards/`, `shared/templates/`, `eng/`, and `state/` sections of `llm-settings`, itself forked from [`paolino/llm-settings`](https://github.com/paolino/llm-settings). Extracted into a standalone repo at the `v1.3.3` cut.

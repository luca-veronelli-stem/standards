# STEM repo standards adoption

Single source of truth for which `standards` Standard version each STEM repo follows.

The repo itself also declares the same version in its top-level `CLAUDE.md` (see `shared/templates/CLAUDE.md`). This file mirrors those declarations so a single glance shows which repos lag.

## Repos

| Repo | Archetype | Standard version | Last bumped | Notes |
| --- | --- | --- | --- | --- |
| `stem-device-manager` | A | — | — | not yet adopted |
| `stem-communication` | B | — | — | not yet adopted; rename + sub-package split planned |
| `stem-production-tracker` | A | — | — | not yet adopted |
| `stem-button-panel-tester` | A | v1.3.2 | 2026-05-07 | bumped to v1.3.2 via the seed-then-restore recipe (#42 / #45); v1.3.3 / v1.4.0 / v1.5.0 / v1.5.1 bump pending — v1.5.0 brings the GUI standards trio, v1.5.1 the F# first-adopter gap fixes (FSharp.Core CPM + lean/-vs-specs/ doc clarification that lets the constitution drop its deviation paragraph) |
| `stem-dictionaries-manager` | A | v1.3.2 | 2026-05-07 | adopted at v1.3.2; app with internal class library — see MIGRATION.md; v1.3.3 / v1.4.0 / v1.5.0 / v1.5.1 bump pending — v1.5.0 brings the GUI standards trio, v1.5.1 the F# first-adopter gap fixes |
| `spark-log-analyzer` | A | — | — | not yet adopted |
| `standards` (this repo) | C | n/a | n/a | self-referential — defines the standards |
| `llm-settings` | C | n/a | n/a | sibling agent-config repo extracted at v1.3.3 (#57); unversioned, HEAD-only |

## Archetype legend

- **A — Desktop App.** Avalonia + FuncUI, end-user GUI, packaged release artifacts (`release.yml` workflow).
- **B — Library.** NuGet-publishable, hexagonal layout (`Abstractions`, `Protocol`, `Drivers.*`, optional `DependencyInjection`).
- **C — Meta/Config.** No runtime build (`standards` itself).
- **D — New (placeholder).** Triggers a `new-archetype` design session when a candidate repo doesn't fit A/B/C.

## Updating this table

When a repo is bumped to a new Standard version:

1. Bump the `**Standard version:**` line in that repo's `CLAUDE.md` to the new tag (e.g. `v1.0.0`).
2. Update the `Standard version` and `Last bumped` columns here.
3. If the bump is a major version, open a follow-up migration PR per repo (the `MIGRATION` standard documents the per-version steps).
4. Commit both changes together when possible — the per-repo `CLAUDE.md` change can land with whatever PR triggers the bump, and this file is updated in `standards` immediately afterwards.

## Naming convention for the version field

- `v1.0.0` — git tag from `standards`. Always with the `v` prefix, always full SemVer triple.
- `—` — repo exists but has not yet adopted any standard.
- `n/a` — concept of a Standard version doesn't apply to this repo (e.g. `standards` itself).

## Pending adoption — v1.5.1

`v1.5.1` closes the **first-adopter gaps** uncovered while bootstrapping `button-panel-tester` on `v1.5.0`. Three patch-level fixes, all backwards-compatible:

1. **`FSharp.Core` `PackageVersion` restored** in `shared/templates/Directory.Packages.props` (dropped accidentally in v1.5.0). Without it, an F# `<PackageReference Include="FSharp.Core" />` is rejected by Central Package Management and the runtime doesn't flow into bin/ — xunit's reflection discoverer then fails opaquely. Pinned at `10.1.201` (v1.3.2 baseline); Dependabot can take it from here.
2. **Archetype A greenfield scaffold** — the rollout now emits `Stem.<App>.slnx` + `src/<App>.Core/{<App>.Core.fsproj,Placeholder.fs}` + `tests/<App>.Tests/{<App>.Tests.fsproj,PlaceholderTests.fs}` on bootstrap, so the first PR is CI-green without any hand-rolled follow-up. The scaffold files are bootstrap-only: a subsequent rollout never re-creates them after deletion or clobbers adopter edits.
3. **`lean/` vs `specs/` clarified** in `REPO_STRUCTURE.md` (+ the README template, CI cache-key gate, and the MIGRATION v1.2.0 salvage hint). `specs/` is now unambiguously the spec-kit feature root; `lean/` is the Lean 4 workspace (`lakefile.lean` + `lean-toolchain` + namespace folders mirroring the F# tree). They're independent siblings — either may be omitted. Doc-only — no rollout-script behaviour changes, no namespace renames, no forced moves on adopters with existing Lean trees under `specs/`.

Per-repo adoption follows `MIGRATION.md`'s "Rollout phase for v1.5.1" recipe. For an existing v1.5.0 adopter the diff is one new `<PackageVersion Include="FSharp.Core" ... />` line in `Directory.Packages.props` (the scaffold files are skipped by the bootstrap-only rule), plus the per-repo `CLAUDE.md` `**Standard version:**` bump. Adopters with no F# code at all can defer the bump until they have other reasons to move (e.g. v1.6.x).

For repos still on v1.5.0 / earlier, the v1.5.0 GUI work also applies on the same bump: the GUI standards trio (`GUI`, `DESIGN_SYSTEM`, `APP_SHELL`), the Poppins font bundle landing under `src/<App>.GUI/Resources/fonts/`, the placeholder-substitution + binary-copy rollout extensions, and the per-app wiring of `LanguagePicker` + `NotificationCenter` + optional `ConnectionStatus` components through a typed `ShellSlots<Msg>` record. The `<App>.GUI.Windows` legacy carve-out keeps in-flight WinForms/WPF code compliant while the Avalonia migration proceeds.

Repos still on v1.4.0 / earlier additionally pick up the workflow-stub migration (caller stubs delegating to reusable workflows shipped from this repo) and the v1.4.0 template refreshes. `MIGRATION.md`'s "Rollout phase for v1.4.0" still applies for those; the `standards` repo is public, so cross-repo `uses:` references resolve without any Actions-access prerequisite. Hand-customised workflow files trip the local-edit guard and need `-Force` or hand-merge.

Repos still on v1.2.0 / earlier additionally pick up the v1.2.0 standards bundle (eight standards + three doc templates) and the v1.2.1 template-placeholder fix on the same bump. `MIGRATION.md`'s v1.2.0 section still applies for those: each work repo runs a one-time export of any open `<Component>/ISSUES.md` / root-level `ISSUES_TRACKER.md` entries to GitHub Issues *before* the rollout PR deletes those files on disk. Per-component `README.md` files are not regenerated automatically — the rollout script's ownership ends at the top-level `README.md` and `CLAUDE.md`. Pre-v1 component READMEs are typically deleted (a snapshot lives in `feat/legacy-docs-snapshot`); new ones are added selectively from `shared/templates/docs/README_TEMPLATE.md` only when a component genuinely earns its keep. See `MIGRATION.md`'s v1.2.0 section for the salvage checklist that runs alongside the ISSUES export.

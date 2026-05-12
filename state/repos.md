# STEM repo standards adoption

Single source of truth for which `standards` Standard version each STEM repo follows.

The repo itself also declares the same version in its top-level `CLAUDE.md` (see `shared/templates/CLAUDE.md`). This file mirrors those declarations so a single glance shows which repos lag.

## Repos

| Repo | Archetype | Standard version | Last bumped | Notes |
| --- | --- | --- | --- | --- |
| `stem-device-manager` | A | — | — | not yet adopted |
| `stem-communication` | B | — | — | not yet adopted; rename + sub-package split planned |
| `stem-production-tracker` | A | — | — | not yet adopted |
| `stem-button-panel-tester` | A | v1.3.2 | 2026-05-07 | bumped to v1.3.2 via the seed-then-restore recipe (#42 / #45) |
| `stem-dictionaries-manager` | A | — | — | not yet adopted; app with internal class library — see MIGRATION.md |
| `spark-log-analyzer` | A | — | — | not yet adopted |
| `standards` (this repo) | C | n/a | n/a | self-referential — defines the standards |

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

## Pending adoption — v1.3.3

`v1.3.3` refreshes pinned third-party versions in the templates so newly-adopted repos don't replay the same Dependabot wave on day one. **GitHub Actions**: `actions/cache v4 → v5`, `actions/setup-dotnet v4 → v5`, `softprops/action-gh-release v2 → v3`, `dorny/test-reporter v1 → v3` (with `use-actions-summary: 'false'` to keep the per-OS Tests check rendering as a Check Run instead of falling silently into `$GITHUB_STEP_SUMMARY` — issue #49). **NuGet**: the Microsoft.* libs in `shared/templates/Directory.Packages.props` moved from `9.0.1` to `10.0.7` to match `Directory.Build.props`'s `net10.0` target; `FsCheck.Xunit` patch-bumped `3.3.0 → 3.3.3`; Avalonia and `Microsoft.NET.Test.Sdk` majors deferred (issue #51). Also wires `.github/dependabot.yml` on `standards` itself so future GHA drift is caught here first, with a new `MIGRATION.md` "Keeping the templates current" section codifying the mirror rule (issue #50).

Per-repo adoption follows `MIGRATION.md`'s minor-bump procedure — re-run `eng/apply-repo-standard.ps1 -StandardVersion v1.3.3`, review the diff (template-version stamps in `Directory.Packages.props` and the workflows), bump the per-repo `CLAUDE.md`, then update the table above. The seed-then-restore recipe from v1.3.2's pending section still applies to repos still on a pre-`v1.3.1` lockfile.

Repos still on v1.2.0 / earlier additionally pick up the v1.2.0 standards bundle (eight standards + three doc templates) and the v1.2.1 template-placeholder fix on the same bump. `MIGRATION.md`'s v1.2.0 section still applies for those: each work repo runs a one-time export of any open `<Component>/ISSUES.md` / root-level `ISSUES_TRACKER.md` entries to GitHub Issues *before* the rollout PR deletes those files on disk. Per-component `README.md` files are not regenerated automatically — the rollout script's ownership ends at the top-level `README.md` and `CLAUDE.md`. Pre-v1 component READMEs are typically deleted (a snapshot lives in `feat/legacy-docs-snapshot`); new ones are added selectively from `shared/templates/docs/README_TEMPLATE.md` only when a component genuinely earns its keep. See `MIGRATION.md`'s v1.2.0 section for the salvage checklist that runs alongside the ISSUES export.

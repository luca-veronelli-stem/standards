# STEM repo standards adoption

Single source of truth for which `standards` Standard version each STEM repo follows.

The repo itself also declares the same version in its top-level `CLAUDE.md` (see `shared/templates/CLAUDE.md`). This file mirrors those declarations so a single glance shows which repos lag.

## Repos

| Repo | Archetype | Standard version | Last bumped | Notes |
| --- | --- | --- | --- | --- |
| `stem-device-manager` | A | — | — | not yet adopted |
| `stem-communication` | B | — | — | not yet adopted; rename + sub-package split planned |
| `stem-production-tracker` | A | — | — | not yet adopted |
| `stem-button-panel-tester` | A | v1.3.2 | 2026-05-07 | bumped to v1.3.2 via the seed-then-restore recipe (#42 / #45); v1.3.3 / v1.4.0 bump pending |
| `stem-dictionaries-manager` | A | v1.3.2 | 2026-05-07 | adopted at v1.3.2; app with internal class library — see MIGRATION.md; v1.3.3 / v1.4.0 bump pending |
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

## Pending adoption — v1.4.0

`v1.4.0` migrates workflow templates from full inline jobs to thin caller stubs that delegate to reusable workflows shipped from this repo (`dotnet-ci.yml`, `mirror-bitbucket.yml`, `release-archetype-{a,b}.yml`). After the bump, a pin change in a reusable workflow (e.g. `actions/setup-dotnet`) propagates to adopted repos on their next CI run without a per-repo PR. The `standards` repo is public, so cross-repo `uses:` references resolve without any Actions-access prerequisite. v1.4.0 also folds in the v1.3.3 template refreshes (GHA pin updates from issue #49, NuGet bumps from issue #51, `.github/dependabot.yml` on `standards` itself from issue #50) and fixes the `xunit 2.9.4` pin regression (#64).

Per-repo adoption follows `MIGRATION.md`'s minor-bump procedure — re-run `eng/apply-repo-standard.ps1 -StandardVersion v1.4.0`, review the diff (workflow templates now stubs; template-version stamps in `Directory.Packages.props`), bump the per-repo `CLAUDE.md`, then update the table above. Hand-customised workflow files trip the local-edit guard and need `-Force` or hand-merge.

Repos still on v1.2.0 / earlier additionally pick up the v1.2.0 standards bundle (eight standards + three doc templates) and the v1.2.1 template-placeholder fix on the same bump. `MIGRATION.md`'s v1.2.0 section still applies for those: each work repo runs a one-time export of any open `<Component>/ISSUES.md` / root-level `ISSUES_TRACKER.md` entries to GitHub Issues *before* the rollout PR deletes those files on disk. Per-component `README.md` files are not regenerated automatically — the rollout script's ownership ends at the top-level `README.md` and `CLAUDE.md`. Pre-v1 component READMEs are typically deleted (a snapshot lives in `feat/legacy-docs-snapshot`); new ones are added selectively from `shared/templates/docs/README_TEMPLATE.md` only when a component genuinely earns its keep. See `MIGRATION.md`'s v1.2.0 section for the salvage checklist that runs alongside the ISSUES export.

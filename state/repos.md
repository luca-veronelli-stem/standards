# STEM repo standards adoption

Single source of truth for which `llm-settings` Standard version each STEM repo follows.

The repo itself also declares the same version in its top-level `CLAUDE.md` (see `shared/templates/CLAUDE.md`). This file mirrors those declarations so a single glance shows which repos lag.

## Repos

| Repo | Archetype | Standard version | Last bumped | Notes |
| --- | --- | --- | --- | --- |
| `stem-device-manager` | A | — | — | not yet adopted |
| `stem-communication` | B | — | — | not yet adopted; rename + sub-package split planned |
| `stem-production-tracker` | A | — | — | not yet adopted |
| `stem-button-panel-tester` | A | v1.2.1 | 2026-05-06 | bumped to v1.2.1 (docs standards + placeholder hints) |
| `stem-dictionaries-manager` | A | — | — | not yet adopted; app with internal class library — see MIGRATION.md |
| `spark-log-analyzer` | A | — | — | not yet adopted |
| `llm-settings` | C | n/a | n/a | self-referential — defines the standards |

## Archetype legend

- **A — Desktop App.** Avalonia + FuncUI, end-user GUI, packaged release artifacts (`release.yml` workflow).
- **B — Library.** NuGet-publishable, hexagonal layout (`Abstractions`, `Protocol`, `Drivers.*`, optional `DependencyInjection`).
- **C — Meta/Config.** No runtime build (`llm-settings` itself).
- **D — New (placeholder).** Triggers a `new-archetype` design session when a candidate repo doesn't fit A/B/C.

## Updating this table

When a repo is bumped to a new Standard version:

1. Bump the `**Standard version:**` line in that repo's `CLAUDE.md` to the new tag (e.g. `v1.0.0`).
2. Update the `Standard version` and `Last bumped` columns here.
3. If the bump is a major version, open a follow-up migration PR per repo (the `MIGRATION` standard documents the per-version steps).
4. Commit both changes together when possible — the per-repo `CLAUDE.md` change can land with whatever PR triggers the bump, and this file is updated in `llm-settings` immediately afterwards.

## Naming convention for the version field

- `v1.0.0` — git tag from `llm-settings`. Always with the `v` prefix, always full SemVer triple.
- `—` — repo exists but has not yet adopted any standard.
- `n/a` — concept of a Standard version doesn't apply to this repo (e.g. `llm-settings` itself).

## Pending adoption — v1.3.2

`v1.3.2` is a docs-only patch on top of `v1.3.1`'s rollout-script fix (issue #42): `MIGRATION.md`'s Pitfalls section now spells out the seed-then-restore recipe (`-Force` → `git checkout HEAD -- <files>` → hand-bump version stamps) for repos with substantive local divergence on previously-unprotected files (issue #45). Per-repo adoption follows `MIGRATION.md`'s minor-bump procedure — re-run `eng/apply-repo-standard.ps1 -StandardVersion v1.3.2`, regenerate inline copies under `docs/Standards/`, bump the per-repo `CLAUDE.md`, then update the table above. **First post-`v1.3.1` run** on a pre-fix lockfile still skips previously-unprotected files; consult the updated Pitfalls section to pick the right recipe.

Repos still on v1.2.0 / earlier additionally pick up the v1.2.0 standards bundle (eight standards + three doc templates) and the v1.2.1 template-placeholder fix on the same bump. `MIGRATION.md`'s v1.2.0 section still applies for those: each work repo runs a one-time export of any open `<Component>/ISSUES.md` / root-level `ISSUES_TRACKER.md` entries to GitHub Issues *before* the rollout PR deletes those files on disk. Per-component `README.md` files are kept (regenerated using the new template).

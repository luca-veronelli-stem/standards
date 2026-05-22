# STEM repo standards adoption

Single source of truth for which `standards` Standard version each STEM repo follows.

The repo itself also declares the same version in its top-level `CLAUDE.md` (see `shared/templates/CLAUDE.md`). This file mirrors those declarations so a single glance shows which repos lag.

## Repos

| Repo | Archetype | Standard version | Last bumped | Notes |
| --- | --- | --- | --- | --- |
| `stem-device-manager` | A | — | — | not yet adopted |
| `stem-communication` | B | — | — | not yet adopted; rename + sub-package split planned |
| `stem-production-tracker` | A | — | — | not yet adopted |
| `stem-button-panel-tester` | A | v1.3.2 | 2026-05-07 | bumped to v1.3.2 via the seed-then-restore recipe (#42 / #45); greenfield successor: `button-panel-tester` (see row below) |
| `button-panel-tester` | A | v1.9.0 | 2026-05-22 | greenfield successor to `stem-button-panel-tester`; first v1.5.x adopter |
| `stem-dictionaries-manager` | A | v1.3.2 | 2026-05-07 | adopted at v1.3.2; app with internal class library — see MIGRATION.md |
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

Per-release adoption notes (what each bump brings, the per-version migration recipe, etc.) live in `CHANGELOG.md` and `shared/standards/MIGRATION.md`. This file is the current-state matrix only.

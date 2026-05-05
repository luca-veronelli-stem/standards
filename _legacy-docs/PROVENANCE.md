# _legacy-docs provenance

Snapshot of each rollout-phase repo's pre-rollout markdown content, taken before the v1 standards rollout (`eng/apply-repo-standard.ps1` + per-repo adoption PRs) regenerates each repo's `Docs/Standards/`. Tracks issue #20.

## Snapshot scope

Two passes, both committed to this branch:

1. **Pass 1 (full `Docs/` tree)** — `cp -R Docs/` per repo. Captures `.puml`, `.lean`, `.csv`, `.xlsx`, `.txt` etc. alongside markdown. Lands at `_legacy-docs/<repo>/docs/` (lowercase target path).
2. **Pass 2 (all tracked markdown)** — every `*.md` from `git ls-files` per repo, preserving the source's path layout. Captures per-component `README.md` / `ISSUES.md` and root-level `ISSUES_TRACKER.md` / `CHANGELOG.md` / `CLAUDE.md`.

Result: each repo's snapshot includes its full Pass-1 `Docs/` tree plus every tracked `.md` file mirrored at its source path.

## Per-repo state at snapshot time (current)

| Repo | Branch | HEAD SHA | Working tree |
| --- | --- | --- | --- |
| `stem-device-manager` | `main` | `5dd2c5c7a016f20acd0681755ee0ca203dd559a7` | clean |
| `stem-communication` | `main` | `2c2a7a0966f6aa69a258c9fed98bc0df71035f18` | clean |
| `stem-button-panel-tester` | `chore/v1.1.0-adoption` | `aca456bcd526e8a4b31a3ed90abd1bfa79549868` | **4 uncommitted change(s)** |
| `spark-log-analyzer` | `main` | `fc48c25904b784c7027c9d5aa84b58c8d0009938` | clean |
| `stem-production-tracker` | `main` | `ba517980ce1185677c229f27265053e2800a3bca` | clean |
| `stem-dictionaries-manager` | `main` | `859abc7a039f054911f93391b9ae6a8fb22e5434` | clean |

## Notes

- `stem-button-panel-tester` is mid-adoption on `chore/v1.1.0-adoption` and has 4 staged deletions in `Docs/Standards/Templates/` (`TEMPLATE_STANDARD.md`, `STANDARD_TEMPLATE.md`, `README_TEMPLATE.md`, `ISSUES_TEMPLATE.md`). Pass 2 couldn't read them from disk; Pass 1 captured them earlier and they live at `_legacy-docs/stem-button-panel-tester/docs/Standards/...` (lowercase path).
- All other repos were on `main` and clean at Pass 1; current state is reflected in the table above.
- Dependency: when comparing this snapshot against a future `docs/Standards/` rollout, anchor diffs to the recorded HEAD SHA per repo — that's the canonical pre-rollout state.

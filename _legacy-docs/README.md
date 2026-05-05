### `_legacy-docs/` — pre-rollout snapshots

Frozen copies of the legacy docs system from each work repo before the v1 standards rollout (phases 2–7 in `shared/standards/MIGRATION.md`) regenerates `Docs/Standards/` from templates. Source of truth for what gets promoted into `shared/standards/`, `shared/templates/docs/`, and the per-component README/ISSUES system while resolving issue #20.

- **Layout** — one subdirectory per repo. Each repo carries:
  - its full pre-rollout `Docs/` tree (Pass 1, snapshotted under lowercase `docs/` for historical reasons),
  - every tracked `*.md` file mirrored at its original path (Pass 2) — including per-component `README.md`, `ISSUES.md`, top-level `ISSUES_TRACKER.md`, `CHANGELOG.md`, and `CLAUDE.md`.
- **Provenance** — `PROVENANCE.md` records each repo's branch / HEAD SHA / working-tree state at snapshot time. Anchor any future diff to those SHAs.
- **Language** — content is mostly Italian; promotion to `shared/` requires translation per the English-by-default rule in `claude/CLAUDE.md`.
- **Lifecycle** — once #20 closes and all v1 rollouts have landed, this folder can be deleted; git history preserves the snapshot if anyone needs it again.

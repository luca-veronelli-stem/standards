### `_legacy-docs/` — pre-rollout snapshots

Frozen copies of `docs/` from each work repo before the v1 standards rollout (phases 2–7 in `shared/standards/MIGRATION.md`) regenerates `docs/Standards/` from templates. Source of truth for what was promoted into `shared/standards/` and `shared/templates/docs/` while resolving issue #20.

- One subdirectory per repo (`<repo>/docs/...`).
- `PROVENANCE.md` records each repo's branch, HEAD SHA, and remote at snapshot time so any future diff is anchored.
- Content language is mostly Italian; promotion to `shared/` requires translation per the English-by-default rule in `claude/CLAUDE.md`.
- Once #20 closes and all v1 rollouts have landed, this folder can be deleted — git history preserves the snapshot if anyone needs it again.

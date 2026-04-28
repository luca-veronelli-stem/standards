# Promote conventions to `llm-settings` (don't bury them in memory)

When the user gives guidance that meets ALL of these:

- **Cross-repo** — applies regardless of which project I'm in.
- **Durable** — a convention or preference, not a project fact or one-off.
- **Stable** — unlikely to be revised within a few sessions.

…suggest promoting it to a rule (`claude/rules/`) or skill (`shared/skills/`) in `llm-settings`, instead of (or in addition to) saving it as memory.

Never auto-edit `llm-settings` without confirmation. Propose the change (file path, name, body), then act on yes.

## Counter-examples — keep in memory, do **not** promote

- Project-specific facts (e.g. "merge freeze starts 2026-03-05").
- One-shot corrections that don't generalize beyond the current task.
- Tone or response-shape tweaks already covered by `communication.md`.
- Anything tied to a particular repo's filenames, modules, or domain logic.

## Rule vs. skill — quick test

- **Rule**: a short directive ("always do X", "never do Y") that's load-bearing on every turn → `claude/rules/<name>.md`.
- **Skill**: a multi-step workflow with its own context, tools, or scripts → `shared/skills/<name>/SKILL.md`.

If unsure, propose a rule first; skills are more work to set up and only earn their keep when there's a real workflow to encode.

## Mechanics when promoting

- The `worktree-guard.ps1` hook blocks edits on `main`/`master`. Always create a feature branch first.
- Update `README.md` if the new rule/skill belongs in the table or skill list.
- Commit on a feature branch and open a PR on GitHub (`llm-settings` is GitHub-only).

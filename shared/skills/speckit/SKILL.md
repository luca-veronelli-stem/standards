---
name: "speckit"
description: "Spec-Driven Development workflow: specify → plan → tasks → implement, with Lean formalization in parallel when applicable."
---

# Spec Kit — Spec-Driven Development

GitHub Spec Kit provides a Spec-Driven Development (SDD) workflow. Specifications are the primary source of truth; code is the generated output.

## Per-project setup

Only `.specify/` (scripts, templates, `memory/constitution.md`) belongs in the repo. The agent-facing prompt skills live **globally** under `~/.claude/skills/` (projected from `shared/skills/speckit-*/` in `llm-settings`) — do not duplicate per-project.

### Initialize spec-kit in a project

Spec-kit has a standalone CLI. On this machine, install once via `uv`:

```powershell
uv tool install specify-cli
```

Then from the project root:

```powershell
specify init --here --ai claude --script sh --offline --ignore-agent-tools
```

Answer `y` if prompted about a non-empty directory. Clean up per-project copies that `specify init` always writes (we have them globally):

```powershell
Remove-Item -Recurse -Force .claude/commands/speckit.*.md -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .claude/skills/speckit-*     -ErrorAction SilentlyContinue
Remove-Item -Force .claude/commands, .claude/skills, .claude -ErrorAction SilentlyContinue
```

For a brand-new project directory, drop `--here`:

```powershell
specify init <project-name> --ai claude --script sh --offline
cd <project-name>
# … same cleanup as above
```

## SDD Workflow

Each step is a skill. The workflow is sequential; each step produces artifacts consumed by the next.

1. **`speckit-constitution`** — Define principles and quality gates. One-time per project.
2. **`speckit-specify`** — Feature spec from natural language. Creates a branch + `spec.md`.
3. **`speckit-clarify`** *(optional)* — Clarification Q&A to de-risk ambiguous areas.
4. **`speckit-plan`** — Implementation plan (`plan.md`, `research.md`, `data-model.md`, contracts).
5. **`speckit-checklist`** *(optional)* — Quality checklists for requirements validation.
6. **`speckit-analyze`** *(optional)* — Cross-artifact consistency check.
7. **`speckit-tasks`** — Break plan into dependency-ordered `tasks.md`.
8. **`speckit-implement`** — Execute tasks phase by phase.
9. **`speckit-taskstoissues`** *(optional)* — Convert tasks to GitHub issues.

## Key principles

- Specs describe **WHAT** and **WHY**, never HOW (no stack, APIs, code structure).
- Written for business stakeholders first; developers read them too.
- Each feature gets its own numbered branch.
- Tasks are organized by user story for independent implementation and testing.
- Constitution defines project-wide principles that gate planning decisions.

## Constitution: what to include (STEM context)

When writing `.specify/memory/constitution.md`, derive from:
- The project's purpose and domain (e.g., industrial device comm, production tracking).
- The `dotnet` rule file (nullable, CancellationToken, no mocks libs, manual DI).
- The `dual-remote` rule (GitHub active, Bitbucket mirror).
- The `workflow` skill (no commit on main, rebase merge, conventional commits).
- Lean 4 formalization commitments (if the project has `Specs/PhaseN/`).

Typical sections:
1. **Core Principles** — pragmatic core, correctness, testability, linear history.
2. **Domain constraints** — protocol invariants, persistence rules, BLE/CAN timing, etc.
3. **Development workflow** — PRs, conventional commits, CI gates.
4. **Governance** — how the constitution itself gets updated.

## Lean 4 pairing (when applicable)

When the repo has `Specs/PhaseN/`, the SDD workflow runs in parallel with the Lean formalization loop (see the `lean4` and `workflow` skills). Rough mapping:

- `speckit-specify` outputs prose invariants → they become Lean predicates.
- `speckit-plan` research sections → Lean state machines and preservation theorems.
- `speckit-tasks` → one task per `#if WINDOWS`-gated test block + one per `.lean` file.
- `speckit-implement` → C# impl, with Lean predicates gating each commit's `dotnet test` run.

## Troubleshooting

- **"specify: command not found"** → `uv tool install specify-cli` didn't take; check `uv tool list` and `$env:PATH`.
- **Stale per-project `.claude/skills/speckit-*`** → re-run the cleanup `Remove-Item` block above.
- **Constitution out of date** → update `.specify/memory/constitution.md` before starting `speckit-specify` on a new feature; otherwise planning decisions get gated on stale rules.

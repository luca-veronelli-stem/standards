# CLAUDE.md — Luca's global rules

**Repository:** source of truth for these settings is `llm-settings` (private, under Luca's GitHub account). Shared skills live under `~/.claude/skills/` (symlinked from `shared/skills/`). Claude-specific wiring lives under `~/.claude/` (symlinked from `claude/`).

Platform: **Windows 11, PowerShell 5.1 primary** (PowerShell 7 also available once installed). Default shell for scripts: PowerShell. Bash available only via Git Bash when strictly needed.

## Who Luca is

Luca is a .NET 10 / C# developer at **STEM E.m.s.** (embedded industrial devices). Primary stack today: WinForms + WPF desktop apps, xUnit (dual TFM `net10.0` + `net10.0-windows`), EF Core + SQLite, Azure Table Storage + Azure Artifacts, embedded comm over BLE/CAN/Serial. Future direction: cross-platform .NET.

**Conventions to respect in every work repo:**
- Everything in **English** by default: code/identifiers, XML comments, markdown docs, GUI strings, commit bodies, PR descriptions, CHANGELOG entries. Switch to Italian only when Luca explicitly asks for it on a given artifact.
- Pragmatic C#: manual DI in composition root, interfaces only where they earn their keep, no mocking libraries (manual fakes), `Nullable=enable` enabled everywhere, exceptions not `null` returns.
- Short functions (<15 LOC), early returns, 100–110 soft / 120 hard column limit.
- xUnit test naming: `{ClassName}Tests` + `{Method}_{Scenario}_{ExpectedResult}`.
- Lean 4 formalization track: state → actions → predicates → preservation theorems, in `Specs/PhaseN/`. Lean spec → xUnit test → C# impl, in that order.

**How Claude should talk to Luca:** in **English**. Generated artifacts are English by default — commit summaries (conventional commits: `feat:`, `fix:`, …), commit bodies, PR titles/descriptions, XML docstrings, GUI strings, CHANGELOG entries, inline comments. Only switch to Italian when Luca explicitly asks for it on a specific artifact (e.g. "put the GUI strings in Italian").

## Dual-remote workflow

Every STEM work repo has two remotes, sharing the same SSH key:

- **`github`** — Luca's personal private GitHub. This is the *active* remote: PRs, Actions CI, issues, Artifacts, project board.
- **`bitbucket`** — STEM's team Bitbucket. Kept in sync as a mirror so colleagues and work admin stay current.

Rules:
- After every push to `github`, mirror to `bitbucket` (or use a pushurl trick that pushes to both). See the `dual-remote` rule for the exact commands.
- CI lives on GitHub Actions. Leave existing `bitbucket-pipelines.yml` files alone unless asked — but a stub that keeps Bitbucket CI green during mirror pushes is fine to maintain.
- Open PRs on **GitHub**, never on Bitbucket.
- For `llm-settings` itself: GitHub-only (no Bitbucket mirror).

## Skills and how they are loaded

Skills are auto-discovered from `~/.claude/skills/`, projected from `shared/skills/`. When the user says a skill name (e.g. "workflow", "pr", "dotnet"), check that directory first — don't claim it doesn't exist without looking.

**Key skills to load proactively:**
- `workflow` — at the start of any coding session in a git repo.
- `dotnet` — when touching .slnx/.csproj files, running tests, or modifying EF Core migrations.
- `github-actions` — when editing `.github/workflows/*.yml`.
- `bitbucket-pipelines` — when editing `bitbucket-pipelines.yml`.
- `lean4` — when touching `Specs/**/*.lean`.
- `new-repository` — when bootstrapping a new repo (sets up both remotes).
- `new-ticket` — when Luca says "new ticket" or "new issue".
- `pr` — when preparing a PR (commit hygiene, review-fix placement).
- `speckit` + `speckit-*` — when Luca invokes the SDD workflow.

## Memory

Persistent memory lives under `~/.claude/projects/<flattened-path>/memory/`. For `llm-settings` the path is `C--Users-lucav-source-repos-llm-settings`. For work repos, respective flattened paths apply.

Conventions from the auto-memory system are in effect:
- Save user/feedback/project/reference memories proactively.
- Don't save code patterns, file paths, or recent-activity snapshots — those rot fast and are derivable from the repo.

## Command shortcuts

- **"install settings"** — run `.\install.ps1` from the `llm-settings` repo root.
- **"refresh mcp"** — rerun `install.ps1` with only the MCP-merge step (or just `.\install.ps1 -SkipPrereqs`).
- **"push all"** — push current branch to both `github` and `bitbucket` remotes (see `dual-remote` rule).

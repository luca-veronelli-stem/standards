# llm-settings

Personal Claude Code configuration for Luca — .NET 10 / C# work at STEM, Windows 11, dual-remote git workflow (GitHub primary, Bitbucket mirror).

Forked and heavily rewritten from [`paolino/llm-settings`](https://github.com/paolino/llm-settings). The shape is the same (skills / rules / MCP servers versioned in a repo, symlinked into `~/.claude/`), but everything Nix/Haskell/Cardano-specific has been stripped or replaced.

## Layout

```
install.ps1                  Windows PowerShell installer (PS 5.1 compatible)
CHANGELOG.md                 SemVer changelog for the standards bundle
claude/
  CLAUDE.md                  global rules loaded by Claude Code
  settings.json              permissions, hooks, MCP enablement
  commands/                  custom slash-commands
  hooks/                     PreToolUse scripts (.ps1)
  rules/                     path-scoped rules (dotnet, dual-remote, stem-conventions, …)
  scripts/                   helper scripts (Python/PowerShell)
shared/
  skills/                    reusable skills (workflow, pr, dotnet, github-actions, …)
  standards/                 v1 cross-repo standards (REPO_STRUCTURE, LANGUAGE, …)
  templates/                 templates copied into work repos by the rollout script
  memory/                    per-project persistent memory (optional)
  mcp/servers.json           MCP server definitions merged into ~/.claude.json
eng/
  apply-repo-standard.ps1    rollout / bump script (per-repo adoption of standards)
state/
  repos.md                   STEM repos adoption tracker (which version each repo follows)
```

## Install

From the repo root, in PowerShell:

```powershell
.\install.ps1
```

Full flow:

1. Checks Windows Developer Mode (needed for symlinks without admin). If OFF, prints the one-line instruction to toggle it and stops.
2. Installs prerequisites via `winget` (idempotent — skips already-installed): Node.js LTS, GitHub CLI, PowerShell 7, Python 3.12. Then `uv` via pip, `elan` via its installer.
3. Symlinks `settings.json`, `CLAUDE.md`, `skills/`, `rules/`, `commands/`, `hooks/` into `%USERPROFILE%\.claude\`.
4. Symlinks per-project memory files into `%USERPROFILE%\.claude\projects\<project>\memory\`.
5. Merges `shared/mcp/servers.json` into `%USERPROFILE%\.claude.json`.

Re-run whenever you want to refresh. Use `.\install.ps1 -SkipPrereqs` to skip the winget step, or `.\install.ps1 -SkipMcp` to skip the `.claude.json` merge.

### Prereqs — what gets installed

| Tool         | Source        | Why                                  |
| ------------ | ------------- | ------------------------------------ |
| Node.js LTS  | winget        | `npx` for `context7` and `playwright` MCP |
| GitHub CLI   | winget        | PRs, issues, Actions runs, `new-ticket` skill |
| PowerShell 7 | winget        | Better JSON handling, nicer scripting |
| Python 3.12  | winget        | needed by some MCP servers (Lean LSP toolchain ecosystem) |
| uv           | winget (`astral-sh.uv`) | `uvx` lightweight script runner used by `lean-lsp` MCP |
| elan         | elan-init.ps1 | Lean 4 toolchain (`lake`, `lean`) |

After a fresh install:

```powershell
gh auth login           # authenticate GitHub CLI
# then open a NEW PowerShell window so PATH changes take effect
```

## What's wired up

### Rules (auto-applied based on path)

| Rule                       | Scope                                       |
| -------------------------- | ------------------------------------------- |
| `communication`            | Always on — tone, conciseness, no trailing summaries |
| `no-attribution`           | Always on — no "Generated with Claude" footers |
| `dotnet`                   | `*.cs`, `*.csproj`, `*.slnx`, `appsettings*.json` |
| `dual-remote`              | Always on — two-remote git workflow conventions |
| `promote-to-llm-settings`  | Always on — route durable, cross-repo guidance into this repo instead of memory |
| `stem-conventions`         | `**/.stem-standard.json`, `**/docs/Standards/REPO_STRUCTURE.md` — points STEM work repos at the v1 standards |

### Skills (available globally via `~/.claude/skills/`)

Workflow & process: `workflow`, `pr`, `cleanup`, `new-repository`, `new-ticket`, `repo-report`

Stack-specific: `dotnet`, `github-actions`, `bitbucket-pipelines`, `lean4`, `documentation`

Spec-Driven Development: `speckit` + `speckit-{analyze,checklist,clarify,constitution,implement,plan,specify,tasks,taskstoissues}`

General-purpose: `semantic-nav`

### Standards (v1)

Cross-repo conventions for STEM work repos live in `shared/standards/`. Inline copies land in each work repo's `docs/Standards/`, pinned to a specific Standard version:

| Standard | Since | Purpose |
| --- | --- | --- |
| `REPO_STRUCTURE` | v1.0 | Root layout, archetype trees, naming rules |
| `LANGUAGE` | v1.0 | F# default; layer-default table; deviation policy |
| `MODULE_SEPARATION` | v1.0 | Onion (A) and hexagonal (B) layering; banned APIs |
| `PORTABILITY` | v1.0 | `net10.0` default; TFM-conditional drivers; cross-platform replacements |
| `BUILD_CONFIG` | v1.0 | `Directory.Build.props`, `Directory.Packages.props`, `global.json`, `.editorconfig` |
| `TESTING` | v1.0 | xUnit + FsCheck + Avalonia.Headless; single F# tests project default |
| `CI` | v1.0 | GitHub Actions: `ci.yml`, `mirror-bitbucket.yml`, `release.yml`; matrix legs |
| `MIGRATION` | v1.0 | Per-repo adoption phases; major/minor/patch bump procedures |
| `EVENTARGS` | v1.2 | Two valid event-payload shapes (`sealed class : EventArgs` or `sealed record`); banned primitives |
| `VISIBILITY` | v1.2 | Archetype-aware default-internal (B) / default-public (A); seal-by-default (CA1852) |
| `LOGGING` | v1.2 | `ILogger<T>` (optional in B, required in A); structured-only; `Console.WriteLine` banned |
| `THREAD_SAFETY` | v1.2 | Decision order (immutability → `Channel<T>` → primitives); .NET 10 `Lock`; sync-over-async banned |
| `CANCELLATION` | v1.2 | `CancellationToken` propagation; linked-CTS timeout; OCE handling |
| `COMMENTS` | v1.2 | XML doc coverage by visibility; English by default; `<inheritdoc/>` |
| `ERROR_HANDLING` | v1.2 | Try-pattern / Result type / exception decision tree; BCL throw helpers |
| `CONFIGURATION` | v1.2 | Constants → Configuration → Service pattern; library + app delivery mechanisms |

Templates that land in each work repo (`Directory.Build.props`, `.editorconfig`, GitHub workflows, issue/PR templates, etc.) live under `shared/templates/`. Doc templates for authoring new standards and per-component READMEs live under `shared/templates/docs/`; the archetype-B-only `API_SURFACE.md` template lives under `shared/templates/archetypes/B/docs/`. Each STEM repo declares its **Standard version** in its top-level `CLAUDE.md`; `state/repos.md` mirrors those declarations.

### Rollout script

```powershell
& '<llm-settings>/eng/apply-repo-standard.ps1' `
    -RepoPath <work-repo> `
    -App <Name> -Archetype A `
    -Owner <user> -LucaUser <user> `
    -StandardVersion v1.0.0
```

On subsequent bumps the script reads `.stem-standard.json` from the work repo, so only `-StandardVersion` needs to change. See the `MIGRATION` standard for the full procedure.

### MCP servers

| Name         | Purpose                                    |
| ------------ | ------------------------------------------ |
| `context7`   | Library/API docs lookup (NuGet, .NET, EF Core, xUnit) |
| `playwright` | Browser automation (Azure Portal, Bitbucket UI, …) |
| `lean-lsp`   | Lean 4 LSP bridge for `Specs/PhaseN/*.lean` |

### Hooks

- `PreToolUse` on `Edit|Write` → `worktree-guard.ps1` refuses to edit if the current git branch is `main` or `master`. Create a feature branch first.

## Commands

- **"install settings"** — run `.\install.ps1` from this repo.
- **"refresh mcp"** — `.\install.ps1 -SkipPrereqs` (re-merges the MCP config only).
- **"push all"** — push current branch to both `github` and `bitbucket` remotes. See the `dual-remote` rule for the pushurl trick.

## Maintenance

This repo is GitHub-only (no Bitbucket mirror). Push to `github` directly:

```powershell
git push github main
```

To add the remote for the first time, after cloning or initializing:

```powershell
git remote add github git@github.com:<luca-user>/llm-settings.git
git push -u github main
```

## Known limitations

- **`issue-lifecycle` MCP is not wired up.** The Python script in `claude/scripts/issue-lifecycle-mcp.py` targets `paolino/Planning` and needs write access to that board. Once access is granted (ask Paolo), wire it into `shared/mcp/servers.json`.
- **`check-links` hook not ported.** Paolino's version was Babashka (`.bb`). A PowerShell rewrite is on the phase-2 list.
- **Windows Developer Mode required** unless you run install.ps1 as admin. Symlinks are non-negotiable — repo edits need to be live in `~/.claude/`.

## Credits

Original structure by [Paolo Veronelli (`paolino`)](https://github.com/paolino). This fork strips the Linux/Nix/Haskell/Cardano scaffolding and replaces it with a Windows/.NET/STEM equivalent.

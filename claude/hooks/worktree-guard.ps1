<#
.SYNOPSIS
    PreToolUse hook that blocks Edit/Write while the current git branch is main/master.

.DESCRIPTION
    Reads Claude Code's PreToolUse input from stdin (not strictly required —
    we rely on CWD), checks whether CWD is a git repo sitting on main or
    master, and exits 2 (block) if so. Exits 0 (allow) in every other case:
    non-git directories, detached HEAD, feature branches, etc.

    Rationale: Luca's workflow is "always through a PR, never directly on
    main". This hook is the last safety net before an Edit or Write lands
    on the wrong branch.

    Bypass: either switch to a feature branch (`git switch -c feat/x`) or
    temporarily comment out the hook entry in settings.json.
#>

$ErrorActionPreference = 'SilentlyContinue'

# Drain stdin so Claude Code doesn't block on the pipe (we don't need the payload).
if (-not [Console]::IsInputRedirected) {} else { [Console]::In.ReadToEnd() | Out-Null }

$branch = git rev-parse --abbrev-ref HEAD 2>$null
if ($LASTEXITCODE -ne 0 -or -not $branch) {
    exit 0
}

if ($branch -eq 'main' -or $branch -eq 'master') {
    Write-Host "worktree-guard: refusing to edit on '$branch'." -ForegroundColor Red
    Write-Host "Create a feature branch first:"
    Write-Host "  git switch -c feat/<description>"
    Write-Host "Then retry the edit."
    exit 2
}

exit 0

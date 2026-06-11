#Requires -Version 7
$ErrorActionPreference = 'Stop'

# Mechanical gate for issue #133: untrack .claude/settings.local.json and
# gitignore *.local.json. Run from the worktree root.

$failures = @()

# Universal: catch whitespace errors in the diff
git diff --check
if ($LASTEXITCODE -ne 0) { $failures += 'git diff --check reported whitespace errors' }

# Acceptance: .claude/settings.local.json is no longer tracked
$tracked = git ls-files '.claude/settings.local.json'
if ($tracked) { $failures += '.claude/settings.local.json is still tracked' }

# Acceptance: the ignore pattern covers the path
git check-ignore -q '.claude/settings.local.json'
if ($LASTEXITCODE -ne 0) { $failures += 'git check-ignore does not match .claude/settings.local.json' }

# Acceptance: cached untrack, not a working-tree delete
if (-not (Test-Path '.claude/settings.local.json')) { $failures += 'working-tree copy was deleted' }

# Acceptance: no other tracked file references the de-tracked path.
# gate.ps1 is excluded: it names the path by design and is dropped before merge.
$refs = git grep -l 'settings.local.json' -- ':(exclude)gate.ps1'
if ($refs) { $failures += "tracked files still reference settings.local.json: $refs" }

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host "FAIL: $_" }
    Write-Error "gate.ps1: $($failures.Count) check(s) failed"
}
Write-Host 'gate.ps1: all checks green'

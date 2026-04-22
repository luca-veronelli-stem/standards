---
name: "cleanup"
description: "Sweep repo hygiene: stale branches, merged PR cleanup, orphan worktrees, closed issues on the Planning board."
---

# Cleanup

Run periodically (weekly or when things feel stale). Safe by default — every destructive step is dry-run first.

## Trigger

User invokes `/cleanup` or explicitly asks to sweep hygiene.

## Workflow

### Step 1: Stale local branches

List branches whose upstream is gone or which are already merged into `main`:

```powershell
# Merged into main
git fetch github
git branch --merged github/main | Where-Object { $_ -notmatch 'main' -and $_.Trim() -ne '' }

# Upstream gone
git branch -vv | Select-String 'origin/.*: gone'
```

**Present the list. Ask for confirmation.** Then:

```powershell
git branch -d <branch>    # safe delete (only if merged)
git branch -D <branch>    # force delete (use only after confirmation)
```

### Step 2: Orphan worktrees (if you use them)

```powershell
git worktree list
git worktree prune --dry-run
```

Remove worktrees whose branch is merged or deleted:

```powershell
git worktree remove <path>
```

**Warning:** uncommitted changes in the worktree are lost. Verify first.

### Step 3: Stale remote branches

On GitHub, delete branches whose PRs were merged (GitHub does this automatically if the repo setting is on — check):

```powershell
gh api repos/<owner>/<repo> --jq .delete_branch_on_merge
```

If `false`, sweep manually:

```powershell
gh pr list --state merged --limit 50 --json headRefName,number,title
```

### Step 4: Planning board (paolino/Planning)

> **Note:** Luca doesn't yet have write access to `paolino/Planning`. This step only works once access is granted — until then, skip it.

Find items on the Planning board whose linked issue is closed, and set their status to Done:

```powershell
# List open Planning items
gh project item-list 2 --owner paolino --format json --limit 200 | ConvertFrom-Json

# Use the issue-lifecycle MCP (once installed) — it wraps the GraphQL calls
# mcp__issue-lifecycle__mark_done(owner, repo, issue_number)
```

### Step 5: Claude memory garbage

Scan `~/.claude/projects/<flattened>/memory/MEMORY.md` for entries pointing to files that no longer exist, or memories that are obviously outdated (refer to a branch that's gone, a file that was deleted, a one-off session decision).

Ask before removing. Memory loss is invisible and irreversible.

## Safety rules

- **Dry-run first.** Every step shows what would be done before doing it.
- **Never `git branch -D` without confirmation.**
- **Never `git worktree remove --force`** unless you've explicitly confirmed no uncommitted work.
- **Never bulk-close issues** even if their PRs merged — the title/thread is reference material.

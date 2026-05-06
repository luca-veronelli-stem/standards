---
name: "pr"
description: "Prepare a clean PR: vertical commits, rebase onto base, address review by rewriting history, not by stacking fixup commits."
---

# PR Skill

Preparing a pull request for review. Built on plain git + `gh`, not StGit.

## Principles

The commit history is for the **reviewer**, not the author. Nobody wants to see "fix: forgot dependency" — they want a clean logical progression. Mistakes and false starts don't belong in the history.

Four rules shape the series:

1. **Vertical commits.** Each commit solves one problem end-to-end through all layers. Prefer one wider commit that moves a feature through types → callers → tests, over N commits where intermediate states don't make sense on their own.

2. **Bisect-safe.** Every commit must compile and pass its own tests in isolation. If a vertical slice needs code that a later commit will rewrite, add a small clearly-commented stub.

3. **Docs travel with code.** XML comments, markdown, and explanatory notes belong in the commit that introduces the code they describe. No separate `docs:` commit stacking on top.

4. **Review fixes go to the origin commit.** When review surfaces a problem with an earlier commit (stray whitespace, missing XML doc, lost note), fix it in that commit via interactive rebase — don't stack a fixup on the tip.

The anti-pattern for all four: treating commits like a journal. The goal is a curated sequence.

## Workflow

### 1. Before you push

Rebase onto the latest target branch:

```powershell
git fetch github main
git rebase github/main
```

Resolve conflicts as they come. Then:

```powershell
git push -u github feat/<description>
# or, if rebasing an existing branch:
git push --force-with-lease github feat/<description>
```

### 2. Open the PR

```powershell
gh pr create --repo <user>/<repo> --base main --title "feat: <short imperative>" --body "$(cat PR_BODY.md)"
```

Body is the narrative (see template below). Add labels and assignees before posting.

### 3. Respond to review

For each review comment:

1. Decide the **origin commit** — the commit that introduced the code being criticized. Not the tip, unless the fix is genuinely new behavior.
2. Write the fix locally.
3. Create a fixup commit: `git commit --fixup=<origin-sha>`
4. When all fixes are in, squash them back: `git rebase -i --autosquash github/main`
5. Re-run local tests + build.
6. Force-push: `git push --force-with-lease`
7. Reply to the GitHub comment linking to the new commit SHA so the reviewer can follow.

### 4. Before merging

- Run `gh pr checks <PR>` — all checks must be green.
- Ensure the PR description is current. It's the living record of the change.
- Use rebase merge: `gh pr merge <PR> --rebase --delete-branch`. Only squash when the series is messy.
- Never merge on a red CI.

## Stacked PRs — base-branch deletion trap

When a stack of PRs targets each other (`A ← B ← C`, where `B`'s base is `A`'s branch), merging the foundation with `--delete-branch` will **auto-close every dependent PR**. GitHub closes the dependents because their base ref no longer exists, and **closed PRs whose base is gone cannot be reopened** — review history, comments, and approvals are lost. Recreating against `main` works but starts the review from scratch.

### Pre-merge defence

Before merging any PR in a stack, retarget every later PR onto `main` (or onto the next surviving branch in the stack). Then merge bottom-up. Each rebase-merge after the first looks like a no-op cherry-pick because the commits are already on `main`.

```powershell
# For each dependent PR in the stack, before touching the foundation:
gh pr edit <PR> --base main
```

Then merge the foundation:

```powershell
gh pr merge <foundation-PR> --rebase --delete-branch
```

### Recovery

If a dependent PR is already closed and the base branch is gone, reopen will fail. The only path forward is recreate against `main`:

```powershell
gh pr create --base main --title "<original title>" --body "<original body>`n`nReplaces #<old-PR>."
```

Cross-link the old PR in the body for context. Comments and approvals on the old PR are not recoverable.

### Local cleanup after each rebase-merge

Feature branches still parented on the pre-merge SHA need to be rebased onto the new `main`:

```powershell
git fetch github
git rebase github/main
git push --force-with-lease
```

The cherry-pick of the just-merged commit is auto-skipped — git detects the patch is already in the upstream history.

## PR body template

```markdown
## Summary

<one paragraph: what this PR does and why.>

## Changes

- <file/area>: <what changed and why>
- <file/area>: <...>

## Design notes

<alternatives considered; invariants preserved; edge cases handled.>

## Review focus

Please pay particular attention to <specific file/area>.

## Testing

- [ ] dotnet build -c Release
- [ ] dotnet test Tests/Tests.csproj --framework net10.0
- [ ] Manual run-through of <feature>
```

## Mechanical gates

Run locally before pushing, and after every rebase:

```powershell
dotnet build -c Release
dotnet test Tests/Tests.csproj --framework net10.0
# For Windows-only paths:
dotnet test Tests/Tests.csproj --framework net10.0-windows
```

If a gate fails, fix and re-run. Don't push red.

## Bisect-safe stubs

When a vertical slice needs code a later commit will rewrite, add a small clearly-marked stub:

```csharp
// NOTE: stub for bisect-safety, replaced in <next-concern>
internal static class BootStateStub { }
```

Stubs must be replaced by the next commit. Never leave a stub at the tip of the final series.

## Upstream handoff checklist

- [ ] `git log --oneline github/main..HEAD` — one logical concern per commit.
- [ ] No `style:`/`docs:`/`fixup!` commits that belong in earlier commits.
- [ ] No stub code at the tip.
- [ ] `dotnet build` + `dotnet test` pass on every commit (walk the stack: `git rebase github/main -x "dotnet build && dotnet test"`).
- [ ] PR body is accurate for the final state.
- [ ] Luca has given explicit go-ahead to open the PR.

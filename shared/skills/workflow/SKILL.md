---
name: "workflow"
description: "Git workflow: dual-remote, branching, commits, PRs, no-commit-on-main. Load at the start of any coding session in a git repo."
---

# Workflow — Luca's default

## Honesty over agreement

AI sycophancy — the tendency to tell you what you want to hear — is a structural bias. This workflow actively counteracts it:

- **Correct errors.** If you're wrong, say so directly. Don't soften.
- **Say "I don't know".** Never fabricate confidence.
- **Disagree openly.** Raise problems early, not after they break things.
- **No performative enthusiasm.** Don't praise ideas to be agreeable.
- **Flag your own uncertainty.** Distinguish what you know, what you infer, what you guess.

This overrides all politeness norms.

## Clickable links in every output

Every verifiable artifact must be a clickable link: PRs, issues, Actions runs, local file paths, commits (`owner/repo@sha`), branches. Don't make the user hunt for what you created.

## Core rules

- **Never commit directly to `main`.** Always through a feature branch + PR.
- **Design phase first.** For non-trivial features: discuss the plan → write the spec (Lean or markdown) → implement. No code before the invariants are stable.
- **Follow skills exactly.** When a skill gives steps, follow them. Ask if something seems missing instead of improvising.
- **Big deletions require approval.** Removing functions, tests, modules, or large logic blocks? Stop and present what you'll delete before acting.
- **For .NET work, load the `dotnet` skill.** For Lean work, load `lean4`. For CI edits, load `github-actions` or `bitbucket-pipelines`.

## Branching

```
feat/<description>     New features
fix/<description>      Bug fixes
refactor/<description> Refactoring with no behavior change
docs/<description>     Docs only
chore/<description>    Maintenance
test/<description>     Test-only changes
```

Keep branch scope disciplined — never accumulate feat work on a fix branch. If scope changes mid-flight, stop, merge current branch, create a new one.

## Dual-remote workflow

Every STEM repo has two remotes sharing the same SSH key:

- **`github`** (Luca's private GitHub) — active remote for PRs, Actions CI, issues.
- **`bitbucket`** (STEM team) — mirror for colleagues and work admin.

`llm-settings` itself is GitHub-only — no Bitbucket side.

See the `dual-remote` rule file for exact push setup and pushurl trick.

## Commits

Conventional Commits:

```
feat: add BLE device discovery
fix: handle empty packet in PacketDecoder
refactor: extract ConnectionManager from Form1
docs: update PROTOCOL.md with CRC16 details
chore: bump xUnit to 2.9.3
test: add integration tests for BootService
```

- Lowercase after colon, imperative mood, present tense.
- Summary in English. Body (if any) in Italian, matching the repo's convention.
- One concern per commit. If a change logically belongs to an earlier commit, use `git commit --fixup=<sha>` then `git rebase -i --autosquash` before pushing.

## Pull requests

- Always use PRs, even for small fixes. Never `git push github main`.
- Open PRs on **GitHub** via `gh pr create`.
- PR title follows conventional commits format; PR body is the narrative of the change (what, why, alternatives considered, what to look at during review).
- Labels: at least one of `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`.
- Never merge if CI is red. Use `gh pr checks <PR>` to verify.
- Prefer **rebase merge** over squash or merge-commit to keep history linear. Squash only when consolidating a noisy commit stream.

## Small focused commits

Each commit addresses a single concern. If a change belongs to an earlier commit, rewrite history with `rebase -i` or `commit --fixup` + `rebase --autosquash`. Don't add "fix the previous commit" commits — the reviewer doesn't care about your false starts.

## Pre-push check

Before every push, run the local equivalent of CI:

```powershell
dotnet build -c Release
dotnet test Tests/Tests.csproj --framework net10.0
```

Catch formatting/build/test issues locally. Round-trips through GH Actions are minutes; local checks are seconds.

## Spec-Driven Development (optional but recommended)

For non-trivial features, the `speckit` skill runs: `speckit-specify` → `speckit-plan` → `speckit-tasks` → `speckit-implement`. The constitution gates planning decisions. Load `speckit` when starting a new feature track.

## Lean formalization (when applicable)

When the repo has a `Specs/PhaseN/` directory, the design loop is:

```
Discuss → Document (prose) → Formalize (Lean 4) → Refine docs → Repeat
```

The loop is done when: all invariants have a Lean predicate, all theorems compile with no `sorry` or custom axioms, docs reference the predicate names. Load the `lean4` skill when editing `.lean` files.

## WIP notes

Long-running branches benefit from a local `WIP.md` (gitignored) tracking status, plan, and decisions. If a session crashes, it's the recovery anchor.

## Open source / upstream contributions

Never push to external repos or submit upstream PRs without explicit Luca approval. Fork first, work locally, show the diff, wait for approval, then push.

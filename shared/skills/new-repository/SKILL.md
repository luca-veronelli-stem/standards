---
name: "new-repository"
description: "Bootstrap a new repo: init, dual-remote setup, labels, branch protection, stub CI."
---

# New Repository Setup

Creating a new STEM work repo (bootstrap on GitHub + mirror on Bitbucket), or a new GitHub-only repo (like `llm-settings`).

## Step 1: Create the GitHub repo

```powershell
gh repo create <luca-user>/<repo-name> --private --clone
cd <repo-name>
```

Use `--public` only when explicitly requested. Default to private for work repos.

## Step 2: Dual-remote setup (STEM work repos only)

Rename `origin` to `github` and add `bitbucket`:

```powershell
git remote rename origin github
git remote add bitbucket git@bitbucket.org:stem-fw/<repo-name>.git
```

Wire the mirror pushurl so `git push github <branch>` hits both hosts:

```powershell
git remote set-url --add --push github git@github.com:<luca-user>/<repo-name>.git
git remote set-url --add --push github git@bitbucket.org:stem-fw/<repo-name>.git
git remote -v  # verify: github has two (push) lines, bitbucket has one each
```

Skip this step for GitHub-only repos like `llm-settings`.

## Step 3: Initial files

```
README.md
.gitignore     # use dotnet or the appropriate language default
LICENSE        # "proprietary — STEM E.m.s." for work repos
.editorconfig  # standard C# conventions
```

For .NET solutions, also add:

```
Directory.Build.props  # Version, Authors, Copyright, common TargetFramework
<Repo>.slnx            # solution file (modern XML format, not .sln)
Core/Core.csproj
Tests/Tests.csproj
```

## Step 4: Stub CI

**GitHub Actions must exist on `main` before the first PR**, otherwise PR-triggered workflows don't run.

Commit a minimal `.github/workflows/ci.yml` that always passes, then push to `main`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build-gate:
    name: Build Gate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "CI stub — replaced by real CI in the first feature PR"
```

Push to main directly (this is the *only* legit direct-to-main push):

```powershell
git add .github/workflows/ci.yml README.md .gitignore LICENSE
git commit -m "chore: bootstrap CI stub"
git push github main
```

The first feature PR then replaces the stub with the real CI (see the `github-actions` skill for .NET workflow templates). For Bitbucket side, a matching `bitbucket-pipelines.yml` stub goes in the same bootstrap commit — see the `bitbucket-pipelines` skill.

## Step 5: Labels

Apply the conventional-commits label set:

```powershell
$labels = @(
    @{name='feat';     color='a2eeef'; desc='New feature'},
    @{name='fix';      color='d73a4a'; desc='Bug fix'},
    @{name='docs';     color='0075ca'; desc='Documentation'},
    @{name='chore';    color='ededed'; desc='Maintenance'},
    @{name='refactor'; color='e8d44d'; desc='Code refactoring'},
    @{name='test';     color='bfd4f2'; desc='Tests'},
    @{name='ci';       color='c5def5'; desc='CI/CD changes'}
)
foreach ($l in $labels) {
    gh label create $l.name --repo "<luca-user>/<repo-name>" --color $l.color --description $l.desc --force
}
```

## Step 6: Branch protection (rulesets)

Apply the baseline ruleset on `main`: block deletion, block force-push, require linear history, require PR (no direct pushes, rebase/squash only).

**Note:** rulesets require **GitHub Pro** for private repos but are free for public repos. Skip this step for private repos on a free account (the GitHub UI shows a "main isn't protected" banner that links to a paywall).

```powershell
$body = @'
{
  "name": "main protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["rebase", "squash"]
      }
    }
  ]
}
'@
$body | gh api repos/<luca-user>/<repo-name>/rulesets -X POST --input -
```

The ruleset applies to Luca too (`current_user_can_bypass: never`) — every change goes through a PR. If a hotfix ever needs to bypass, edit the ruleset to add a bypass actor temporarily, then remove.

**Optional — required status checks.** Once the real CI replaces the bootstrap stub (Step 9), wire the relevant job names as required checks via a `required_status_checks` rule. Job names vary per project type (.NET, Lean, etc.), so this is per-repo, not part of the baseline.

```powershell
# Append to the rules array of the existing ruleset, then PUT.
{ "type": "required_status_checks",
  "parameters": {
    "strict_required_status_checks_policy": false,
    "required_status_checks": [ { "context": "<job-name>" } ]
  }
}
```

## Step 7: Description, topics, homepage

```powershell
gh api repos/<luca-user>/<repo-name> -X PATCH `
    -f description="<one-line summary>" `
    -f homepage=""

$topics = @{ names = @('dotnet', 'stem') } | ConvertTo-Json
$topics | gh api repos/<luca-user>/<repo-name>/topics -X PUT --input -
```

## Step 8: Speckit (optional)

If using Spec-Driven Development, initialize spec-kit:

```powershell
npx -y @github/spec-kit init --here --ai claude --script sh --offline --ignore-agent-tools
# Remove per-project speckit-* skills (we have them globally)
Remove-Item -Recurse -Force .claude/commands/speckit.*.md -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .claude/skills/speckit-*     -ErrorAction SilentlyContinue
Remove-Item -Force .claude/commands, .claude/skills, .claude -ErrorAction SilentlyContinue
```

Fill `.specify/memory/constitution.md` with the project's principles — see the `speckit` skill.

## Step 9: First feature PR

Create a feature branch, replace the CI stub with the real workflow from the `github-actions` skill, open the PR.

```powershell
git switch -c feat/initial-ci
# edit .github/workflows/ci.yml with the real workflow
git add .
git commit -m "feat: add real CI workflow with dotnet build + test"
git push -u github feat/initial-ci
gh pr create --title "feat: add real CI" --body "Replaces the bootstrap stub with the actual CI pipeline." --label ci
```

---
name: "new-repository"
description: "Bootstrap a new repo: gh create + dual-remote + apply v1 standards + labels + branch protection."
---

# New Repository Setup

Creating a new STEM work repo (GitHub-primary, Bitbucket-mirror) or a GitHub-only repo. The v1 standards rollout script (`<llm-settings>/eng/apply-repo-standard.ps1`) does most of the structural work; this skill covers the steps that live outside the script.

## Step 1: Create the GitHub repo

```powershell
gh repo create <luca-user>/<repo-name> --private --clone
cd <repo-name>
git commit --allow-empty -m "chore: bootstrap"
git push origin main
```

Use `--public` only when explicitly requested. Default to private for work repos. The empty bootstrap commit makes `main` exist before adding other commits.

## Step 2: Dual-remote setup (STEM work repos only)

Rename `origin` to `github` and add `bitbucket`:

```powershell
git remote rename origin github
git remote add bitbucket git@bitbucket.org:stem-fw/<repo-name>.git
git remote set-url --push bitbucket no_push   # Bitbucket fetch-only; mirror via Actions
git remote -v
```

Skip this step for GitHub-only repos like `llm-settings`. See the `dual-remote` rule for the full mirror-workflow setup (deploy key, Actions secret, workflow file).

## Step 3: Apply the v1 standards (rollout script)

Run the rollout script from `llm-settings`. It lays down templates, archetype overlay, inline standards, and `.stem-standard.json`:

```powershell
& 'C:\Users\LucaV\Source\Repos\llm-settings\eng\apply-repo-standard.ps1' `
    -RepoPath . `
    -App <AppName> `
    -Archetype A `
    -Owner <luca-user> `
    -LucaUser <luca-user> `
    -StandardVersion v1.0.0 `
    -Description '<one-line summary>'
```

Use `-DryRun` to preview. After the script runs:

```powershell
git switch -c chore/v1-bootstrap
git add .
git commit -m "chore: bootstrap v1 standards (Stem.<App>, archetype A)"
```

The first feature project (`src/<App>.Core/<App>.Core.fsproj`, etc.) goes in **the same PR or a follow-up** — the script doesn't create source projects, only the toolchain scaffold.

## Step 4: Labels

The issue templates ship with conventional-commits labels (`feat`, `fix`, `chore`). Apply the full label set so PRs/issues can be filtered:

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

## Step 5: Branch protection (rulesets)

Apply the baseline ruleset on `main`: block deletion, block force-push, require linear history, require PR (rebase/squash only).

**Note:** rulesets require **GitHub Pro** for private repos but are free for public repos. Skip for private repos on a free account (a "main isn't protected" banner links to a paywall).

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

The ruleset applies to Luca too (`current_user_can_bypass: never`) — every change goes through a PR.

After the first green CI run, append a `required_status_checks` rule referencing the matrix job names:

```jsonc
{ "type": "required_status_checks",
  "parameters": {
    "strict_required_status_checks_policy": false,
    "required_status_checks": [
      { "context": "build (ubuntu-latest)" },
      { "context": "build (windows-latest)" }
    ]
  }
}
```

## Step 6: `delete_branch_on_merge`

```powershell
gh api -X PATCH /repos/<luca-user>/<repo-name> -F delete_branch_on_merge=true
```

## Step 7: Description, topics

```powershell
gh api repos/<luca-user>/<repo-name> -X PATCH `
    -f description="<one-line summary>" `
    -f homepage=""

$topics = @{ names = @('dotnet', 'stem') } | ConvertTo-Json
$topics | gh api repos/<luca-user>/<repo-name>/topics -X PUT --input -
```

## Step 8: Mirror workflow setup (STEM work repos only)

Per the `dual-remote` rule:

1. Generate the deploy key: `ssh-keygen -t ed25519 -C "github-actions-mirror@<repo>" -f $HOME\.ssh\bb_mirror -N '""'`.
2. Register the public key on Bitbucket (Repo settings → Access keys, write enabled).
3. Register the private key as `BITBUCKET_SSH_KEY` Actions secret: `cat ~/.ssh/bb_mirror | gh secret set BITBUCKET_SSH_KEY --repo <luca-user>/<repo>`.
4. The mirror workflow itself ships with the v1 templates — `.github/workflows/mirror-bitbucket.yml`. Edit `{{Repo}}` substitution if your project name differs from the GitHub repo slug.

## Step 9: Speckit (optional)

If using Spec-Driven Development, initialize spec-kit:

```powershell
specify init --here --ai claude --script sh --offline --ignore-agent-tools
# Remove per-project speckit copies (we have them globally)
Remove-Item -Recurse -Force .claude/commands/speckit.*.md -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .claude/skills/speckit-*     -ErrorAction SilentlyContinue
Remove-Item -Force .claude/commands, .claude/skills, .claude -ErrorAction SilentlyContinue
```

Fill `.specify/memory/constitution.md` — see the `speckit` skill.

## Step 10: First feature PR

Open a PR for the bootstrap branch. CI on `main` doesn't exist yet, but the PR-triggered run on the bootstrap branch will be the first green run. After that's green, configure required status checks (Step 5) and merge.

```powershell
git push -u github chore/v1-bootstrap
gh pr create --title "chore: bootstrap v1 standards" --body "Applies llm-settings v1.0.0 standards via apply-repo-standard.ps1." --label chore
```

## Step 11: Update `state/repos.md`

Once merged, record the adoption in `<llm-settings>/state/repos.md` (Standard version + Last bumped date). Open a small PR there.

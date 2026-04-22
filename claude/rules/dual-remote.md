# Dual-remote workflow (GitHub primary, Bitbucket mirror)

Every STEM work repo has two remotes. Same SSH key on both.

- **`github`** — Luca's private GitHub. Active remote: PRs, Actions CI, issues, Artifacts, project board. This is where development actually happens.
- **`bitbucket`** — STEM's team Bitbucket. Mirror only. Colleagues and work admin read from here.

**Exception:** `llm-settings` itself is GitHub-only. No Bitbucket mirror.

## Remote setup for a new repo

```powershell
# After git init (or after cloning from wherever the team keeps the seed)
git remote add github    git@github.com:<luca-user>/<repo>.git
git remote add bitbucket git@bitbucket.org:stem-fw/<repo>.git

# Make 'github' the default push target
git config --global push.default current
git push -u github main
```

## Pushing to both with one command

Use a compound pushurl on the `github` remote so `git push github` hits both:

```powershell
git remote set-url --add --push github git@github.com:<luca-user>/<repo>.git
git remote set-url --add --push github git@bitbucket.org:stem-fw/<repo>.git
# Verify:
git remote -v
```

After this `git push github <branch>` pushes to both hosts. For fetching, `github` still pulls only from GitHub (fetchurl unchanged).

Alternative (explicit): keep remotes separate and alias a helper:

```powershell
git config alias.pushall '!git push github $1 && git push bitbucket $1'
# usage: git pushall feat/my-branch
```

## PR / CI rules

- Open PRs on **GitHub** (via `gh pr create`). Never on Bitbucket.
- CI of record runs on **GitHub Actions**. Keep `.github/workflows/*.yml` green.
- `bitbucket-pipelines.yml` should exist (the team expects it) but can be a minimal build-only stub. Sync it whenever .NET versions or major dependencies change.
- Issues live on **GitHub**. The `new-ticket` skill targets GitHub only.

## When things drift

If GitHub and Bitbucket branches diverge (rare — usually a direct team push to Bitbucket):

```powershell
git fetch github
git fetch bitbucket
git log github/main..bitbucket/main  # inspect differences
# Usually: rebase GitHub branch onto Bitbucket, then push to both.
```

**Why this setup:** GitHub-only tooling (Actions marketplace, Copilot, Projects v2, gh CLI, this llm-settings workflow) is the productive side. Bitbucket visibility is a team requirement, not a development need. The mirror pushurl keeps both honest with zero cognitive overhead.

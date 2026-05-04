---
name: "bitbucket-pipelines"
description: "Maintain bitbucket-pipelines.yml (build-only stub) so the team's Bitbucket view shows green on the mirrored main."
---

# Bitbucket Pipelines

Every STEM work repo has two CI systems:

- **GitHub Actions** (`.github/workflows/ci.yml`) — the **real** CI; blocks PR merges. See the `github-actions` skill.
- **Bitbucket Pipelines** (`bitbucket-pipelines.yml`) — **build-only stub** that keeps the Bitbucket side green on the mirrored `main`. No tests, no matrix.

The v1 templates ship a minimal stub at `shared/templates/bitbucket-pipelines.yml`. The rollout script copies it on bootstrap.

## Why a stub, not a mirror of GitHub Actions

- **Audience is read-only.** Colleagues on Bitbucket need to see the repo builds. They don't run their own PR flow there.
- **Bitbucket Linux runners can't build Windows-only projects** without `EnableWindowsTargeting`. Even with it, a full mirror of CI duplicates work that already runs on GitHub.
- **Drift is the enemy.** A complex Bitbucket pipeline that has to track GitHub's matrix logic is a maintenance trap.

Keep the file simple. The contract is: *if the repo builds, Bitbucket shows green.*

## The stub

```yaml
image: mcr.microsoft.com/dotnet/sdk:10.0

pipelines:
  default:
    - step:
        name: Build
        caches:
          - dotnetcore
        script:
          - dotnet build --configuration Release

definitions:
  caches:
    dotnetcore: ~/.nuget/packages
```

That's the whole file. Bump the `image:` tag whenever `global.json` changes the .NET SDK major version.

## When to update the stub

- **`global.json` changes the .NET SDK major.** Update `image: mcr.microsoft.com/dotnet/sdk:NN.0`.
- **Build flag changes that block compilation cross-platform.** Mirror the flag here. (Rare under v1 — Windows-only code lives in conditional driver projects.)
- **A new repo-specific build step that's required for `dotnet build` to succeed.** Add the minimum needed.

Don't add tests, matrices, artifact uploads, or cache layering — those belong on GitHub Actions.

## Schema reference (when you do need to edit)

| Concept | GitHub Actions | Bitbucket Pipelines |
| --- | --- | --- |
| Triggers | `on: [push, pull_request]` | `pipelines.default` / `branches` / `pull-requests` |
| Runner | `runs-on: ubuntu-latest` | `image:` (Docker image used for all steps) |
| Cache | `actions/cache@v4` | `caches:` definition + `caches:` on step |
| Secrets | `secrets.NAME` | Repository Variables (web UI) |
| Artifacts | `actions/upload-artifact@v4` | `artifacts:` list on step |
| Matrix | `strategy.matrix` | `parallel:` with duplicated steps |
| Concurrency cancel | `concurrency.cancel-in-progress: true` | No native equivalent — last run wins |

## Common pitfalls

- **`image: mcr.microsoft.com/dotnet/sdk:latest`** — don't. Pin the major version. `latest` can silently bump and break builds.
- **Cache never hitting** — `~/.nuget/packages` is correct for the Microsoft SDK image. Don't move it.
- **Direct push to `bitbucket`** — should fail because of the `no_push` placeholder set by `dual-remote.md`. If a colleague accidentally bypassed it, the mirror workflow will reconcile on the next push to `main`.

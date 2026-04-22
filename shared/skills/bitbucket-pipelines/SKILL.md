---
name: "bitbucket-pipelines"
description: "Write or update bitbucket-pipelines.yml for .NET 10 projects. Mirrors the GitHub Actions CI so the Bitbucket side stays green for colleagues."
---

# Bitbucket Pipelines

Every STEM work repo has two CI systems:

- **GitHub Actions** (`.github/workflows/ci.yml`) — the **real** CI, blocks PR merges.
- **Bitbucket Pipelines** (`bitbucket-pipelines.yml`) — mirror CI so colleagues see green builds on the Bitbucket side.

**Rule:** When a change lands on GitHub Actions (new .NET version, new test, new CI step), mirror the essential parts into `bitbucket-pipelines.yml` in the same commit. Don't let them drift.

## Schema basics

Bitbucket Pipelines uses YAML but with a different schema from GH Actions:

```yaml
image: mcr.microsoft.com/dotnet/sdk:10.0

definitions:
  caches:
    nuget: ~/.nuget/packages
  steps:
    - step: &build-and-test
        name: Build & Test
        caches:
          - nuget
        script:
          - dotnet restore <Repo>.slnx
          - dotnet build <Repo>.slnx -c Release -p:EnableWindowsTargeting=true
          - dotnet test Tests/Tests.csproj --framework net10.0 -c Release --no-build --logger "trx;LogFileName=test-results.trx" --results-directory ./test-results
        artifacts:
          - test-results/**

pipelines:
  default:
    - step: *build-and-test
  branches:
    main:
      - step: *build-and-test
  pull-requests:
    '**':
      - step: *build-and-test
```

## Key differences vs GitHub Actions

| Concept            | GitHub Actions                          | Bitbucket Pipelines                       |
| ------------------ | --------------------------------------- | ----------------------------------------- |
| Triggers           | `on: [push, pull_request]`              | `pipelines.default` / `branches` / `pull-requests` |
| Runner             | `runs-on: ubuntu-latest`                | `image:` (Docker image used for all steps)|
| Cache              | `actions/cache@v4`                      | `caches:` definition + `caches:` on step  |
| Secrets            | `secrets.NAME`                          | Repository Variables (web UI)             |
| Artifacts          | `actions/upload-artifact@v4`            | `artifacts:` list on step                 |
| Matrix             | `strategy.matrix`                       | `parallel:` with duplicated steps         |
| Concurrency cancel | `concurrency.cancel-in-progress: true`  | No native equivalent — last run wins      |
| Conditions         | `if:`                                   | `condition:` (limited — path-based only)  |
| Services           | `services:` (Docker)                    | `services:` definition + `services:` on step |

## Writing a pipeline from scratch

Start from the template above and adjust:

1. **`image:`** — match the .NET SDK version. Use the Microsoft-official image tag, not `latest`.
2. **`caches:`** — always cache NuGet. Invalidates on cache-key change; Bitbucket uses the referenced path.
3. **`script:`** — mirror the GH Actions steps. Same dotnet commands, same flags.
4. **`artifacts:`** — upload test results (`.trx`) and any build outputs you'd inspect offline.
5. **Pipeline sections:**
   - `default:` — runs on every push to any branch without a more specific rule.
   - `branches: main:` — runs on pushes to main.
   - `pull-requests: '**':` — runs on any PR. Use this as the primary check.

## YAML anchors (reuse)

Bitbucket supports YAML anchors (`&name` / `*name`). Define one step in `definitions.steps` and reference it everywhere to avoid drift:

```yaml
definitions:
  steps:
    - step: &ci-build
        name: CI
        # ...

pipelines:
  default:
    - step: *ci-build
  pull-requests:
    '**':
      - step: *ci-build
```

## Secrets / repository variables

Set via Bitbucket web UI → Repository settings → Repository variables. Reference as `$NAME` in scripts (shell-style, not `${{ ... }}`):

```yaml
script:
  - dotnet nuget add source "$AZURE_ARTIFACTS_URL" --name stem-azure --username luca --password "$AZURE_ARTIFACTS_PAT" --store-password-in-clear-text
```

Mark secrets as "Secured" — they're masked in logs.

## Windows-only targets

Bitbucket's shared runners are Linux. Windows-specific projects (`net10.0-windows`) can't be built on them without `-p:EnableWindowsTargeting=true`. Same flag as GitHub Actions.

If you truly need a Windows runner, it's a paid feature — avoid unless required. Mostly you can build the cross-platform subset (`net10.0`) on Linux and rely on local/CI-on-GH for Windows.

## Starter `bitbucket-pipelines.yml` for a STEM repo

```yaml
# bitbucket-pipelines.yml
#
# Mirror CI — the real CI lives on GitHub Actions (.github/workflows/ci.yml).
# This file keeps Bitbucket green for colleagues. Keep it in sync with
# .github/workflows/ci.yml whenever the .NET version or test steps change.

image: mcr.microsoft.com/dotnet/sdk:10.0

definitions:
  caches:
    nuget: ~/.nuget/packages
  steps:
    - step: &build-and-test
        name: Build & Test (net10.0 cross-platform)
        caches:
          - nuget
        script:
          - dotnet restore <Repo>.slnx
          - dotnet build <Repo>.slnx -c Release -p:EnableWindowsTargeting=true
          - >-
            dotnet test Tests/Tests.csproj
            --framework net10.0
            -c Release
            --no-build
            --logger "trx;LogFileName=test-results.trx"
            --results-directory ./test-results
        artifacts:
          - test-results/**

pipelines:
  default:
    - step: *build-and-test
  branches:
    main:
      - step: *build-and-test
  pull-requests:
    '**':
      - step: *build-and-test
```

## Common pitfalls

- **`image: mcr.microsoft.com/dotnet/sdk:latest`** — don't. Pin the major version. `latest` can silently bump to `.NET 11` and break builds.
- **Missing `-p:EnableWindowsTargeting=true`** — first visible symptom is `PlatformNotSupportedException` or WPF SDK errors during build.
- **Artifacts not uploading** — check the pattern under `artifacts:`; it's relative to the clone root.
- **Cache never hitting** — Bitbucket caches are keyed by path. If you see "Starting from empty cache" every run, the path may be wrong for the image's layout. `~/.nuget/packages` is correct for the Microsoft SDK image.

## When to update

Update `bitbucket-pipelines.yml` when:
- `.github/workflows/ci.yml` gets a new `dotnet` command or flag.
- .NET SDK major version bumps.
- A new test project is added.
- A new secret/env var becomes required for CI.

Don't update it for GitHub-Actions-specific features (matrix, deployment, artifact retention) — those don't translate.

---
name: "github-actions"
description: "Write .NET GitHub Actions workflows: dotnet build + xUnit tests, NuGet cache, dual-TFM matrix, artifact publish, concurrency."
---

# GitHub Actions for .NET

Primary CI for Luca's work. Active on the `github` remote. Triggers on push to main and on PRs.

## Directory & filename conventions

```
.github/
├── workflows/
│   ├── ci.yml         # main CI — build + test on PR and push
│   ├── release.yml    # triggered by version tag
│   └── publish.yml    # pushes NuGet to Azure Artifacts (if applicable)
```

One workflow per file. Filename matches the top-level `name:`.

## ci.yml template (STEM .NET 10)

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

env:
  DOTNET_NOLOGO: true
  DOTNET_CLI_TELEMETRY_OPTOUT: true
  NUGET_PACKAGES: ${{ github.workspace }}/.nuget/packages

jobs:
  build-gate:
    name: Build Gate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.0.x'

      - name: Cache NuGet
        uses: actions/cache@v4
        with:
          path: ${{ env.NUGET_PACKAGES }}
          key:  nuget-${{ runner.os }}-${{ hashFiles('**/*.csproj', '**/Directory.Packages.props') }}
          restore-keys: nuget-${{ runner.os }}-

      - name: Restore
        run: dotnet restore <Repo>.slnx

      - name: Build (Release, cross-platform subset)
        run: dotnet build <Repo>.slnx -c Release --no-restore -p:EnableWindowsTargeting=true

      - name: Test (net10.0 only — cross-platform)
        run: >
          dotnet test Tests/Tests.csproj
          --framework net10.0
          -c Release
          --no-build
          --logger "trx;LogFileName=test-results.trx"
          --results-directory ./test-results

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: ./test-results/
```

Adjust `<Repo>.slnx` and the `dotnet-version` if the target changes.

## Required status check

Name the job `Build Gate` and reference it from the branch protection ruleset (see `new-repository` skill). Every PR must have this check green before merge.

## Release workflow

Triggered by a version tag push (`v2.15.0`). Builds, runs tests, creates a GitHub Release, uploads build artifacts.

```yaml
name: Release

on:
  push:
    tags: ['v*.*.*']

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.0.x'
      - run: dotnet build <Repo>.slnx -c Release -p:EnableWindowsTargeting=true
      - run: dotnet test Tests/Tests.csproj --framework net10.0 -c Release --no-build
      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh release create ${{ github.ref_name }} \
            --generate-notes \
            ./path/to/build/output/*.zip
```

## NuGet publish to Azure Artifacts

If the repo ships a package:

```yaml
name: Publish

on:
  release:
    types: [published]

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.0.x'

      - name: Setup Azure Artifacts source
        run: |
          dotnet nuget add source "${{ secrets.AZURE_ARTIFACTS_URL }}" \
            --name stem-azure \
            --username luca \
            --password "${{ secrets.AZURE_ARTIFACTS_PAT }}" \
            --store-password-in-clear-text

      - name: Pack
        run: dotnet pack <Project>/<Project>.csproj -c Release -o ./pkg

      - name: Push
        run: dotnet nuget push "./pkg/*.nupkg" --source stem-azure --api-key az --skip-duplicate
```

Secrets needed: `AZURE_ARTIFACTS_URL`, `AZURE_ARTIFACTS_PAT`.

## Conventions

- **Always set `concurrency`** with `cancel-in-progress: true` so stale runs are killed when new commits land.
- **Set `permissions:` explicitly** per workflow (default to `contents: read`; grant `contents: write` only when releases/tags are involved).
- **Use `actions/setup-dotnet@v4`**, not older versions. Pin to `10.0.x` (wildcard minor).
- **Use `actions/cache@v4`** for NuGet restore; key off hash of `.csproj` files.
- **Use `-p:EnableWindowsTargeting=true`** whenever you build a `.slnx` that contains `net10.0-windows` projects on a Linux runner.
- **Don't run `net10.0-windows` tests on Linux** — they fail. Filter by framework: `--framework net10.0`.
- **Upload test results as an artifact** even on failure (`if: always()`), so you can download the `.trx` and inspect offline.
- **Never hard-code secrets.** Use `${{ secrets.NAME }}` and set them via `gh secret set NAME --body "..."`.

## Triggering on both GitHub and Bitbucket

The dual-remote mirror push (see `dual-remote` rule) means the same commits land on Bitbucket too. Keep `bitbucket-pipelines.yml` minimal / independent — don't try to mirror this file's logic there. Bitbucket Pipelines runs on a different schema; see the `bitbucket-pipelines` skill.

## Troubleshooting

- **`The process '/usr/bin/dotnet' failed with exit code 1`** — check the log, usually a missing `-p:EnableWindowsTargeting=true`.
- **`EnableWindowsTargeting` didn't help** — some packages (OxyPlot.WindowsForms, Plugin.BLE) can't restore on Linux. Move them to a `net10.0-windows`-only project and split the solution build into two jobs.
- **Stuck on old workflow** — GH only runs PR-triggered workflows if the workflow file exists on the default branch. Push the workflow to main first.
- **Test failures differ locally vs CI** — usually a nullable-reference-warning promoted to error only in Release config. Run `dotnet build -c Release` locally to catch.

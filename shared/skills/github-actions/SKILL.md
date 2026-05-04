---
name: "github-actions"
description: "Edit .NET GitHub Actions workflows in STEM repos: ci, mirror-bitbucket, release. Templates ship with the v1 standards."
---

# GitHub Actions for .NET

Primary CI for Luca's work. Active on the `github` remote. The v1 standards ship the canonical workflows under `shared/templates/.github/workflows/`; the rollout script copies them into each repo. **Don't write a workflow from scratch — start from the template** and adjust per-repo.

## Workflows shipped per repo

| Workflow | Source template | Trigger |
| --- | --- | --- |
| `.github/workflows/ci.yml` | `shared/templates/.github/workflows/ci.yml` | push, PR, dispatch, weekly cron |
| `.github/workflows/mirror-bitbucket.yml` | `shared/templates/.github/workflows/mirror-bitbucket.yml` | push to `main` |
| `.github/workflows/release.yml` (A) | `shared/templates/archetypes/A/.github/workflows/release.yml` | tag `v*.*.*` (zip self-contained) |
| `.github/workflows/release.yml` (B) | `shared/templates/archetypes/B/.github/workflows/release.yml` | tag `v*.*.*` (NuGet to GitHub Packages) |

The CI standard (`docs/Standards/CI.md` inside a work repo, or `shared/standards/CI.md` upstream) describes the contract: matrix `[ubuntu-latest, windows-latest]`, format check as a hard gate, conditional Linux/Windows build+test legs, NuGet + Lean cache, `dorny/test-reporter` for TRX surfacing.

## Required status checks

For branch protection, point the rule at the matrix job names:

```jsonc
"required_status_checks": [
  { "context": "build (ubuntu-latest)" },
  { "context": "build (windows-latest)" }
]
```

(See the `new-repository` skill for the full ruleset payload.)

## Editing a workflow in an adopted repo

If you need a per-repo deviation from the template:

1. Make the change in the work repo's `.github/workflows/` file.
2. If the deviation is durable and applicable to other STEM repos, propose pulling it back into `shared/templates/` so future repos get it. The `promote-to-llm-settings` rule handles this.
3. If the deviation is repo-specific (e.g. the repo needs a Selenium service container), don't try to push it upstream — note it in the repo's `CLAUDE.md` "Repo-specific notes" section.

The rollout script overwrites `.github/workflows/*.yml` on bump. Repo-specific edits get clobbered. Either upstream the change or be ready to re-apply it after every bump.

## Conventions

- **Always set `concurrency`** with `cancel-in-progress: true`. The templates do this.
- **Set `permissions:` explicitly** per workflow (default `contents: read`; grant `contents: write` only when releases/tags are involved; `packages: write` for archetype B's release).
- **Use `actions/setup-dotnet@v4`** with `global-json-file: global.json`. Don't pin `dotnet-version:` directly.
- **Use `actions/cache@v4`** for NuGet restore; key off `Directory.Packages.props` hash (the template does this).
- **Use multi-TFM legs conditionally** — Linux runs `--framework net10.0`; Windows runs unrestricted.
- **Don't run `net10.0-windows` tests on Linux** — the template's conditional steps handle this.
- **Upload test results** even on failure (`if: always()`). The template uses `dorny/test-reporter@v1` for inline PR-check rendering.
- **Never hard-code secrets.** Use `${{ secrets.NAME }}` and set them via `gh secret set NAME --body "..."`.

## NuGet publish — archetype B (GitHub Packages)

The archetype B release template publishes to **GitHub Packages**, not Azure Artifacts. Authenticated via `GITHUB_TOKEN` (no extra setup). For legacy repos still publishing to Azure Artifacts, see the `dotnet` skill's NuGet section — the secret/PAT setup remains valid until those packages migrate.

## Troubleshooting

- **`The process '/usr/bin/dotnet' failed with exit code 1`** — usually a missing TFM filter on Linux. Confirm the template's `if: runner.os == 'Linux'` conditional is in place on the build/test steps.
- **`EnableWindowsTargeting` errors** — only needed for solutions that build legacy WinForms/WPF projects on Linux. v1-adopted repos shouldn't need this; if they do, a project is leaking Windows code into a non-driver layer (see PORTABILITY).
- **First PR-triggered run never starts** — GitHub only runs PR-triggered workflows if the workflow file already exists on the default branch. The bootstrap PR adds the workflow files, so the first run happens **on the bootstrap PR's branch** before merge.
- **Stuck on old workflow content** — clear the runner cache (settings → Actions → caches) if a stale `Directory.Packages.props` hash makes restore reuse a broken cache.
- **Mirror workflow fails with "error in libcrypto"** — the `BITBUCKET_SSH_KEY` secret was set via a PowerShell pipe (line-ending conversion). Re-set it from bash: `cat ~/.ssh/bb_mirror | gh secret set BITBUCKET_SSH_KEY --repo <owner>/<repo>`.

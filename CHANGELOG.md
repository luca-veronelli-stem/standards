# Changelog

All notable changes to `llm-settings` follow [Semantic Versioning](https://semver.org/) and are recorded here in [Keep a Changelog](https://keepachangelog.com/) format.

Each STEM repo declares the **Standard version** it follows in its top-level `CLAUDE.md`. `state/repos.md` mirrors those declarations so a single glance shows which repos lag.

## Versioning rules for `llm-settings`

- **Major** — breaking change to a standard, template, rule, skill, or installer that forces adopters to migrate or pin an older version.
- **Minor** — new standard, new template, new rule, new skill, new installer capability, or a non-breaking change to an existing one.
- **Patch** — bug fixes that restore intended behaviour, plus typos, clarifications, and internal refactors. No change to documented contracts.

The version number is the git tag (`v1.0.0`, `v1.1.0`, …). There is no version field inside any single file — `git describe` is the source of truth.

## [Unreleased]

### Fixed
- `eng/apply-repo-standard.ps1`: the skip-local-edits guard no longer silently clobbers customised files when the `.stem-standard.lock` is missing entries for them. Two defects converged on the same boolean short-circuit at the lock-baseline check: (1) when a file existed on disk but had no entry in `lock.files`, the guard fell through to "write" instead of skipping; (2) standards files were keyed by bare filename in the lock map but looked up by `docs/Standards/<NAME>.md`, so the lookup always missed and inherited defect (1). Hit on the v1.2.1 → v1.3.0 bump on `stem-button-panel-tester`, where it overwrote `CLAUDE.md`, `README.md`, `Directory.Packages.props`, and both GitHub workflows — regressing action versions and removing test-filter expressions, dependency pins, and per-repo entries. The fix treats a missing lock entry on an existing target as locally-modified (skip with the standard `(local edit; pass -Force to overwrite)` warning) and routes the standards loop through `Invoke-TemplateFile` with `-DestRoot $repoFull -DestRelativePrefix 'docs/Standards/'` so lock keys are uniform. `shared/standards/MIGRATION.md` got a new Pitfalls section flagging that the first post-`v1.3.1` run on a pre-fix lockfile will skip the previously-unprotected files until the user inspects the diff and re-runs with `-Force` to seed the missing entries. Closes #42.

## [1.3.0] - 2026-05-06

### Added
- `shared/templates/LICENSE.template` — STEM proprietary-EULA template parameterized on `{{App}}`, `{{Year}}`, `{{Author}}`. Wired into `apply-repo-standard.ps1` as a **bootstrap-only** file (alongside `CHANGELOG.md`), so first-time rollouts seed it but re-runs never overwrite per-repo customisations. Lifted from the `stem-communication` LICENSE body, which had been copy-pasted (with a "DUMMY" disclaimer header) into every other STEM repo. The disclaimer is dropped here; the body is unchanged.
- `shared/skills/pr/SKILL.md`: new "Stacked PRs — base-branch deletion trap" section documenting the failure mode where merging the foundation of a stack with `--delete-branch` auto-closes every dependent PR (and closed PRs whose base is gone cannot be reopened). Covers pre-merge defence (retarget dependents to `main`), recovery (recreate against `main`, cross-link the old PR), and local cleanup after each rebase-merge. Hit during the `feat/001-dictionary-from-api` 5-PR merge train on `stem-button-panel-tester`. Closes #35.
- `shared/standards/MIGRATION.md`: new Anti-patterns entry warning against hardcoding the Standard version inside `.specify/memory/constitution.md` (or any other speckit artefact). The rollout script's ownership ends at `docs/Standards/` + `CLAUDE.md`/`README.md` templates and does not rewrite `.specify/`, so a literal version pinned in the constitution silently goes stale on every bump. Authors should reference the version indirectly via the `**Standard version:**` line in the repo's top-level `CLAUDE.md`. Includes ✅/❌ wording examples. Closes #37.

### Changed
- CI template (`shared/templates/.github/workflows/ci.yml`) and CI standard (`shared/standards/CI.md`): the default formatting gate is now `dotnet format whitespace --verify-no-changes --no-restore`, not the full `dotnet format`. The full variant fails on GitHub-hosted runners with `CS0246` on cross-language refs (C# → F#) during the analyzer phase, even after a successful build — Roslyn's `MSBuildWorkspace` doesn't fully resolve cross-language refs on those images. The same command passes locally. Analyzer/style enforcement still happens via the build's `TreatWarningsAsErrors`, so the whitespace check is sufficient at the CI gate. Husky.NET pre-commit keeps running the full check locally, where the gap doesn't manifest. `shared/standards/BUILD_CONFIG.md`'s "Build invariants (CI enforces these)" snippet was updated to match. `shared/skills/dotnet/SKILL.md` got a Troubleshooting entry pointing at the new gate. Revisit when .NET SDK 11 / Roslyn ship; if `MSBuildWorkspace` gains full cross-language resolution on the hosted runners, restore the full check. Closes #36.

## [1.2.1] - 2026-05-06

### Fixed
- `shared/templates/README.md.template` and `shared/templates/CLAUDE.md.template`: render-visible placeholder hints (`(1–3 paragraphs: ...)` and similar) shipped unfilled into adopted repos because they look like prose to a casual reader. Replaced with explicit `*[TODO — ...]*` markers backed by HTML-comment guidance, matching the convention already used in `docs/README_TEMPLATE.md`, `docs/STANDARD_TEMPLATE.md`, and `archetypes/B/docs/API_SURFACE.md`. The `PULL_REQUEST_TEMPLATE.md` `Summary` placeholder is left as-is — it's overwritten on every PR creation.
- `state/repos.md`: retitled the "Pending adoption" section from `v1.2.0` to `v1.2.1` so repos picking up the standards bundle adopt the patched templates directly.

## [1.2.0] - 2026-05-05

### Added
- Eight new standards under `shared/standards/`, promoted from `stem-communication`'s legacy `Docs/Standards/` and genericized for cross-repo use: `EVENTARGS`, `VISIBILITY`, `LOGGING`, `THREAD_SAFETY`, `CANCELLATION`, `COMMENTS`, `ERROR_HANDLING`, `CONFIGURATION`. Each is English-native, drops the rule-code bureaucracy (TS-001, EA-001, …), and is archetype-aware (different rules for libraries vs apps where the data justified it). The `COMMENTS` standard explicitly drops the legacy "Italian for All" principle in favor of the CLAUDE.md English-by-default rule. The `CONFIGURATION` standard renames "Layer" to "Service / Component" so apps and libraries both adopt the fail-fast validation pattern. The `ERROR_HANDLING` standard is genericized away from `LayerResult` and per-layer error-code prefixes. Closes part of #20.
- `shared/templates/docs/STANDARD_TEMPLATE.md` — meta-template for authoring future standards. Matches the v1.0/v1.2.0 house style (stability+principle blockquote, prose-driven sections, no rule codes, no severity markers).
- `shared/templates/docs/README_TEMPLATE.md` — per-component README template. Stripped of OSI/protocol-Layer content; covers any project/component with required/optional/B-only sections.
- `shared/templates/archetypes/B/docs/API_SURFACE.md` — library API surface template (archetype B only). Apps don't have a public surface.

### Changed
- `eng/apply-repo-standard.ps1` now tracks per-file SHA256 of last-written content in `.stem-standard.lock` and refuses to overwrite files that have been modified since the previous rollout (override with `-Force`). Re-running at the same Standard version is a true no-op when the work repo is unchanged. `CHANGELOG.md` is treated as bootstrap-only and never overwritten on re-run. New `-Minimal` switch scopes the iteration to template/standard files that changed between the locked source tag and the target tag (`git diff <source>..<target> -- shared/templates shared/standards`); files containing `{{StandardVersion}}` always re-render. `-DryRun` now prints unified diffs (via `git diff --no-index`) instead of a path list. Output is line-ending-normalized to LF on write so `core.autocrlf=true` checkouts no longer produce spurious diffs on re-run. Closes #27.

### Fixed
- `claude/rules/dual-remote.md`: rewrote the mirror-workflow setup. Bitbucket Cloud access keys are read-only, so the previous "enable Has write access" instruction couldn't be followed (the toggle no longer exists in the UI; the first mirror push fails with `fatal: Could not read from remote repository.`). The new flow registers a single shared SSH key (`~/.ssh/bb_mirror_shared`) on the Bitbucket user profile and reuses it across all mirror repos via per-repo `BITBUCKET_SSH_KEY` secrets. Added a Cleanup section for migrating from the old per-repo `bb_mirror_<repo>` keys. The workflow YAML itself is unchanged. Closes #25.

## [1.1.1] - 2026-05-05

### Fixed
- CI template (`shared/templates/.github/workflows/ci.yml`): dropped `--framework net10.0` from the Linux build leg. `--framework` overrides per-project TFMs and broke on repos with legacy WinForms/WPF (`net10.0-windows`) projects. The cross-platform contract is now enforced by the Linux **test** leg plus the MIGRATION tracker; `shared/standards/PORTABILITY.md`'s "Verifying portability" snippet was updated to match. Closes #22.
- CI template: narrowed `on.push.branches` from `["**"]` to `[main]`, eliminating the double-trigger that fired CI twice on every PR-branch commit (push + pull_request triggers couldn't be deduped via `concurrency.group` because `github.ref` differs per trigger).

## [1.1.0] - 2026-05-05

### Added
- `install.ps1` configures `gpg.program` and `core.sshCommand` to point at the Windows-native binaries (`C:\Program Files\GnuPG\bin\gpg.exe`, `C:\Windows\System32\OpenSSH\ssh.exe`) when present, so signed commits and SSH push work out of the box on a fresh STEM machine without needing to override the `Git\usr\bin\` bundled tools by hand. Idempotent and respects user-set non-bundled values. Closes #13.

### Changed
- Applied the conventional-commits label set (`feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`) to this repo, matching the vocabulary the `new-repository` skill installs on STEM work repos. Existing issues #13 and PRs #11 / #12 were retroactively labelled. Closes #14.
- Renamed every reference to the `stem-dictionaries` repo to its actual GitHub name `stem-dictionaries-manager` across `state/repos.md`, `shared/standards/MIGRATION.md`, and `shared/standards/REPO_STRUCTURE.md`. Closes #16.

## [1.0.1] - 2026-05-05

### Fixed
- `install.ps1` now falls back to `cmd /c mklink` when `New-Item -ItemType SymbolicLink` rejects the call due to a missing `SeCreateSymbolicLinkPrivilege`. Unblocks installation on STEM domain-joined machines, where group policy strips the privilege from standard accounts even with Developer Mode enabled.

### Changed
- Tightened the patch-bump rule in this changelog: bug fixes that restore intended behaviour are now explicitly patch-level. Previous wording ("no behavioural impact") excluded them by accident.

## [1.0.0] - 2026-05-04

### Added
- First cut of the v1 standards bundle. Lands the eight cross-repo standards drafted in the *standards-definition* design session (REPO_STRUCTURE, LANGUAGE, MODULE_SEPARATION, PORTABILITY, BUILD_CONFIG, TESTING, CI, MIGRATION).
- Templates under `shared/templates/` for archetype A (desktop app), B (library), C (meta/config). Cover `Directory.Build.props`, `Directory.Packages.props`, `global.json`, `.editorconfig`, `.gitignore`, `.gitattributes`, GitHub workflows (`ci`, `mirror-bitbucket`, `release`), issue/PR templates, `CODEOWNERS`, `dependabot.yml`, `bitbucket-pipelines.yml` stub, `eng/install-hooks.{ps1,sh}`, `BannedSymbols.txt`.
- Rollout script `eng/apply-repo-standard.ps1` that bootstraps or bumps a STEM repo from the templates.
- New rule `claude/rules/stem-conventions.md`, path-scoped to adopted work repos.
- `state/repos.md` — adoption tracker.
- `CHANGELOG.md` — this file.

### Changed
- Skills updated to reference the v1 standards: `documentation`, `dotnet`, `new-repository`, `lean4`, `new-ticket`, `github-actions`, `bitbucket-pipelines`.
- `claude/CLAUDE.md` references the standards bundle and the per-repo Standard version declaration.
- `claude/rules/dotnet.md` defers structural questions (project shape, test layout) to the standards.
- `README.md` documents the standards table, the rollout flow, and the new files.

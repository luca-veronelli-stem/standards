# Changelog

All notable changes to `llm-settings` follow [Semantic Versioning](https://semver.org/) and are recorded here in [Keep a Changelog](https://keepachangelog.com/) format.

Each STEM repo declares the **Standard version** it follows in its top-level `CLAUDE.md`. `state/repos.md` mirrors those declarations so a single glance shows which repos lag.

## Versioning rules for `llm-settings`

- **Major** — breaking change to a standard, template, rule, skill, or installer that forces adopters to migrate or pin an older version.
- **Minor** — new standard, new template, new rule, new skill, new installer capability, or a non-breaking change to an existing one.
- **Patch** — bug fixes that restore intended behaviour, plus typos, clarifications, and internal refactors. No change to documented contracts.

The version number is the git tag (`v1.0.0`, `v1.1.0`, …). There is no version field inside any single file — `git describe` is the source of truth.

## [Unreleased]

### Added
- `install.ps1` configures `gpg.program` and `core.sshCommand` to point at the Windows-native binaries (`C:\Program Files\GnuPG\bin\gpg.exe`, `C:\Windows\System32\OpenSSH\ssh.exe`) when present, so signed commits and SSH push work out of the box on a fresh STEM machine without needing to override the `Git\usr\bin\` bundled tools by hand. Idempotent and respects user-set non-bundled values. Closes #13.

### Changed
- Applied the conventional-commits label set (`feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`) to this repo, matching the vocabulary the `new-repository` skill installs on STEM work repos. Existing issues #13 and PRs #11 / #12 were retroactively labelled. Closes #14.

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

# Changelog

All notable changes to `llm-settings` follow [Semantic Versioning](https://semver.org/) and are recorded here in [Keep a Changelog](https://keepachangelog.com/) format.

Each STEM repo declares the **Standard version** it follows in its top-level `CLAUDE.md`. `state/repos.md` mirrors those declarations so a single glance shows which repos lag.

## Versioning rules for `llm-settings`

- **Major** — breaking change to a standard or template (existing repos must migrate or pin an older version).
- **Minor** — new standard, new template, new skill, or non-breaking change to an existing one.
- **Patch** — typos, clarifications, internal refactors with no behavioural impact.

The version number is the git tag (`v1.0.0`, `v1.1.0`, …). There is no version field inside any single file — `git describe` is the source of truth.

## [Unreleased]

### Added
- First cut of the v1 standards bundle. Lands the eight cross-repo standards drafted in the *standards-definition* design session (REPO_STRUCTURE, LANGUAGE, MODULE_SEPARATION, PORTABILITY, BUILD_CONFIG, TESTING, CI, MIGRATION).
- Templates under `shared/templates/` for archetype A (desktop app), B (library), C (meta/config). Cover `Directory.Build.props`, `Directory.Packages.props`, `global.json`, `.editorconfig`, `.gitignore`, `.gitattributes`, GitHub workflows (`ci`, `mirror-bitbucket`, `release`), issue/PR templates, `CODEOWNERS`, `dependabot.yml`, `bitbucket-pipelines.yml` stub, `eng/install-hooks.{ps1,sh}`, `BannedSymbols.txt`.
- Rollout script `eng/apply-repo-standard.ps1` that bootstraps a STEM repo from the templates.
- New rule `claude/rules/stem-conventions.md` that points active sessions at the standards.
- `state/repos.md` — adoption tracker.
- `CHANGELOG.md` — this file.

### Changed
- Skills updated to reference the v1 standards: `documentation`, `dotnet`, `new-repository`, `lean4`, `new-ticket`, `github-actions`, `bitbucket-pipelines`, `speckit*`.
- `claude/CLAUDE.md` references the standards bundle and the per-repo Standard version declaration.
- `README.md` lists the new standards/templates table and the rollout flow.

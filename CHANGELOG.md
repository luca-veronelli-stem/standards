# Changelog

All notable changes to `standards` follow [Semantic Versioning](https://semver.org/) and are recorded here in [Keep a Changelog](https://keepachangelog.com/) format.

Each STEM repo declares the **Standard version** it follows in its top-level `CLAUDE.md`. `state/repos.md` mirrors those declarations so a single glance shows which repos lag.

## Versioning rules

- **Major** — breaking change to a standard or template that forces adopters to migrate or pin an older version.
- **Minor** — new standard or new template, or a non-breaking change to an existing one.
- **Patch** — bug fixes that restore intended behaviour, plus typos, clarifications, and internal refactors. No change to documented contracts.

The version number is the git tag (`v1.0.0`, `v1.1.0`, …). There is no version field inside any single file — `git describe` is the source of truth.

Historical entries from `v1.0.0` through `v1.3.3` were written while this repo was bundled with the agent-config under the name `llm-settings`. From this point forward `standards` is scoped to the STEM standards alone; the agent-config wiring lives in [`luca-veronelli-stem/llm-settings`](https://github.com/luca-veronelli-stem/llm-settings) (unversioned, HEAD-only).

## [Unreleased]

### Added
- New `GUI` standard at `shared/standards/GUI.md` codifying the Avalonia + FuncUI + Elmish-MVU dialect for archetype A apps. Pins the `<App>.GUI/` project layout (top-level `Model`/`Update`/`View`/`Strings`/`App`/`Program` + `Pages/`, `Components/`, `Composition/`, `Resources/` subfolders), the manual-DI composition-root pattern (`Composition/Bindings.fs`, no `Microsoft.Extensions.DependencyInjection` container inside the GUI), the pure-`Update` invariant with effects expressed as `Cmd<Msg>`, cancellation-aware long-running operations per [`CANCELLATION.md`](./shared/standards/CANCELLATION.md), and a three-layer test posture (FsCheck on `Update`, Avalonia.Headless smoke on `View`, wiring tests on `Bindings.buildDeps`). Includes the legacy `<App>.GUI.Windows` (WinForms/WPF) carve-out, matching the pattern [`LANGUAGE.md`](./shared/standards/LANGUAGE.md) already uses, so in-flight Avalonia migrations remain a documented state rather than a deviation.
- New `DESIGN_SYSTEM` standard at `shared/standards/DESIGN_SYSTEM.md` codifying the visual contract that pairs with `GUI`. Pins `Avalonia.Themes.Fluent` with light mode as the startup default (brand-aligned — the Stem brand manual is entirely light-canvas, so dark mode is called out as a software-only convention for engineer sessions / low-light bays), a 4-pt spacing scale (`Stem.<App>.GUI.Spacing`), `FluentIcons.Avalonia.Fluent` as the icon source, and an F# strings-module approach to localisation (typed `Lang` DU, compile-time completeness, no `.resx`, Italian default at runtime + English mandatory). Defines four error-and-progress surfaces (toast / banner / inline / modal) with an explicit decision tree, a shared `ErrorPayload` shape carrying `Lang -> string` functions so a mid-flight language switch re-renders correctly, and an accessibility floor (keyboard nav, focus indicator on, WCAG AA contrast, 44 × 44 px touch targets for production-floor workstations). Carries the full Stem corporate palette (Blu Stem `#004682` and its three sanctioned tints, the Cool Gray ramp `Gray10`–`Gray60`, `RossoAlert` `#E40032`) exposed as named `Brand.*` tokens — no hex literals in views — and a software-derived `Brand.Semantic` set (`Info` / `Success` / `Warning` / `Error`) whose Success and Warning are deliberately distinct from the EMS and Commercial Vehicles division colors to prevent semantic-vs-identity collision. Typography is Poppins exclusively (Google Fonts, SIL OFL — bundled in `Resources/fonts/`); the brand's Stem-Regular custom font is reserved for division wordmarks inside print brand marks and is not used in software. Adds a `Branding` module pattern that lets each app declare its target Stem division (`EMS`, `Commercial Vehicles`, `Marine`, `France`, or none) — the division identity color appears only as a badge next to the corporate brand mark and as a division-tagged row divider, never in chrome (chrome is always Blu Stem + Cool Gray). Bumps the standards count from sixteen to eighteen.

### Changed
- Repository flipped from private to public on GitHub. `MIGRATION.md`'s "Rollout phase for v1.4.0" no longer documents an "Actions access" prerequisite — public repos resolve cross-repo reusable-workflow `uses:` references without the `access_level=user` toggle. Adopter-facing wording stripped of "(private)" / "(private repo)" suffixes in `shared/templates/CLAUDE.md.template`, `eng/apply-repo-standard.ps1` (generated `docs/Standards/README.md` header), and `state/repos.md`. Inline-copy rationale in `REPO_STRUCTURE.md` updated: hyperlink-to-standards now resolves for Bitbucket-only colleagues, but inline copies still win on the grounds that matter (in-tree greppability, no browser round-trip, pinned to Standard version). No standard contracts change.

## [1.4.0] - 2026-05-12

### Added
- Reusable GitHub Actions workflows shipped from this repo at `.github/workflows/dotnet-ci.yml`, `mirror-bitbucket.yml`, `release-archetype-a.yml`, `release-archetype-b.yml`. Adopted repos now receive thin caller stubs that delegate the job body via `uses: luca-veronelli-stem/standards/.github/workflows/<workflow>.yml@<StandardVersion>`. Bumping a pin in the called workflow (e.g. `actions/setup-dotnet`, `dorny/test-reporter`) propagates to adopted repos on their next CI run without a per-repo PR — removing the recurring "bump pins in templates, then re-roll every adopted repo" wave that `v1.3.3` typified. The matching standards-repo CI checks (templates-parse, Pester smoke on the rollout) cover the stub shape so a malformed `with:` or a missing input fails here, not in an adopted repo. Closes #58.
- Standards-repo CI expanded beyond PSScriptAnalyzer to validate what this repo actually ships: every `shared/templates/**/*.{props,json,yml,yaml}` parses (placeholders substituted with safe dummies); every `shared/standards/<NAME>.md` carries the agreed `# Standard: <NAME>` + `> **Stability:** ...` header; the `$standardPurpose` registry in `eng/apply-repo-standard.ps1` cross-references the on-disk standards set in both directions; and a Pester smoke test drives the rollout end-to-end against a throwaway repo (config, lock, templates, archetype overlay, generated index, idempotency). The pre-split JSON-validity and skill-frontmatter checks (now dead weight after `llm-settings` extracted) are dropped. Each step carries a one-line "what this protects" comment. Closes #59.

### Changed
- Workflow templates shrink to caller stubs. `shared/templates/.github/workflows/ci.yml` is now ~25 lines (triggers + concurrency + permissions + one `uses:` line); `mirror-bitbucket.yml` similarly thin; `archetypes/{A,B}/.github/workflows/release.yml` shrink to stubs passing per-repo inputs (`app`, `repo`, `owner`, `tag`). On the v1.3.x → v1.4.0 bump the rollout replaces the full workflows with the stubs in any repo that hadn't hand-customised them; hand-customised repos hit the local-edit guard and need `-Force` or hand-merge (see `MIGRATION.md` → "Rollout phase for v1.4.0"). The reusable-workflow ref `@{{StandardVersion}}` is the existing `{{StandardVersion}}` placeholder; the rollout substitutes it at bump time, so adopted repos always reference the exact tag they're pinned to. Part of #58.
- Split the agent-config (`claude/`, `shared/skills/`, `shared/mcp/`, `install.ps1`, `PSScriptAnalyzerSettings.psd1`) into a sibling repo `luca-veronelli-stem/llm-settings`. This repo (formerly `luca-veronelli-stem/llm-settings`, renamed to `luca-veronelli-stem/standards`) is now scoped to the STEM cross-repo standards: docs, templates, rollout script, state tracker. Cross-references throughout the standards docs, templates, and `eng/apply-repo-standard.ps1` rewritten from `<llm-settings>/...` to `<standards>/...` (and to `this repo` where the context made the path self-referential). Inline copies in adopted repos pointed at the new upstream path on the next bump.
- Inlined the no-mocks rule into `TESTING.md` so the standard is self-contained; the previous "Per `dotnet.md`" delegation pointed at an agent-side rule that no longer ships with this repo.
- Dropped bare "v1" decoration in favour of either specific semver (`v1.3.3` when pinning) or "the standards" (generic reference). The major-version umbrella concept stays intact in `MIGRATION.md` for explaining v2 transitions.

### Fixed
- `shared/templates/Directory.Packages.props`: pinned `xunit` to `2.9.3` (was `2.9.4`, which doesn't exist on nuget.org — the highest published version is `2.9.3`). The bad pin landed in `v1.3.3`'s package-version sweep (#51) and made any clean `dotnet restore` on a v1.3.x adopted repo with the standard test stack fail with `NU1102: Unable to find package xunit with version (>= 2.9.4)`. Surfaced while bootstrapping the v1.4.0 reusable-workflow e2e fixture (#58). Closes #64.

## [1.3.3] - 2026-05-07

### Added
- `.github/dependabot.yml` for `llm-settings` itself, scoped to the `github-actions` ecosystem with minor/patch grouping. Majors stay individual so behaviour-changing bumps (e.g. the `dorny/test-reporter` v3 sink flip) get reviewed in isolation. NuGet is not enabled — `llm-settings` has no `.csproj`/`.fsproj` for Dependabot to walk; the `Directory.Packages.props` template is refreshed manually before each cut. `shared/standards/MIGRATION.md` got a new "Keeping the templates current" section codifying the mirror rule (GHA Dependabot PR here → fold the same bump into `shared/templates/**/*.yml`) and the manual NuGet refresh procedure. Closes #50.

### Changed
- Workflow templates: `actions/cache@v4 → v5`, `actions/setup-dotnet@v4 → v5`, `softprops/action-gh-release@v2 → v3`, `dorny/test-reporter@v1 → v3`. The `dorny/test-reporter` v3 default sink moved to `$GITHUB_STEP_SUMMARY`, which silently drops the per-OS Tests check at PR level (observed on `stem-dictionaries-manager#25`); pinned `use-actions-summary: 'false'` on the `ci.yml` step to keep the legacy Check Run sink so the gate still renders inline. Touches `shared/templates/.github/workflows/ci.yml` and `shared/templates/archetypes/{A,B}/.github/workflows/release.yml`. `shared/standards/CI.md` and the `github-actions` / `bitbucket-pipelines` skills' references were updated to match. Closes #49.
- `shared/templates/Directory.Packages.props`: bumped the Microsoft.* libs that had drifted off the `net10.0` target declared by `Directory.Build.props`. `Microsoft.Extensions.{DependencyInjection,Configuration,Configuration.Json,Options}`, `Microsoft.EntityFrameworkCore{,.Sqlite}`, and `System.IO.Ports` all moved from `9.0.1` to `10.0.7`. `FsCheck.Xunit` patch-bumped `3.3.0 → 3.3.3` within the current major. Avalonia `11.3.7 → 12.x` and `Microsoft.NET.Test.Sdk 17 → 18` are deliberately deferred — they are major bumps with non-trivial breakage risk on adopted repos and don't fit a patch release. The dictionary-of-deps surfaced by `stem-dictionaries-manager`'s v1.3.2 adoption (Hosting, OpenApi, HealthChecks, CommunityToolkit.Mvvm, Swashbuckle) live in *that* repo's own `Directory.Packages.props`, not in the template, so the cross-repo fix is in `state/repos.md` (#50's mirror rule) rather than this file. Closes #51.

### Fixed
- Aligned the per-component `README.md` adoption guidance with observed practice. The previous wording in `shared/standards/MIGRATION.md` (v1.2.0 step 2) and `state/repos.md` line 47 claimed the rollout script *"refreshes per-component README.md files using the new template"*, but `eng/apply-repo-standard.ps1` only ever handled the top-level `README.md` and `CLAUDE.md`; adopters quietly deleted the pre-v1 component READMEs (a snapshot lives on the `feat/legacy-docs-snapshot` branch — see `stem-button-panel-tester` commit `f0e69f0`, 2026-05-05). Both files now describe the de-facto flow: per-component READMEs are not regenerated automatically, pre-v1 ones are typically deleted after a salvage pass, and new ones are added selectively from `shared/templates/docs/README_TEMPLATE.md` only when a component genuinely earns its keep. `MIGRATION.md`'s v1.2.0 section also gains an explicit salvage checklist (cross-system context, domain semantics, `BR-*` references, external-system pointers) running alongside the existing ISSUES export step. `eng/apply-repo-standard.ps1` got a docstring note declaring per-component READMEs out of scope so future readers don't expect the script to touch them. Closes #52.

## [1.3.2] - 2026-05-07

### Changed
- `shared/standards/MIGRATION.md`: split the pre-`v1.3.1` lockfile pitfall bullet into two cases. Minor local divergence still gets a straight `-Force`; substantive local divergence (`Directory.Packages.props`, `.github/workflows/*.yml`, `CLAUDE.md`, `README.md` with repo-specific narrative) gets the seed-then-restore recipe — `-Force` to seed the lock with template hashes, immediate `git checkout HEAD -- <customised files>` to restore pre-bump content, then a hand-bump of version stamps. After that, `disk != lock` is the desired permanent state and future bumps auto-skip those files. Cross-links the `stem-button-panel-tester` v1.2.1 → v1.3.1 bump as the worked example. Closes #45.

## [1.3.1] - 2026-05-07

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

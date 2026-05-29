# Spec — Cover F#-specific shapes in cross-repo standards (#94)

Status: **draft, awaiting review at the `specs` phase.**
Release: a normal repo minor — **v1.12.0** (the next tag after `v1.11.0`).

## Versioning note (corrects the ticket's wording)

The ticket says "land as a coordinated minor bump (e.g. content-standards
`v1.3.0`)." That phrasing predates / mis-describes this repo's model. There is
**no independent per-track semver**: the repo has a single version line, the git
tag (`git describe` is the source of truth per `CHANGELOG.md`), currently
`v1.11.0`. `apply-repo-standard.ps1` takes one `-StandardVersion`; `state/repos.md`
pins one version per repo. The `(v1.2.0)` / `(v1.5.0)` / `(v1.9.0)` annotations in
`README.md` mean **"introduced at"**, not a live track number.

So #94 ships as a standard repo minor — **v1.12.0** — adding non-breaking F#
guidance to existing standards. The content-standards "introduced at v1.2.0"
annotation does **not** change (the group is extended, not new).

## Paramount user story (P1)

As an implementer writing F# in an adopted STEM repo, when the natural shape
of my code is an F# construct with no 1:1 C# analogue (most prominently a
**module** or a **discriminated union**), I can read the affected standard and
find a single documented answer for the F# shape, instead of re-deriving the
"translate the C# rule to F#" mapping at each call site and producing ad-hoc
deviations.

LOGGING + the `WarmUp` module-as-feature-unit is the canonical worked example
(surfaced by `button-panel-tester` PR #95).

## Audit method

Each standard's current F# coverage was read directly from
`shared/standards/*.md` on `main` at this branch point. The matrix below
records what the file *actually* says today (not what the ticket assumed).
Where the ticket's first-pass survey and the file disagree, the file wins and
the discrepancy is noted.

## Audit matrix (AC #1) — 16 standards × F# shape question

Legend: **Covered** = the standard already answers it; **Gap** = needs a
sentence/subsection; **N/A** = no F# extension needed (language-agnostic or no
F# analogue).

### Content track (8)

| Standard | F# question | Status | Evidence (verified on `main`) |
|----------|-------------|--------|-------------------------------|
| LOGGING | Logger for a module (no `T` for `ILogger<T>`)? | **Gap** (P1) | `## F#` (L136–156) shows F# **classes only** (`ILogger<FrameDecoder> option`). No module guidance; the helpers carve-out (L42) is about helpers within a class, not standalone modules. This is the ticket's worked example. |
| VISIBILITY | `private`/`internal` DU cases; module visibility; BannedSymbols for DU ctors? | **Gap** | No `## F#` section and **no DU mention at all** (headers: Two regimes / Seal / abstract / Members). The ticket's "VISIBILITY mentions private cases inside DUs" is inaccurate — there is nothing. |
| THREAD_SAFETY | Shared mutable via `let mutable` at module scope vs instance fields? | **Gap (minor)** | `## F#` (L124–131) covers immutability-first, `Channel<'T>`, `task{}`, and "`ref cell`/mutable fields → same primitives." Does **not** call out module-scope `let mutable` as global state. One sentence closes it. |
| ERROR_HANDLING | `≥3-failures → custom hierarchy` when failures are DU cases? | **Gap (minor)** | `## F#` (L144–171) shows `Result<'T,'TError>`; "What this means" (L177) still frames the ≥3 threshold as an **exception** hierarchy. Doesn't say the error DU *is* the hierarchy (no exception type needed). One clarification closes it. |
| CANCELLATION | `task{}`/`async{}` CE subtleties (`reraise()` after `await`)? | **Gap (minor)** | `## F#` (L115–129) covers token propagation through `task{}`/`async{}`. Does **not** mention `reraise()` being unavailable after an `await` in `task{}` (surfaced in PR #95). One sentence + the `ExceptionDispatchInfo` workaround. |
| COMMENTS | `///` auto-wrap vs `<summary>`; records/DUs/modules? | **Covered** | `## F#` (L121–132): "Same `///` syntax" and explicitly "For F#-specific docs (records, DUs, modules), the same coverage rules apply." |
| CONFIGURATION | Options binding for F# records? | **Covered** | `## F#` (L162–181): F# records bind; `mutable` needed for `IConfiguration` reflection; immutable record + `validate` for libraries. |
| EVENTARGS | F# events vs `EventArgs` subclassing? | **Covered** | `## F# events` (L71–85): `IEvent<_,_>`/`Event<_>` + record payload; C# heritage shape only at interop boundary. |

### Structural track (8)

| Standard | F# question | Status | Evidence |
|----------|-------------|--------|----------|
| REPO_STRUCTURE | Do modules count as a "type" for any one-type-per-file rule? | **Gap (minor, optional)** | No explicit one-type-per-file rule exists, so there is nothing modules violate. Worth one clarifying sentence that F# files are organised by module/namespace, not a one-type rule — or leave as N/A. Decision D4. |
| LANGUAGE | F# default, language version, nullable for F#? | **Covered** | F#-default standard; dual-language throughout. |
| TESTING | FsCheck / property tests / headless Avalonia for F#? | **Covered** | F# testing stack (xUnit + FsCheck + Avalonia.Headless) is the standard's default. |
| MODULE_SEPARATION | Layer/assembly rules for `.fsproj`? | **Covered** | Layer rules apply identically to `.fsproj`; no F#-shape gap. |
| BUILD_CONFIG | Central packages / props for `.fsproj`? | **Covered** | Project-system mechanism, identical for `.fsproj` (incl. `FSharp.Core` CPM entry). |
| PORTABILITY | — | **N/A** | Language-agnostic (ticket "Out of scope"). |
| CI | — | **N/A** | Language-agnostic (ticket "Out of scope"). |
| MIGRATION | — | **N/A** | Language-agnostic (ticket "Out of scope"). |

## Work this implies for v1.12.0

Substantive additions (new prose / subsections):

1. **LOGGING** (P1) — add module-logger guidance: an explicit module carve-out
   to the `ILogger<T>` rule **and** the recommended
   `ILoggerFactory.CreateLogger("<stable-category>")` idiom, with the `WarmUp`
   case as the worked example. *(Decision D2 = both.)*
2. **VISIBILITY** — add an `## F#` subsection: DU case visibility (cases inherit
   the type's visibility; keep error/domain DUs `internal` by default), module
   visibility, and a note that BannedSymbols.txt bans **BCL symbols** (it has no
   bearing on DU-constructor visibility, which the compiler enforces via
   `private`).

Minor clarifications (a sentence or two each):

3. **THREAD_SAFETY** — module-scope `let mutable` is global mutable state; treat
   it like a `static` field.
4. **ERROR_HANDLING** — when failures are modelled as DU cases
   (`Result<'T, FetchFailureReason>`), the DU *is* the hierarchy; the ≥3-failure
   threshold for a custom **exception** hierarchy does not force an exception
   type.
5. **CANCELLATION** — `reraise()` is unavailable after an `await` inside
   `task{}`; capture with `ExceptionDispatchInfo` (or rethrow explicitly).
6. **REPO_STRUCTURE** — *(optional, per D4)* one sentence that F# files organise
   by module/namespace; no one-type-per-file rule applies.

No change needed: COMMENTS, CONFIGURATION, EVENTARGS, LANGUAGE, TESTING,
MODULE_SEPARATION, BUILD_CONFIG. Out of scope: PORTABILITY, CI, MIGRATION.

## Decisions (interview answers recorded; confirm any override)

- **D1 — Phase stop:** `specs` (this document). Confirm before I proceed to the
  v1.12.0 implementation.
- **D2 — LOGGING idiom:** **both** carve-out + `ILoggerFactory.CreateLogger`
  idiom. *(answered)*
- **D3 — Matrix home:** where should the permanent matrix live?
  - (a) a new section in `README.md` *(recommended — next to the standards
    index; single discoverable place)*
  - (b) a new `shared/standards/FSHARP.md` cross-standard index
  - (c) specs-only (not a shipped artifact)
- **D4 — Scope depth:** **matrix + fix all flagged** *(answered)* → items 1–5
  above, with item 6 (REPO_STRUCTURE) optional. Confirm whether to include 6.

## Deliverables

| Artifact | Surface(s) | Task |
|----------|-----------|------|
| Audit matrix (permanent) | per D3 | T001 |
| LOGGING module-logger guidance | `shared/standards/LOGGING.md` | T002 |
| VISIBILITY F# subsection | `shared/standards/VISIBILITY.md` | T003 |
| THREAD_SAFETY / ERROR_HANDLING / CANCELLATION clarifications | the three `.md` files | T004 |
| REPO_STRUCTURE sentence (optional, D4) | `shared/standards/REPO_STRUCTURE.md` | T005 |
| Cut release **v1.12.0** | `CHANGELOG.md` new `## [1.12.0]` entry + `chore(release): cut v1.12.0`; README content "introduced at v1.2.0" annotation **unchanged** | T006 |
| Adoption tracker note | `state/repos.md` | T007 |
| Tag `v1.12.0` | git tag per the release flow | T008 (finalization) |

## Verification

- `eng/tests/Apply-RepoStandard.Tests.ps1` (Pester) stays green — the
  standards-count assertion is derived dynamically, so adding prose to existing
  `.md` files needs no test fixup.
- `CHANGELOG.md` advances to `v1.12.0`; the git tag matches.
- Each edited standard still has its `> **Stability:**` header consistent with
  the CI "Standards-doc structure" check.

## Related

- `button-panel-tester` #92 (origin), PR #95 phase-7.md deviation note.
- `docs/Standards/LOGGING.md` L42, L136–156 — the passages the worked example
  extends.

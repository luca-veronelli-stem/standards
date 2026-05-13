# Standard: DESIGN_SYSTEM

> **Stability:** v1.5.0
> **Principle:** every archetype A app shares the **same visual contract**: the same theme, the same spacing rhythm, the same icon source, the same localisation mechanism, the same error-and-progress surfaces. Internal STEM tooling reads as one product family even when each app is a separate repo. Brand assets (corporate palette / typography / logo) follow once received from STEM; until then the design system is anchored to neutral Fluent defaults.
> **Applies to:** archetype A.
> **Pairs with:** [`GUI.md`](./GUI.md). `GUI` governs project shape and the MVU paradigm; this standard governs everything the user sees inside that shape.

## Reference

`Avalonia.Themes.Fluent` (theme), `FluentIcons.Avalonia.Fluent` (iconography). Both pinned via the templates' `Directory.Packages.props`. F# strings module for localisation — no external runtime, no `.resx`, no JSON dictionaries.

## Theme

- **Base:** `FluentTheme` from `Avalonia.Themes.Fluent`. No `SimpleTheme`, no third-party theme packs.
- **Mode:** **dark mode is the default at first launch.** Engineers and production-floor operators prefer dark UIs on long sessions and low-light bays. The user can toggle to light; the choice is persisted to settings per [`CONFIGURATION.md`](./CONFIGURATION.md).
- The active mode lives on the top-level `Model` (`type ThemeMode = Dark | Light`) and is applied at `App.fs` startup via `RequestedThemeVariant`.

```fsharp
// in App.fs
override this.Initialize () =
    base.Initialize ()
    this.Styles.Add (FluentTheme ())
    this.RequestedThemeVariant <- ThemeVariant.Dark
```

## Palette / typography / logo

> **Status:** placeholder pending STEM corporate visual identity.

Until Luca delivers the STEM brand book, archetype A apps use Fluent defaults:

- **Accent:** Fluent default blue (`SystemAccentColor`).
- **Neutrals:** Fluent default `SystemControl*` grays.
- **Semantic:** Fluent default success / warning / error variants.
- **Typography:** `Segoe UI Variable` on Windows; `Inter` (bundled in `Resources/fonts/` on the app) on Linux and macOS.
- **Logo:** monochrome `STEM` wordmark in `Resources/branding/stem-logo.svg`, swappable at brand-book time.

When the brand book lands, this section is replaced with named palette tokens (`Stem.Brand.Accent`, `Stem.Brand.AccentSubtle`, …), a typography scale, and the canonical logo asset. The replacement is a **minor** version bump on this standard — no breaking change to call sites, only a swap of resource values.

## Spacing

A 4-pt grid spans the whole app. Use named constants from a per-app `Spacing` module — no magic numbers in the view DSL.

```fsharp
module Stem.<App>.GUI.Spacing

let xs   = 4.0      // hairline padding, tight stacks
let sm   = 8.0      // standard control padding
let md   = 12.0     // grouped-control spacing
let lg   = 16.0     // section padding
let xl   = 24.0     // page margins
let xxl  = 32.0     // page-section breaks
let xxxl = 56.0     // hero / dialog padding
let huge = 80.0     // full-bleed splash
```

Stack with `StackPanel.spacing Spacing.md`; pad with `Border.padding (Thickness Spacing.lg)`. Never pass a literal `8.0` or `12.0` into a layout primitive — if a value isn't in the scale, propose adding it to `Spacing` rather than inlining.

## Iconography

- **Source:** `FluentIcons.Avalonia.Fluent` (Microsoft's open-source Fluent System Icons, MIT licensed). Provides ~2000 icons in regular and filled variants, paired natively with the Fluent theme.
- **Usage from FuncUI:**

  ```fsharp
  open FluentIcons.Avalonia.Fluent
  open FluentIcons.Common

  SymbolIcon.create [
      SymbolIcon.symbol Symbol.Save
      SymbolIcon.iconVariant IconVariant.Regular
      SymbolIcon.fontSize 20.0
  ]
  ```

- **Sizing:** icons match the surrounding text's `FontSize`. Toolbar icons default to `20`, in-line icons to `16`, hero icons (empty states) to `48`.
- **Filled vs regular:** regular for navigation and idle affordances; filled for selected / active / destructive states. Pick one of the two within a row — never mix.
- **Custom icons:** when the Fluent catalogue genuinely lacks a glyph (device-specific schematics, STEM hardware silhouettes), drop an SVG into `Resources/icons/` and expose it through a typed `Icons` module. Avoid raster formats; SVG only.

## Localisation (i18n)

Every archetype A app ships **Italian** (default at runtime) **and English** translations. No app is single-language. No string ever sits inline in a view — every visible word lives in `Strings.fs`.

### Mechanism — F# strings module

```fsharp
module Stem.<App>.GUI.Strings

type Lang = It | En

let welcome (lang: Lang) =
    match lang with
    | It -> "Benvenuto"
    | En -> "Welcome"

let deviceConnected (lang: Lang) =
    match lang with
    | It -> "Dispositivo collegato"
    | En -> "Device connected"

let devicesFound (count: int) (lang: Lang) =
    match lang with
    | It -> sprintf "%d dispositivi trovati" count
    | En -> sprintf "%d devices found" count
```

The view consumes by passing the current `Lang` from the `Model`:

```fsharp
TextBlock.create [
    TextBlock.text (Strings.welcome model.Lang)
]
```

### Why F# strings module, not `.resx`

- **Compile-time completeness.** Adding a new language is one new DU case; the compiler then refuses to build until every string function handles it. Adding a new string forces an `It` and `En` value at the declaration site. Missing translations are impossible.
- **Refactor-safe.** Renaming a string is a rename across the project — no XML keys to chase, no `Resources.Designer.cs` to regenerate, no runtime `null` from a missing lookup.
- **MVU-native.** Strings are values, not resource-manager lookups. `Update` and `View` consume them the same way they consume any other model field.
- **No external tooling.** Translators receive a `Strings.fs` patch on a PR; the diff reads as prose paired by case. There is no ResX Manager dependency, no Crowdin pipeline, no key-mismatch class of bug.

### Default language at runtime

`Lang.It` is the startup default. The first-run experience offers a language picker in the title bar; the choice is persisted per [`CONFIGURATION.md`](./CONFIGURATION.md). The active value lives on the top-level `Model.Lang`.

### Italian-first content rules

- **Seed data stays Italian.** Variables, protocol dictionaries, and other domain data are *data*, not UI chrome — they ship in whatever language STEM uses internally (typically Italian for legacy dictionaries) and are not translated by the strings module.
- **UI chrome translates.** Every label, button, error message, toast, modal heading, and tab title goes through `Strings.fs`.
- **Logs stay English** per [`LOGGING.md`](./LOGGING.md) and the `COMMENTS.md` English-by-default rule. The strings module is the user-facing surface, not the diagnostic one.

## Error and progress surfaces

Four surfaces, each with a defined role. Pick by the decision tree, not by feel.

| Surface | When to use | Lifetime | Blocks input? |
| --- | --- | --- | --- |
| **Toast** | Non-critical info, success confirmation, recoverable warning | Auto-dismiss after 4–8 s | No |
| **Banner** | Persistent condition the user should be aware of (offline mode, stale data, pending update) | Until condition clears or user dismisses | No |
| **Inline error** | Validation failure attached to a specific control | Until the user corrects the input | No |
| **Modal** | Destructive confirmation, unrecoverable error, mandatory acknowledgement | Until the user acknowledges | Yes |

### Decision tree

1. Does the user need to *do* something before the app can proceed? → **modal**.
2. Is the error tied to one input field? → **inline error** beside that control.
3. Is the condition ongoing (not a one-shot event)? → **banner**.
4. Otherwise → **toast**.

### Payload shape

All four surfaces consume the same `ErrorPayload` record produced upstream per [`ERROR_HANDLING.md`](./ERROR_HANDLING.md):

```fsharp
type Severity = Info | Success | Warning | Error

type ErrorPayload = {
    Severity: Severity
    Title:    Lang -> string
    Body:     Lang -> string
    Action:   (Lang -> string) option   // optional "Retry" / "View details" label
    OnAction: Msg option                 // dispatched if Action is invoked
}
```

The `Title` and `Body` carry localised functions, not pre-rendered strings — the surface renders them with the current `Model.Lang`, so a language switch mid-toast re-renders correctly.

### Semantic colours

Each severity maps to a Fluent token:

- `Info`    → `SystemControlBackgroundAccentBrush`
- `Success` → green semantic (Fluent `SystemFillColorSuccess`)
- `Warning` → amber semantic (Fluent `SystemFillColorCaution`)
- `Error`   → red semantic (Fluent `SystemFillColorCritical`)

When the STEM brand palette lands, these map to brand tokens instead.

## Loading and progress

- **Inline spinner** for small async ops (single-row save, validation round-trip). Sits on the control itself.
- **Top-of-view progress bar** (`ProgressBar.isIndeterminate true`) for page transitions and content loads.
- **Skeleton loaders** for content-heavy pages (variable tables, log views) — preserves layout while data streams in.
- **Cancel affordance.** When the operation is long-running and cancellable per [`CANCELLATION.md`](./CANCELLATION.md), the surface exposes a visible **Cancel** button (toast action / banner button / modal button). Operations without a Cancel affordance are not allowed to run more than ~2 s.

## Window sizing and DPI

- **Minimum window size:** `1024 × 600`. Engineers run these tools on docked laptops and production-floor workstations; below this size column-dense tables collapse beyond usability.
- **Per-monitor DPI awareness:** on by default via Avalonia. No fixed-pixel positioning — use `Grid` with proportional rows/columns, or `DockPanel`, or `StackPanel` plus the `Spacing` scale.
- **High-DPI assets:** SVG icons (Fluent System Icons + custom) scale natively; raster assets in `Resources/` ship at 1×, 2×, and 3× via Avalonia's `.assets` convention.

## Accessibility floor

Minimum requirements every archetype A app meets:

- **Keyboard navigation:** every interactive control is reachable by Tab; tab order matches visual reading order.
- **Focus indicator:** the Fluent default focus ring stays on. Don't strip it for visual reasons.
- **Contrast:** body text meets WCAG AA against its background in both themes. Verify via Avalonia DevTools' contrast checker during page review.
- **Touch targets:** minimum 44 × 44 px when running on a touchscreen workstation (production floor). Critical actions get explicit hit-test padding.

Production-floor touchscreens are real deployment targets for some apps — design with mouse and finger in mind from the start, not as a retrofit.

## What this means in practice

- **Adding a string:** edit `Strings.fs`, the compiler reminds you to fill `It` and `En`. View consumes via `Strings.<name> model.Lang`.
- **Adding a colour:** use a Fluent token; if the brand book has landed, use a `Stem.Brand.*` token. Never a hex literal in the view DSL.
- **Adding an icon:** import from `FluentIcons.Common.Symbol` and pick. Custom SVG only when the Fluent set genuinely lacks the glyph.
- **Reporting an error:** build an `ErrorPayload` upstream; route to the right surface via the decision tree. Don't `printfn` a user-facing string and call it a day.
- **Choosing a spacing value:** read from `Stem.<App>.GUI.Spacing`. If the value you need is missing, add it to `Spacing` (and consider whether it should land here as a new scale step).
- **When the brand book arrives:** swap the palette / typography / logo section of this standard for the named-token version; bump this standard's minor; re-roll adopted repos.

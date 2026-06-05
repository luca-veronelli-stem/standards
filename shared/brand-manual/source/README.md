# Brand source masters

Editable Adobe Illustrator masters for the STEM brand assets. Everything the
rollout ships to adopters is **derived** from these files — keep them here as the
single source of truth and never hand-edit the exports.

| File | Master for |
|------|------------|
| `stem-marks.ai` | Brand-marks and symbols (corporate / ems / commercial-vehicles / marine, in positive / negative / mono-white) |
| `stem-app-icons.ai` | Application icons (positive / mono-white) |

## Where the exports live

Rendered SVG/PNG/ICO exports are committed under the archetype A template tree
and copied byte-identical into adopter repos by the rollout:

```
shared/templates/archetypes/A/src/{{App}}.GUI/Resources/branding/
  app-icons/    brand-marks/    symbols/
```

The `.ai` masters deliberately stay **outside** that template tree so they are
not copied into every adopted repo.

## Regenerating after an edit

1. Export the affected SVGs from Illustrator over the matching files under
   `…/Resources/branding/`.
2. Rebuild the app-icon `.ico` from its SVG and verify the alpha plane with
   [`eng/New-StemAppIcon.ps1`](../../../eng/New-StemAppIcon.ps1) (it fails loudly
   if a frame's alpha was flattened to opaque — the positional `-background`
   gotcha).
3. Optionally batch-check the committed icons with
   [`eng/verify-icon-alpha.py`](../../../eng/verify-icon-alpha.py).

The brand manual PDF (`../stem-brand-manual.pdf`) is the human-facing reference
for usage rules.

"""
Batch-verify the alpha plane of every frame in the committed STEM app-icon
.ico files.

This is the post-hoc companion to eng/New-StemAppIcon.ps1: that script verifies
alpha at *generation* time, while this one re-checks the icons already committed
to the tree (e.g. as a CI guard) without regenerating them.

Exit 0 if every frame of every icon has real alpha (some pixel < 255 opaque, or
transparent pixels present); exit 1 otherwise. One line per (file, frame) is
printed for the commit/CI log.

Usage:
    py eng/verify-icon-alpha.py [<dir-containing-the-.ico-files>]

With no argument it checks the icons under the archetype A branding tree.
"""
import sys
from pathlib import Path
from PIL import IcoImagePlugin

# Repo root is the parent of eng/. Default to the archetype A app-icons dir,
# where the committed .ico masters live (and from which the rollout copies them
# byte-identical into adopter repos).
REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DIR = (
    REPO_ROOT
    / "shared/templates/archetypes/A/src/{{App}}.GUI/Resources/branding/app-icons"
)
ICONS = ("stem-app-icon-positive.ico", "stem-app-icon-mono-white.ico")

icon_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_DIR

all_pass = True
for name in ICONS:
    path = icon_dir / name
    print(f"== {name} ==")
    with open(path, "rb") as fh:
        ico = IcoImagePlugin.IcoFile(fh)
        for entry in ico.entry:
            w, h = entry.width, entry.height
            frame = ico.getimage((w, h))
            if frame.mode != "RGBA":
                frame = frame.convert("RGBA")
            alpha = frame.getchannel("A")
            amin, amax = alpha.getextrema()
            hist = alpha.histogram()
            transparent = hist[0]
            partial = sum(hist[1:255])
            total = sum(hist)
            ok = (amin < 255) or (transparent > 0)
            if not ok:
                all_pass = False
            print(
                f"  {w}x{h} mode={frame.mode} "
                f"alpha=[{amin}..{amax}] "
                f"transparent={transparent}/{total} "
                f"partial={partial} {'OK' if ok else 'BUG'}"
            )

sys.exit(0 if all_pass else 1)

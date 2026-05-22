#requires -Version 5.1
<#
.SYNOPSIS
    Generate a multi-frame transparent Windows .ico from an SVG master.

.DESCRIPTION
    Wraps ImageMagick's `magick -define icon:auto-resize=...` to produce a
    multi-frame .ico (16/32/48/256 px by default) from a single SVG source,
    then verifies via Pillow that every frame preserves an alpha channel that
    actually varies (lo < 255). This second step is the load-bearing safety
    net for the positional-flag gotcha documented below: a flattened-alpha
    .ico passes every casual visual check (Explorer composites against white;
    magick reports no warning; the file is still 32bpp RGBA) but renders as
    an opaque white tile on any dark surface (dark-theme title bar, photo
    overlays). The Pillow check exits non-zero before the bad .ico can be
    committed.

    -Background flag positioning. `-background none` MUST come BEFORE the SVG
    input on the magick command line. It is a positional setting that applies
    only to inputs read after it. Placed after the SVG, it silently no-ops
    and ImageMagick flattens the SVG's transparent canvas against its
    default white background. Surfaced in button-panel-tester #101 (Stem
    standards #101).

.PARAMETER SvgPath
    Path to the SVG master. Required.

.PARAMETER IcoPath
    Path where the generated .ico will be written. Required. Parent directory
    must already exist.

.PARAMETER Sizes
    Square frame sizes (px) to embed in the .ico. Default 16, 32, 48, 256 --
    the set Windows actually picks from for title-bar, taskbar, Alt-Tab and
    Explorer-extra-large surfaces. Smaller sets are fine; sizes outside this
    list mostly waste bytes.

.EXAMPLE
    # Regenerate the bundled positive app icon from its SVG master.
    & 'C:\Users\LucaV\Source\Repos\standards\eng\New-StemAppIcon.ps1' `
        -SvgPath shared/templates/archetypes/A/src/`{`{App`}`}.GUI/Resources/branding/app-icons/stem-app-icon-positive.svg `
        -IcoPath shared/templates/archetypes/A/src/`{`{App`}`}.GUI/Resources/branding/app-icons/stem-app-icon-positive.ico

.NOTES
    Requires:
      - ImageMagick 7 (`magick` on PATH).
      - Python 3 + Pillow (`py -c "from PIL import Image"` must succeed).
    Both are baseline expectations on a STEM dev workstation.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SvgPath,
    [Parameter(Mandatory)][string]$IcoPath,
    [int[]]$Sizes = @(16, 32, 48, 256)
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SvgPath)) {
    throw "SVG master not found: $SvgPath"
}

$icoFull = [System.IO.Path]::GetFullPath($IcoPath)
$icoDir  = Split-Path $icoFull -Parent
if (-not (Test-Path -LiteralPath $icoDir)) {
    throw "Output directory does not exist: $icoDir"
}

# IMPORTANT: -background MUST come BEFORE the SVG input. This is a
# positional setting in ImageMagick -- placed after the input it is a
# no-op and the alpha channel gets flattened against the default white
# background. The output looks correct in Explorer (which composites
# against white) but renders as a white tile on any dark surface.
$autoResize = "icon:auto-resize=$($Sizes -join ',')"
& magick -background none $SvgPath -define $autoResize $icoFull
if ($LASTEXITCODE -ne 0) {
    throw "ImageMagick failed with exit code $LASTEXITCODE"
}

# Verify transparency was preserved on every embedded frame. Catches the
# positional-flag bug even if a future contributor re-orders the command,
# and any other path that produces a 32bpp RGBA .ico with an alpha plane
# pinned to 255 (fully opaque). Single quotes around the path defeat
# Python's r'...' string parsing on Windows; pass via $env to keep the
# script portable across path shapes.
$env:STEM_ICO_VERIFY_PATH = $icoFull
$pyCheck = @'
import os
from PIL import IcoImagePlugin
path = os.environ["STEM_ICO_VERIFY_PATH"]
with open(path, "rb") as fh:
    ico = IcoImagePlugin.IcoFile(fh)
    sizes = sorted(ico.sizes())
    if not sizes:
        raise SystemExit("no frames in .ico")
    for size in sizes:
        alpha = ico.getimage(size).getchannel("A")
        lo, hi = alpha.getextrema()
        if lo == 255:
            raise SystemExit(
                f"frame {size[0]}x{size[1]}: alpha flattened to opaque (range {lo},{hi})"
            )
print(f"ALL FRAMES TRANSPARENT ({len(sizes)} frames: {', '.join(f'{w}x{h}' for w, h in sizes)})")
'@
& py -c $pyCheck
$verifyExit = $LASTEXITCODE
Remove-Item Env:\STEM_ICO_VERIFY_PATH -ErrorAction SilentlyContinue
if ($verifyExit -ne 0) {
    Remove-Item -LiteralPath $icoFull -Force -ErrorAction SilentlyContinue
    throw "Transparency verification failed; output removed."
}

Write-Host "Wrote $icoFull ($($Sizes -join ', ') px frames; alpha verified)" -ForegroundColor Green

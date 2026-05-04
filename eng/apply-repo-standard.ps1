#requires -Version 5.1
<#
.SYNOPSIS
    Bootstraps or bumps a STEM repo to a given llm-settings Standard version.

.DESCRIPTION
    Copies the v1 templates and standards from this llm-settings checkout
    into a target work repo, substituting {{Placeholder}} markers with values
    from the parameters and from .stem-standard.json (written on first run,
    read on subsequent runs).

    See shared/standards/MIGRATION.md for the rollout flow.

.PARAMETER RepoPath
    Target work repo. Defaults to the current directory.

.PARAMETER App
    Short app/library name (e.g. 'DeviceManager', 'Communication'). Used to
    fill {{App}} placeholders in templates.

.PARAMETER Repo
    GitHub repo slug (e.g. 'stem-device-manager'). Used to fill {{Repo}}.
    Defaults to the basename of RepoPath.

.PARAMETER Archetype
    One of A, B, C, D. D triggers an error -- run a new-archetype session.

.PARAMETER Owner
    GitHub owner where the repo lives. Used to fill {{Owner}}.

.PARAMETER LucaUser
    GitHub username for CODEOWNERS '@user' references. Used to fill {{LucaUser}}.
    Often the same as -Owner.

.PARAMETER StandardVersion
    The llm-settings tag this repo should pin to (e.g. 'v1.0.0').

.PARAMETER Author
    Author name for README/CHANGELOG headers. Used to fill {{Author}}.

.PARAMETER Description
    One-line repo description for README badge line. Used to fill {{Description}}.

.PARAMETER DryRun
    Print what would change. Don't write anything.

.EXAMPLE
    # First-time bootstrap
    & 'C:\Users\LucaV\Source\Repos\llm-settings\eng\apply-repo-standard.ps1' `
        -RepoPath C:\Users\LucaV\Source\Repos\stem-device-manager `
        -App DeviceManager `
        -Archetype A `
        -Owner luca-veronelli `
        -LucaUser luca-veronelli `
        -StandardVersion v1.0.0 `
        -Description 'Telemetry and device management for STEM industrial gear'

.EXAMPLE
    # Subsequent bump -- only StandardVersion needs to change.
    & 'C:\Users\LucaV\Source\Repos\llm-settings\eng\apply-repo-standard.ps1' `
        -RepoPath C:\Users\LucaV\Source\Repos\stem-device-manager `
        -StandardVersion v1.1.0
#>

[CmdletBinding()]
param(
    [string]$RepoPath = (Get-Location).Path,
    [string]$App,
    [string]$Repo,
    [ValidateSet('A','B','C','D')]
    [string]$Archetype,
    [string]$Owner,
    [string]$LucaUser,
    [string]$StandardVersion,
    [string]$Author = 'Luca Veronelli',
    [string]$Description,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------
# Resolve roots
# --------------------------------------------------------------------------

$llmSettingsRoot = Split-Path $PSScriptRoot -Parent
$templatesRoot   = Join-Path $llmSettingsRoot 'shared/templates'
$standardsRoot   = Join-Path $llmSettingsRoot 'shared/standards'

if (-not (Test-Path $templatesRoot)) {
    throw "Templates root not found: $templatesRoot. Is this script in <llm-settings>/eng/?"
}
if (-not (Test-Path $standardsRoot)) {
    throw "Standards root not found: $standardsRoot."
}

$repoFull = (Resolve-Path $RepoPath -ErrorAction Stop).Path
if (-not (Test-Path (Join-Path $repoFull '.git'))) {
    throw "RepoPath does not appear to be a git repo: $repoFull"
}

# --------------------------------------------------------------------------
# Merge params with .stem-standard.json (passed params win)
# --------------------------------------------------------------------------

$configPath = Join-Path $repoFull '.stem-standard.json'
$existing   = $null
if (Test-Path $configPath) {
    $existing = Get-Content $configPath -Raw | ConvertFrom-Json
}

function Get-ConfigValue {
    param($Passed, $Existing, $Default = $null)
    if ($Passed)             { return $Passed }
    if ($null -ne $Existing) { return $Existing }
    return $Default
}

$cfg = [ordered]@{
    app             = Get-ConfigValue $App             $existing.app
    repo            = Get-ConfigValue $Repo            $existing.repo            (Split-Path $repoFull -Leaf)
    archetype       = Get-ConfigValue $Archetype       $existing.archetype
    owner           = Get-ConfigValue $Owner           $existing.owner
    lucaUser        = Get-ConfigValue $LucaUser        $existing.lucaUser
    standardVersion = Get-ConfigValue $StandardVersion $existing.standardVersion
    author          = Get-ConfigValue $Author          $existing.author          'Luca Veronelli'
    description     = Get-ConfigValue $Description     $existing.description     ''
    year            = (Get-Date).Year.ToString()
}

$required = @('app','archetype','owner','lucaUser','standardVersion')
$missing  = $required | Where-Object { -not $cfg[$_] }
if ($missing) {
    throw "Missing required values: $($missing -join ', '). Pass via -Param or set in .stem-standard.json."
}

if ($cfg.archetype -eq 'D') {
    throw "Archetype D is a placeholder. Run a new-archetype design session before adopting any standard."
}

# --------------------------------------------------------------------------
# Substitution
# --------------------------------------------------------------------------

$placeholders = @{
    '{{App}}'             = $cfg.app
    '{{Repo}}'            = $cfg.repo
    '{{Archetype}}'       = $cfg.archetype
    '{{Owner}}'           = $cfg.owner
    '{{LucaUser}}'        = $cfg.lucaUser
    '{{StandardVersion}}' = $cfg.standardVersion
    '{{Author}}'          = $cfg.author
    '{{Description}}'     = $cfg.description
    '{{Year}}'            = $cfg.year
}

$noSubstituteExtensions = @('.png','.jpg','.jpeg','.gif','.ico','.icns','.dll','.exe','.pdb','.zip','.7z','.tar','.gz')
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Expand-Placeholder {
    param([string]$Text)
    foreach ($key in $placeholders.Keys) {
        $Text = $Text.Replace($key, [string]$placeholders[$key])
    }
    return $Text
}

# --------------------------------------------------------------------------
# Single-file processor: substitute + copy + record in summary
# --------------------------------------------------------------------------

$summary = New-Object System.Collections.Generic.List[string]

function Copy-TemplateFile {
    param(
        [string]$SourceFile,
        [string]$SourceRoot,
        [string]$DestRoot,
        [string]$Tag
    )

    $relative = $SourceFile.Substring($SourceRoot.Length).TrimStart('\','/')

    $destRelative = if ($relative.EndsWith('.template')) {
        $relative.Substring(0, $relative.Length - '.template'.Length)
    } else {
        $relative
    }

    $destFull = Join-Path $DestRoot $destRelative
    $destDir  = Split-Path $destFull -Parent
    $ext      = [System.IO.Path]::GetExtension($SourceFile).ToLowerInvariant()

    if ($noSubstituteExtensions -contains $ext) {
        if (-not $DryRun) {
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
            Copy-Item -Path $SourceFile -Destination $destFull -Force
        }
        $summary.Add("[$Tag] $destRelative (binary)")
        return
    }

    $content    = [System.IO.File]::ReadAllText($SourceFile)
    $newContent = Expand-Placeholder -Text $content

    if (-not $DryRun) {
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        [System.IO.File]::WriteAllText($destFull, $newContent, $utf8NoBom)
    }
    $summary.Add("[$Tag] $destRelative")
}

# --------------------------------------------------------------------------
# 1) Common templates -> repo root (excludes archetypes/)
# --------------------------------------------------------------------------

Write-Host "Applying common templates -> $repoFull" -ForegroundColor Cyan
$archetypesPath = (Join-Path $templatesRoot 'archetypes').TrimEnd('\','/')
Get-ChildItem -Path $templatesRoot -Recurse -File | Where-Object {
    -not $_.FullName.StartsWith($archetypesPath, [StringComparison]::OrdinalIgnoreCase)
} | ForEach-Object {
    Copy-TemplateFile -SourceFile $_.FullName -SourceRoot $templatesRoot -DestRoot $repoFull -Tag 'common'
}

# --------------------------------------------------------------------------
# 2) Archetype overlay (A or B)
# --------------------------------------------------------------------------

if ($cfg.archetype -in @('A','B')) {
    $overlayRoot = Join-Path $templatesRoot "archetypes/$($cfg.archetype)"
    if (Test-Path $overlayRoot) {
        Write-Host "Applying archetype $($cfg.archetype) overlay" -ForegroundColor Cyan
        Get-ChildItem -Path $overlayRoot -Recurse -File | ForEach-Object {
            Copy-TemplateFile -SourceFile $_.FullName -SourceRoot $overlayRoot -DestRoot $repoFull -Tag "overlay-$($cfg.archetype)"
        }
    }
}

# --------------------------------------------------------------------------
# 3) Standards -> docs/Standards/
# --------------------------------------------------------------------------

$standardsTarget = Join-Path $repoFull 'docs/Standards'
Write-Host "Copying standards -> docs/Standards/" -ForegroundColor Cyan
if (-not $DryRun -and -not (Test-Path $standardsTarget)) {
    New-Item -ItemType Directory -Path $standardsTarget -Force | Out-Null
}
Get-ChildItem -Path $standardsRoot -Filter *.md -File | ForEach-Object {
    $destFull = Join-Path $standardsTarget $_.Name
    if (-not $DryRun) {
        Copy-Item -Path $_.FullName -Destination $destFull -Force
    }
    $summary.Add("[standards] docs/Standards/$($_.Name)")
}

# Generate docs/Standards/README.md index.
$standardPurpose = [ordered]@{
    'REPO_STRUCTURE'     = 'Root layout, archetype trees, naming rules.'
    'LANGUAGE'           = 'F# default; layer-default table; deviation policy.'
    'MODULE_SEPARATION'  = 'Onion (A) and hexagonal (B) layering; banned APIs.'
    'PORTABILITY'        = 'net10.0 default; TFM-conditional drivers; cross-platform replacements.'
    'BUILD_CONFIG'       = 'Directory.Build.props, Directory.Packages.props, global.json, .editorconfig.'
    'TESTING'            = 'xUnit + FsCheck + Avalonia.Headless; single F# tests project default.'
    'CI'                 = 'GitHub Actions: ci.yml, mirror-bitbucket.yml, release.yml; matrix legs.'
    'MIGRATION'          = 'Per-repo adoption phases; major/minor/patch bump procedures.'
}

$indexLines = New-Object System.Collections.Generic.List[string]
$indexLines.Add("# STEM standards (Standard version: $($cfg.standardVersion))")
$indexLines.Add('')
$indexLines.Add("These are inline copies pinned to ``$($cfg.standardVersion)``. Upstream source of truth is [`llm-settings/shared/standards/`](https://github.com/$($cfg.lucaUser)/llm-settings/tree/$($cfg.standardVersion)/shared/standards) (private repo).")
$indexLines.Add('')
$indexLines.Add('| Standard | Purpose |')
$indexLines.Add('| --- | --- |')
foreach ($kvp in $standardPurpose.GetEnumerator()) {
    $indexLines.Add("| [$($kvp.Key).md](./$($kvp.Key).md) | $($kvp.Value) |")
}
$indexLines.Add('')
$indexLines.Add('## Bumping the standard version')
$indexLines.Add('')
$indexLines.Add('Re-run the rollout from `<llm-settings>/eng/apply-repo-standard.ps1` with `-StandardVersion vX.Y.Z`. The script reads `.stem-standard.json` at the repo root, so only the new tag needs to be passed.')

if (-not $DryRun) {
    [System.IO.File]::WriteAllText((Join-Path $standardsTarget 'README.md'), ($indexLines -join "`n") + "`n", $utf8NoBom)
}
$summary.Add('[standards] docs/Standards/README.md (regenerated)')

# --------------------------------------------------------------------------
# 4) Persist .stem-standard.json
# --------------------------------------------------------------------------

if (-not $DryRun) {
    $cfg | ConvertTo-Json -Depth 4 | ForEach-Object {
        [System.IO.File]::WriteAllText($configPath, $_, $utf8NoBom)
    }
}
$summary.Add('.stem-standard.json (written/updated)')

# --------------------------------------------------------------------------
# 5) Summary
# --------------------------------------------------------------------------

Write-Host ''
Write-Host '----- Summary -----' -ForegroundColor Yellow
foreach ($line in $summary) { Write-Host $line }
Write-Host ''
Write-Host "Standard version stamped: $($cfg.standardVersion)" -ForegroundColor Green
Write-Host "Archetype:                $($cfg.archetype)"
Write-Host ''
if ($DryRun) {
    Write-Host '(Dry run -- no files were written.)' -ForegroundColor Yellow
} else {
    Write-Host 'Next steps:'
    Write-Host "  1. Review the diff: cd $repoFull; git status; git diff"
    Write-Host '  2. Update <llm-settings>/state/repos.md to record the new version.'
    Write-Host '  3. Commit on a feature branch and open a PR.'
}

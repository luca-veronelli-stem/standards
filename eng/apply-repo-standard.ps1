#requires -Version 5.1
<#
.SYNOPSIS
    Bootstraps or bumps a STEM repo to a given llm-settings Standard version.

.DESCRIPTION
    Copies the v1 templates and standards from this llm-settings checkout
    into a target work repo, substituting {{Placeholder}} markers with values
    from the parameters and from .stem-standard.json (written on first run,
    read on subsequent runs).

    Tracks what the rollout last wrote in .stem-standard.lock (per-file SHA256
    of post-substitution content). On re-run:
      - Files unchanged on disk and unchanged in the source between versions
        are silent no-ops.
      - Files modified on disk since the last rollout are skipped with a
        warning (override with -Force).
      - CHANGELOG.md and LICENSE are never touched after the bootstrap.
      - -Minimal scopes the iteration to files that changed between the
        source tag (read from .stem-standard.lock) and the target tag.
      - -DryRun prints unified diffs of would-be changes (uses git diff).

    Out of scope: per-component README.md files (e.g. src/<Component>/README.md).
    Ownership ends at the top-level README.md and CLAUDE.md. Per-component
    READMEs are managed by hand on adoption -- typically deleted after a
    salvage pass for non-derivable content, optionally regenerated from
    shared/templates/docs/README_TEMPLATE.md per component. See
    shared/standards/MIGRATION.md (v1.2.0 section) for the salvage checklist.

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
    Print unified diffs of would-be changes; don't write anything.

.PARAMETER Force
    Overwrite files that have been locally modified since the last rollout
    (i.e. their on-disk hash differs from .stem-standard.lock). Without -Force,
    those files are skipped with a warning.

.PARAMETER Minimal
    Only iterate over template/standard files that changed between the source
    tag (read from .stem-standard.lock) and the target tag (-StandardVersion).
    Falls back to the full set if the lock is missing or git diff fails. Files
    containing {{StandardVersion}} are always re-rendered regardless, since
    every bump changes their substituted content.

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
        -StandardVersion v1.1.0 `
        -Minimal
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
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Minimal
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
# Lockfile (.stem-standard.lock) -- tracks per-file SHA256 of last-written
# post-substitution content. Auto-managed; do not hand-edit.
# --------------------------------------------------------------------------

$lockPath = Join-Path $repoFull '.stem-standard.lock'
$lock     = $null
if (Test-Path $lockPath) {
    $lock = Get-Content $lockPath -Raw | ConvertFrom-Json
}

# Two distinct signals:
#   * $repoIsBootstrapped -- repo has been through the rollout before, marked
#     by the presence of .stem-standard.json. Used for the bootstrap-only
#     carve-out (CHANGELOG.md and friends).
#   * $hasLockBaseline    -- a per-file hash baseline exists from a prior run
#     of the hardened script. Used to distinguish "rollout-written" from
#     "hand-edited" content.
$repoIsBootstrapped = $null -ne $existing
$hasLockBaseline    = $null -ne $lock

# Files in the work repo that are written only on bootstrap, never on re-run.
# CHANGELOG.md grows over time and must not be clobbered by template churn.
# LICENSE is per-repo customisation (project name, year) that the seed
# template provides at bootstrap; subsequent edits stay with the repo.
$bootstrapOnlyFiles = @('CHANGELOG.md', 'LICENSE')

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

# Normalize line endings to LF before hashing, so a target file rewritten as
# CRLF by core.autocrlf=true still hashes equal to its LF source.
function ConvertTo-LfText {
    param([string]$Text)
    return ($Text -replace "`r`n", "`n")
}

function Get-Sha256OfText {
    param([string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-LfText $Text))
    $sha   = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
        return -join ($hash | ForEach-Object { $_.ToString('x2') })
    } finally {
        $sha.Dispose()
    }
}

function Get-Sha256OfFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $text = [System.IO.File]::ReadAllText($Path)
    return Get-Sha256OfText -Text $text
}

# Unified diff via git diff --no-index between two temp files.
function Show-UnifiedDiff {
    param(
        [string]$OldText,
        [string]$NewText,
        [string]$DisplayPath
    )
    $tmpOld = [System.IO.Path]::GetTempFileName()
    $tmpNew = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tmpOld, (ConvertTo-LfText $OldText), $utf8NoBom)
        [System.IO.File]::WriteAllText($tmpNew, (ConvertTo-LfText $NewText), $utf8NoBom)
        $diff = & git diff --no-index --no-color --no-prefix -U3 $tmpOld $tmpNew 2>$null
        if ($LASTEXITCODE -gt 1) {
            Write-Host "    (git diff unavailable; printing raw new content)" -ForegroundColor DarkYellow
            return
        }
        foreach ($line in $diff) {
            $rendered = $line `
                -replace [regex]::Escape($tmpOld), "a/$DisplayPath" `
                -replace [regex]::Escape($tmpNew), "b/$DisplayPath"
            Write-Host "    $rendered"
        }
    } finally {
        Remove-Item $tmpOld, $tmpNew -ErrorAction SilentlyContinue
    }
}

# --------------------------------------------------------------------------
# Compute the -Minimal file set: files that changed between the locked
# source tag and the target tag in the llm-settings repo.
# --------------------------------------------------------------------------

$minimalAllowedSourceRels = $null
if ($Minimal) {
    if (-not $lock) {
        Write-Host "[-Minimal] no lockfile -- falling back to full iteration." -ForegroundColor DarkYellow
    } elseif ($lock.standardVersion -eq $cfg.standardVersion) {
        Write-Host "[-Minimal] target version matches locked version ($($cfg.standardVersion)) -- empty diff set." -ForegroundColor DarkYellow
        $minimalAllowedSourceRels = @{}
    } else {
        Push-Location $llmSettingsRoot
        try {
            $diffOutput = & git diff --name-only "$($lock.standardVersion)..$($cfg.standardVersion)" -- shared/templates shared/standards 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[-Minimal] git diff failed -- falling back to full iteration." -ForegroundColor DarkYellow
            } else {
                $minimalAllowedSourceRels = @{}
                foreach ($p in $diffOutput) {
                    if ([string]::IsNullOrWhiteSpace($p)) { continue }
                    # Normalize to forward slashes; key by full path under llm-settings root.
                    $minimalAllowedSourceRels[($p -replace '\\','/')] = $true
                }
                Write-Host "[-Minimal] $($minimalAllowedSourceRels.Count) source file(s) changed between $($lock.standardVersion) and $($cfg.standardVersion)." -ForegroundColor Cyan
            }
        } finally {
            Pop-Location
        }
    }
}

function Test-MinimalAllowed {
    param([string]$AbsoluteSourcePath)
    if ($null -eq $minimalAllowedSourceRels) { return $true }   # not in -Minimal mode
    $rel = $AbsoluteSourcePath.Substring($llmSettingsRoot.Length).TrimStart('\','/').Replace('\','/')
    return $minimalAllowedSourceRels.ContainsKey($rel)
}

# --------------------------------------------------------------------------
# Single-file processor
# --------------------------------------------------------------------------

# Outcome counters / lists for the final summary.
$plannedWrites    = New-Object System.Collections.Generic.List[string]
$skippedNoChange  = New-Object System.Collections.Generic.List[string]
$skippedModified  = New-Object System.Collections.Generic.List[string]
$skippedBootstrap = New-Object System.Collections.Generic.List[string]
$skippedMinimal   = New-Object System.Collections.Generic.List[string]
$writtenLockHashes = @{}   # destRelative (forward-slash) -> sha256

function Invoke-TemplateFile {
    param(
        [string]$SourceFile,
        [string]$SourceRoot,
        [string]$DestRoot,
        [string]$Tag,
        [string]$DestRelativePrefix = '',  # prepended to dest-relative path so lock keys are uniform with $repoFull-relative form
        [bool]  $AlwaysIterate = $false   # bypasses -Minimal scoping (for version-stamped files)
    )

    $relative = $SourceFile.Substring($SourceRoot.Length).TrimStart('\','/')

    $destRelative = if ($relative.EndsWith('.template')) {
        $relative.Substring(0, $relative.Length - '.template'.Length)
    } else {
        $relative
    }
    if ($DestRelativePrefix) {
        $destRelative = (Join-Path $DestRelativePrefix $destRelative)
    }
    $destRelativeFwd = $destRelative.Replace('\','/')

    $destFull = Join-Path $DestRoot $destRelative
    $destDir  = Split-Path $destFull -Parent
    $ext      = [System.IO.Path]::GetExtension($SourceFile).ToLowerInvariant()
    $isBinary = $noSubstituteExtensions -contains $ext

    # -- Policy: bootstrap-only files are never overwritten on re-run.
    if ($repoIsBootstrapped -and $bootstrapOnlyFiles -contains $destRelativeFwd) {
        $skippedBootstrap.Add("[$Tag] $destRelativeFwd")
        return
    }

    # -- Policy: -Minimal narrows iteration to source files that changed.
    if (-not $AlwaysIterate -and -not (Test-MinimalAllowed -AbsoluteSourcePath $SourceFile)) {
        $skippedMinimal.Add("[$Tag] $destRelativeFwd")
        return
    }

    # -- Render new content (or read raw bytes for binary).
    if ($isBinary) {
        $newBytes = [System.IO.File]::ReadAllBytes($SourceFile)
        $newText  = $null
        $newHash  = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new($newBytes)) -Algorithm SHA256).Hash.ToLower()
    } else {
        $rawText  = [System.IO.File]::ReadAllText($SourceFile)
        $newText  = Expand-Placeholder -Text $rawText
        $newHash  = Get-Sha256OfText -Text $newText
    }

    # -- Compare to existing target.
    $targetExists = Test-Path $destFull
    if ($targetExists) {
        $diskHash = if ($isBinary) {
            (Get-FileHash -Path $destFull -Algorithm SHA256).Hash.ToLower()
        } else {
            Get-Sha256OfFile -Path $destFull
        }

        if ($diskHash -eq $newHash) {
            # Already up to date. Record the hash for the lock and move on.
            $writtenLockHashes[$destRelativeFwd] = $newHash
            $skippedNoChange.Add("[$Tag] $destRelativeFwd")
            return
        }

        # Disk differs from rendered template. Was it the rollout's previous
        # write or a local edit?
        $lockHash = $null
        if ($lock -and $lock.files -and ($lock.files.PSObject.Properties.Name -contains $destRelativeFwd)) {
            $lockHash = $lock.files.$destRelativeFwd
        }

        # Decide whether the on-disk content was hand-edited:
        #   - If we have a lock baseline AND a hash for this file, the answer is
        #     exact: disk != lockHash means the user changed it since the last rollout.
        #   - If we have a lock baseline but no hash for this file, the file slipped
        #     past an earlier (lossy) rollout's lock-write. Treat as locally-modified
        #     so the user opts in via -Force; otherwise we'd silently clobber.
        #   - If we don't have a lock but the repo was previously bootstrapped, we
        #     can't tell what the previous rollout wrote -- assume locally-modified
        #     for safety (the user uses -Force on the first hardened run to seed).
        #   - If we have neither (true first bootstrap), nothing to protect -- write.
        if ($hasLockBaseline) {
            if ($lockHash) {
                $isLocallyModified = ($diskHash -ne $lockHash)
            } else {
                $isLocallyModified = $true
            }
        } elseif ($repoIsBootstrapped) {
            $isLocallyModified = $true
        } else {
            $isLocallyModified = $false
        }

        if ($isLocallyModified -and -not $Force) {
            $skippedModified.Add("[$Tag] $destRelativeFwd  (local edit; pass -Force to overwrite)")
            # Preserve the existing lock hash if any, so future runs still
            # see this as locally-modified until either -Force or a manual
            # reconciliation.
            if ($lockHash) { $writtenLockHashes[$destRelativeFwd] = $lockHash }
            return
        }
    }

    # -- We will write. Plan the write (or print diff for -DryRun).
    $plannedWrites.Add("[$Tag] $destRelativeFwd")

    if ($DryRun) {
        $oldText = if ($targetExists -and -not $isBinary) { [System.IO.File]::ReadAllText($destFull) } else { '' }
        if ($isBinary) {
            Write-Host "  -- $destRelativeFwd (binary, $($newBytes.Length) bytes)" -ForegroundColor DarkYellow
        } else {
            Write-Host "  -- $destRelativeFwd" -ForegroundColor DarkYellow
            Show-UnifiedDiff -OldText $oldText -NewText $newText -DisplayPath $destRelativeFwd
        }
        # Don't update lock during dry run.
        return
    }

    # -- Real write.
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    if ($isBinary) {
        [System.IO.File]::WriteAllBytes($destFull, $newBytes)
    } else {
        # Always write LF-normalized to keep the rollout output deterministic.
        $lfText = ConvertTo-LfText $newText
        [System.IO.File]::WriteAllText($destFull, $lfText, $utf8NoBom)
    }
    $writtenLockHashes[$destRelativeFwd] = $newHash
}

# --------------------------------------------------------------------------
# 1) Common templates -> repo root (excludes archetypes/)
# --------------------------------------------------------------------------

Write-Host "Applying common templates -> $repoFull" -ForegroundColor Cyan
$archetypesPath = (Join-Path $templatesRoot 'archetypes').TrimEnd('\','/')
Get-ChildItem -Path $templatesRoot -Recurse -File | Where-Object {
    -not $_.FullName.StartsWith($archetypesPath, [StringComparison]::OrdinalIgnoreCase)
} | ForEach-Object {
    # CLAUDE.md.template and README.md.template carry {{StandardVersion}} --
    # always re-render even in -Minimal mode (the bump itself changes their
    # substituted output).
    $alwaysIterate = $_.Name -in @('CLAUDE.md.template','README.md.template')
    Invoke-TemplateFile -SourceFile $_.FullName -SourceRoot $templatesRoot -DestRoot $repoFull -Tag 'common' -AlwaysIterate:$alwaysIterate
}

# --------------------------------------------------------------------------
# 2) Archetype overlay (A or B)
# --------------------------------------------------------------------------

if ($cfg.archetype -in @('A','B')) {
    $overlayRoot = Join-Path $templatesRoot "archetypes/$($cfg.archetype)"
    if (Test-Path $overlayRoot) {
        Write-Host "Applying archetype $($cfg.archetype) overlay" -ForegroundColor Cyan
        Get-ChildItem -Path $overlayRoot -Recurse -File | ForEach-Object {
            Invoke-TemplateFile -SourceFile $_.FullName -SourceRoot $overlayRoot -DestRoot $repoFull -Tag "overlay-$($cfg.archetype)"
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
    # Pass DestRoot=$repoFull with a docs/Standards/ prefix so lock keys for
    # standards files match the repo-relative form used by common templates
    # (BUILD_CONFIG.md -> docs/Standards/BUILD_CONFIG.md). Earlier versions
    # passed $standardsTarget as DestRoot, producing bare-filename keys that
    # didn't round-trip to the lookup form -- defeating the local-edit guard
    # (issue #42).
    Invoke-TemplateFile -SourceFile $_.FullName -SourceRoot $standardsRoot -DestRoot $repoFull -DestRelativePrefix 'docs/Standards/' -Tag 'standards'
}

# Generate docs/Standards/README.md index. Always rendered (carries the
# version), so bypass -Minimal.
$standardPurpose = [ordered]@{
    'REPO_STRUCTURE'     = 'Root layout, archetype trees, naming rules.'
    'LANGUAGE'           = 'F# default; layer-default table; deviation policy.'
    'MODULE_SEPARATION'  = 'Onion (A) and hexagonal (B) layering; banned APIs.'
    'PORTABILITY'        = 'net10.0 default; TFM-conditional drivers; cross-platform replacements.'
    'BUILD_CONFIG'       = 'Directory.Build.props, Directory.Packages.props, global.json, .editorconfig.'
    'TESTING'            = 'xUnit + FsCheck + Avalonia.Headless; single F# tests project default.'
    'CI'                 = 'GitHub Actions: ci.yml, mirror-bitbucket.yml, release.yml; matrix legs.'
    'MIGRATION'          = 'Per-repo adoption phases; major/minor/patch bump procedures.'
    'EVENTARGS'          = 'Two valid event-payload shapes; banned primitives.'
    'VISIBILITY'         = 'Archetype-aware default-internal/default-public; seal-by-default.'
    'LOGGING'            = 'ILogger<T>; structured-only; Console.WriteLine banned.'
    'THREAD_SAFETY'      = 'Decision order; .NET 10 Lock; sync-over-async banned.'
    'CANCELLATION'       = 'CancellationToken propagation; linked-CTS timeout; OCE handling.'
    'COMMENTS'           = 'XML doc coverage by visibility; English by default; <inheritdoc/>.'
    'ERROR_HANDLING'     = 'Try-pattern / Result type / exception decision tree.'
    'CONFIGURATION'      = 'Constants -> Configuration -> Service pattern; library + app delivery.'
}

$indexLines = New-Object System.Collections.Generic.List[string]
$indexLines.Add("# STEM standards (Standard version: $($cfg.standardVersion))")
$indexLines.Add('')
$indexLines.Add("These are inline copies pinned to ``$($cfg.standardVersion)``. Upstream source of truth is [`llm-settings/shared/standards/`](https://github.com/$($cfg.lucaUser)/llm-settings/tree/$($cfg.standardVersion)/shared/standards) (private repo).")
$indexLines.Add('')
$indexLines.Add('| Standard | Purpose |')
$indexLines.Add('| --- | --- |')
foreach ($kvp in $standardPurpose.GetEnumerator()) {
    $stdFile = Join-Path $standardsRoot ("$($kvp.Key).md")
    if (Test-Path $stdFile) {
        $indexLines.Add("| [$($kvp.Key).md](./$($kvp.Key).md) | $($kvp.Value) |")
    }
}
$indexLines.Add('')
$indexLines.Add('## Bumping the standard version')
$indexLines.Add('')
$indexLines.Add('Re-run the rollout from `<llm-settings>/eng/apply-repo-standard.ps1` with `-StandardVersion vX.Y.Z`. The script reads `.stem-standard.json` at the repo root, so only the new tag needs to be passed.')

$indexText = ($indexLines -join "`n") + "`n"
$indexDestRel = 'docs/Standards/README.md'
$indexDestFull = Join-Path $repoFull $indexDestRel
$indexNewHash = Get-Sha256OfText -Text $indexText
$indexExists  = Test-Path $indexDestFull
$indexDiskHash = if ($indexExists) { Get-Sha256OfFile -Path $indexDestFull } else { $null }

if ($indexDiskHash -eq $indexNewHash) {
    $writtenLockHashes[$indexDestRel] = $indexNewHash
    $skippedNoChange.Add("[standards] $indexDestRel")
} else {
    $indexLockHash = $null
    if ($lock -and $lock.files -and ($lock.files.PSObject.Properties.Name -contains $indexDestRel)) {
        $indexLockHash = $lock.files.$indexDestRel
    }
    $indexLocallyModified = if ($hasLockBaseline) {
        if ($indexLockHash) {
            $indexExists -and ($indexDiskHash -ne $indexLockHash)
        } else {
            # Missing lock entry with target on disk -- treat as locally-modified
            # (mirrors Defect 1 fix in Invoke-TemplateFile, issue #42).
            $indexExists
        }
    } elseif ($repoIsBootstrapped) {
        $indexExists
    } else {
        $false
    }
    if ($indexLocallyModified -and -not $Force) {
        $skippedModified.Add("[standards] $indexDestRel  (local edit; pass -Force to overwrite)")
        if ($indexLockHash) { $writtenLockHashes[$indexDestRel] = $indexLockHash }
    } else {
        $plannedWrites.Add("[standards] $indexDestRel (regenerated)")
        if ($DryRun) {
            $oldIndex = if ($indexExists) { [System.IO.File]::ReadAllText($indexDestFull) } else { '' }
            Write-Host "  -- $indexDestRel" -ForegroundColor DarkYellow
            Show-UnifiedDiff -OldText $oldIndex -NewText $indexText -DisplayPath $indexDestRel
        } else {
            [System.IO.File]::WriteAllText($indexDestFull, $indexText, $utf8NoBom)
            $writtenLockHashes[$indexDestRel] = $indexNewHash
        }
    }
}

# --------------------------------------------------------------------------
# 4) Persist .stem-standard.json (config) and .stem-standard.lock (hashes)
# --------------------------------------------------------------------------

if (-not $DryRun) {
    $cfg | ConvertTo-Json -Depth 4 | ForEach-Object {
        [System.IO.File]::WriteAllText($configPath, $_, $utf8NoBom)
    }

    # Sort lock entries for stable diffs across runs.
    $sortedFiles = [ordered]@{}
    foreach ($key in ($writtenLockHashes.Keys | Sort-Object)) {
        $sortedFiles[$key] = $writtenLockHashes[$key]
    }
    $newLock = [ordered]@{
        version         = 1
        writtenAt       = (Get-Date).ToUniversalTime().ToString('o')
        standardVersion = $cfg.standardVersion
        files           = $sortedFiles
    }
    [System.IO.File]::WriteAllText($lockPath, ($newLock | ConvertTo-Json -Depth 4), $utf8NoBom)
}

# --------------------------------------------------------------------------
# 5) Summary
# --------------------------------------------------------------------------

Write-Host ''
Write-Host '----- Summary -----' -ForegroundColor Yellow
if ($plannedWrites.Count -gt 0) {
    Write-Host "Will write ($($plannedWrites.Count)):" -ForegroundColor Green
    foreach ($line in $plannedWrites)    { Write-Host "  $line" }
}
if ($skippedNoChange.Count -gt 0) {
    Write-Host "Already up to date ($($skippedNoChange.Count)):" -ForegroundColor DarkGray
    foreach ($line in $skippedNoChange)  { Write-Host "  $line" -ForegroundColor DarkGray }
}
if ($skippedMinimal.Count -gt 0) {
    Write-Host "Skipped (-Minimal scope): $($skippedMinimal.Count) file(s)" -ForegroundColor DarkGray
}
if ($skippedBootstrap.Count -gt 0) {
    Write-Host "Skipped (bootstrap-only):" -ForegroundColor DarkGray
    foreach ($line in $skippedBootstrap) { Write-Host "  $line" -ForegroundColor DarkGray }
}
if ($skippedModified.Count -gt 0) {
    Write-Host "Skipped (local edits) ($($skippedModified.Count)):" -ForegroundColor Yellow
    foreach ($line in $skippedModified)  { Write-Host "  $line" -ForegroundColor Yellow }
    Write-Host '  Re-run with -Force to overwrite, or hand-reconcile each file.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host "Standard version stamped: $($cfg.standardVersion)" -ForegroundColor Green
Write-Host "Archetype:                $($cfg.archetype)"
Write-Host ''
if ($DryRun) {
    Write-Host '(Dry run -- no files were written.)' -ForegroundColor Yellow
} else {
    Write-Host 'Next steps:'
    Write-Host "  1. Review: cd $repoFull; git status; git diff"
    Write-Host '  2. Update <llm-settings>/state/repos.md to record the new version.'
    Write-Host '  3. Commit on a feature branch and open a PR.'
}

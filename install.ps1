<#
.SYNOPSIS
    Install Luca's llm-settings into the current Windows user profile.

.DESCRIPTION
    Symlinks claude/ and shared/ into %USERPROFILE%\.claude\, merges MCP
    server definitions into %USERPROFILE%\.claude.json, and (optionally)
    installs prerequisite tooling via winget.

    Designed for Windows PowerShell 5.1 - works under pwsh too.

.PARAMETER SkipPrereqs
    Skip the winget / pip / elan install phase. Use this on re-runs or when
    you've already installed Node.js, gh, PowerShell 7, Python, uv, elan.

.PARAMETER SkipMcp
    Skip the ~/.claude.json MCP merge step. Useful when debugging or when
    you don't want to touch existing MCP configuration.

.PARAMETER SkipLean
    Skip installing elan (Lean toolchain). Only set if you won't use lean-lsp.

.EXAMPLE
    .\install.ps1
    Full install (prereqs + symlinks + MCP).

.EXAMPLE
    .\install.ps1 -SkipPrereqs
    Refresh symlinks + MCP only; leave installed tools alone.
#>

[CmdletBinding()]
param(
    [switch]$SkipPrereqs,
    [switch]$SkipMcp,
    [switch]$SkipLean
)

$ErrorActionPreference = 'Stop'

$RepoRoot   = $PSScriptRoot
$ClaudeSrc  = Join-Path $RepoRoot 'claude'
$SharedSrc  = Join-Path $RepoRoot 'shared'
$HomeDir    = $env:USERPROFILE
$ClaudeDir  = Join-Path $HomeDir '.claude'
$ClaudeJson = Join-Path $HomeDir '.claude.json'
$HooksSrc   = Join-Path $ClaudeSrc 'hooks'

Write-Host ""
Write-Host "=== llm-settings installer ===" -ForegroundColor Cyan
Write-Host "Repo     : $RepoRoot"
Write-Host "Target   : $ClaudeDir"
Write-Host ""

# ---------- 1. Developer Mode check ----------

function Test-DeveloperMode {
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
    $v = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
    if ($v -and $v.AllowDevelopmentWithoutDevLicense -eq 1) { return $true }
    return $false
}

if (-not (Test-DeveloperMode)) {
    Write-Host "ERROR: Windows Developer Mode is OFF." -ForegroundColor Red
    Write-Host ""
    Write-Host "Symlinks to %USERPROFILE%\.claude\ require one of:"
    Write-Host "  (a) Developer Mode enabled (recommended)"
    Write-Host "  (b) this script run as Administrator"
    Write-Host ""
    Write-Host "Enable Developer Mode with: start ms-settings:developers"
    Write-Host "Then toggle 'Developer Mode' on and re-run this script."
    Write-Host ""
    exit 1
}

# ---------- 2. Prereqs ----------

function Test-Command($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function Install-WingetPkg($id, $friendly) {
    Write-Host "  winget install $friendly ($id)" -ForegroundColor DarkGray
    $p = Start-Process -FilePath winget -ArgumentList @(
        'install', '--id', $id,
        '--silent',
        '--accept-package-agreements',
        '--accept-source-agreements'
    ) -Wait -NoNewWindow -PassThru
    # 0 = installed, -1978335189 / 0x8A15002B = already installed
    if ($p.ExitCode -ne 0 -and $p.ExitCode -ne -1978335189) {
        Write-Warning "    winget exit code: $($p.ExitCode) (continuing)"
    }
}

function Sync-Path {
    $m = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
    $u = [Environment]::GetEnvironmentVariable('PATH', 'User')
    $env:PATH = "$m;$u"
}

if (-not $SkipPrereqs) {
    Write-Host "--- Installing prerequisites ---" -ForegroundColor Yellow
    if (-not (Test-Command 'winget')) {
        Write-Warning "winget is not available. Install 'App Installer' from the Microsoft Store, then re-run."
        exit 1
    }

    if (-not (Test-Command 'node'))   { Install-WingetPkg 'OpenJS.NodeJS.LTS'   'Node.js LTS' } else { Write-Host "  node: already installed" }
    if (-not (Test-Command 'gh'))     { Install-WingetPkg 'GitHub.cli'          'GitHub CLI' }  else { Write-Host "  gh: already installed" }
    if (-not (Test-Command 'pwsh'))   { Install-WingetPkg 'Microsoft.PowerShell' 'PowerShell 7' } else { Write-Host "  pwsh: already installed" }

    # Real Python (not the MS Store stub)
    $pythonOk = $false
    $pyCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pyCmd -and $pyCmd.Source -notlike '*WindowsApps*') { $pythonOk = $true }
    if (-not $pythonOk) { Install-WingetPkg 'Python.Python.3.12' 'Python 3.12' } else { Write-Host "  python: already installed" }

    Sync-Path

    # uv / uvx (winget keeps it on PATH globally, unlike `pip install --user`)
    if (-not (Test-Command 'uv') -and -not (Test-Command 'uvx')) {
        Install-WingetPkg 'astral-sh.uv' 'uv'
        Sync-Path
    } else { Write-Host "  uv/uvx: already installed" }

    # elan (Lean toolchain) - only if requested
    if (-not $SkipLean) {
        if (-not (Test-Command 'elan')) {
            Write-Host "  installing elan (Lean toolchain)" -ForegroundColor DarkGray
            try {
                $resp = Invoke-WebRequest -Uri 'https://elan.lean-lang.org/elan-init.ps1' -UseBasicParsing
                $elanScript = $resp.Content
                # PS 5.1 with -UseBasicParsing can hand back a byte[] when the
                # response has no declared charset. Decode to string for IEX.
                if ($elanScript -is [byte[]]) {
                    $elanScript = [System.Text.Encoding]::UTF8.GetString($elanScript)
                }
                Invoke-Expression -Command $elanScript
                Sync-Path
            } catch {
                Write-Warning "    elan install failed - $($_.Exception.Message). Install manually from https://lean-lang.org"
            }
        } else { Write-Host "  elan: already installed" }
    }

    Write-Host ""
}

# ---------- 2.5 Git tooling overrides ----------
# Git for Windows ships its own gpg.exe and ssh.exe under Git\usr\bin\ that
# can't reach the Windows-native ssh-agent or the Gpg4win keyring. Point git
# at the system binaries when present so signed commits and SSH push work
# out of the box on a fresh STEM machine.

function Set-GitToolingOverride {
    param(
        [Parameter(Mandatory)] [string]$Key,
        [Parameter(Mandatory)] [string]$Target
    )
    if (-not (Test-Path $Target)) {
        Write-Host "  $Key`: target not found at $Target, skipping"
        return
    }
    $current = (& git config --global --get $Key 2>$null) | Select-Object -First 1
    if ($current) {
        $normalizedCurrent = ($current -replace '\\','/').Trim()
        $normalizedTarget  = ($Target  -replace '\\','/').Trim()
        if ($normalizedCurrent -ieq $normalizedTarget) {
            Write-Host "  $Key`: already set to $current"
            return
        }
        $isBundled = $normalizedCurrent -imatch '/Git/usr/bin/'
        if (-not $isBundled) {
            Write-Warning "  $Key`: already set to non-bundled '$current'. Leaving as-is."
            return
        }
        Write-Host "  $Key`: replacing bundled '$current' with '$Target'"
    } else {
        Write-Host "  $Key`: setting to $Target"
    }
    & git config --global $Key $Target
}

if (Test-Command 'git') {
    Write-Host "--- Configuring git tooling overrides ---" -ForegroundColor Yellow
    Set-GitToolingOverride -Key 'gpg.program'     -Target 'C:\Program Files\GnuPG\bin\gpg.exe'
    Set-GitToolingOverride -Key 'core.sshCommand' -Target 'C:\Windows\System32\OpenSSH\ssh.exe'
    Write-Host ""
}

# ---------- 3. Create symlinks ----------

function New-Link {
    param(
        [string]$Source,
        [string]$Target
    )
    if (-not (Test-Path $Source)) {
        Write-Warning "  source missing, skipping: $Source"
        return
    }
    if (Test-Path $Target) {
        $item = Get-Item $Target -Force
        if ($item.LinkType -eq 'SymbolicLink' -or $item.LinkType -eq 'Junction') {
            Remove-Item $Target -Force -Recurse:$false
        } else {
            $bak = "$Target.bak"
            if (Test-Path $bak) { Remove-Item $bak -Recurse -Force }
            Move-Item $Target $bak -Force
            Write-Host "  backup: $Target -> $bak" -ForegroundColor DarkGray
        }
    }
    # Try New-Item first. PS 5.1's SymbolicLink provider requires
    # SeCreateSymbolicLinkPrivilege on the calling token. On STEM domain-joined
    # machines that privilege is suppressed by GPO even with Developer Mode on,
    # so we fall back to `cmd /c mklink`, which calls CreateSymbolicLinkW with
    # SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE and works under Dev Mode
    # without the privilege.
    try {
        $null = New-Item -ItemType SymbolicLink -Path $Target -Target $Source -Force -ErrorAction Stop
    } catch {
        $isDir = (Get-Item $Source -Force).PSIsContainer
        $flag  = if ($isDir) { '/D ' } else { '' }
        $cmd   = "mklink $flag`"$Target`" `"$Source`""
        $output = & cmd.exe /c $cmd 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "mklink failed for '$Target' -> '$Source': $output"
        }
    }
    Write-Host "  linked: $Target -> $Source"
}

Write-Host "--- Linking into $ClaudeDir ---" -ForegroundColor Yellow
if (-not (Test-Path $ClaudeDir)) {
    $null = New-Item -ItemType Directory -Path $ClaudeDir
}

New-Link -Source (Join-Path $ClaudeSrc 'settings.json') -Target (Join-Path $ClaudeDir 'settings.json')
New-Link -Source (Join-Path $ClaudeSrc 'CLAUDE.md')     -Target (Join-Path $ClaudeDir 'CLAUDE.md')
New-Link -Source (Join-Path $SharedSrc 'skills')        -Target (Join-Path $ClaudeDir 'skills')
New-Link -Source (Join-Path $ClaudeSrc 'rules')         -Target (Join-Path $ClaudeDir 'rules')
New-Link -Source (Join-Path $ClaudeSrc 'commands')      -Target (Join-Path $ClaudeDir 'commands')
if (Test-Path $HooksSrc) {
    New-Link -Source $HooksSrc -Target (Join-Path $ClaudeDir 'hooks')
}

Write-Host ""

# ---------- 4. Project memory ----------

$SharedMemory = Join-Path $SharedSrc 'memory'
if (Test-Path $SharedMemory) {
    Write-Host "--- Linking per-project memory files ---" -ForegroundColor Yellow
    Get-ChildItem -Directory $SharedMemory | ForEach-Object {
        $projectName = $_.Name
        $targetDir = Join-Path $ClaudeDir "projects\$projectName\memory"
        if (-not (Test-Path $targetDir)) {
            $null = New-Item -ItemType Directory -Path $targetDir -Force
        }
        Get-ChildItem -File -Filter '*.md' $_.FullName | ForEach-Object {
            New-Link -Source $_.FullName -Target (Join-Path $targetDir $_.Name)
        }
    }
    Write-Host ""
}

# ---------- 5. MCP servers merge ----------

if (-not $SkipMcp) {
    $ServersJson = Join-Path $SharedSrc 'mcp\servers.json'
    if (Test-Path $ServersJson) {
        Write-Host "--- Merging MCP servers into $ClaudeJson ---" -ForegroundColor Yellow
        $newServers = (Get-Content $ServersJson -Raw | ConvertFrom-Json).mcpServers

        if (Test-Path $ClaudeJson) {
            $existing = Get-Content $ClaudeJson -Raw | ConvertFrom-Json
        } else {
            $existing = [pscustomobject]@{}
        }

        if ($existing.PSObject.Properties['mcpServers']) {
            $existing.mcpServers = $newServers
        } else {
            $existing | Add-Member -NotePropertyName mcpServers -NotePropertyValue $newServers
        }

        # PS 5.1 ConvertTo-Json: set depth high to avoid flattening
        $json = $existing | ConvertTo-Json -Depth 100
        Set-Content -Path $ClaudeJson -Value $json -Encoding utf8
        Write-Host "  merged $($newServers.PSObject.Properties.Name -join ', ')"
        Write-Host ""
    }
}

# ---------- 6. Done ----------

Write-Host "=== Install complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Run 'gh auth login' to authenticate the GitHub CLI."
Write-Host "  2. Open a NEW terminal so PATH changes take effect."
Write-Host "  3. If you installed pwsh, launch Claude Code from pwsh for best results."
Write-Host "  4. Test MCP servers by opening Claude Code and checking ~/.claude.json."
Write-Host ""

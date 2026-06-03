#Requires -Version 7
$ErrorActionPreference = 'Stop'

# gate.ps1 -- mechanical gate for fix/0123-cache-restore-non-fatal (standards #123).
# Ephemeral: created at branch setup, dropped in the final commit before the PR
# is marked ready. ASCII-only on purpose (PSScriptAnalyzer's
# PSUseBOMForUnicodeEncodedFile rule requires a BOM for non-ASCII .ps1 files).
#
# This PR edits the reusable .github/workflows/dotnet-ci.yml plus two standards
# docs (CI.md, MIGRATION.md). The repo's own CI (.github/workflows/ci.yml)
# parses shared/templates/** but NOT .github/workflows/**, so a malformed edit
# to the reusable workflow would slip past CI -- this gate parses it locally.
#
# The fix commit extends this file with the #123 behaviour invariants.

Write-Host '== gate: git diff --check (whitespace) =='
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'git diff --check reported whitespace errors' }

Write-Host '== gate: parse .github/workflows/*.yml =='
$haveYaml = $false
if (Get-Module -ListAvailable powershell-yaml) {
    $haveYaml = $true
} else {
    try {
        Install-Module powershell-yaml -Force -Scope CurrentUser -ErrorAction Stop
        $haveYaml = $true
    } catch {
        Write-Warning "powershell-yaml unavailable ($($_.Exception.Message)); falling back to a lexical check."
    }
}
if ($haveYaml) { Import-Module powershell-yaml }
foreach ($f in Get-ChildItem -Path .github/workflows -Filter *.yml -File) {
    $text = [System.IO.File]::ReadAllText($f.FullName)
    if ($haveYaml) {
        try {
            [void](ConvertFrom-Yaml -Yaml $text)
            Write-Host "  ok (parsed): $($f.Name)"
        } catch {
            throw "YAML parse failed for $($f.Name): $($_.Exception.Message)"
        }
    } else {
        # Lexical floor: indentation must be spaces, never hard tabs.
        if ($text -match "(?m)^\t") { throw "$($f.Name): hard tab in indentation" }
        Write-Host "  ok (lexical): $($f.Name)"
    }
}

Write-Host '== gate: standards-doc structure (H1 + Stability marker) =='
$docs = Get-ChildItem -Path shared/standards -Filter *.md -File
foreach ($d in $docs) {
    $name  = [System.IO.Path]::GetFileNameWithoutExtension($d.Name)
    $lines = Get-Content $d.FullName
    if ($lines.Count -lt 3) { throw "shared/standards/$($d.Name): too short (need H1 + Stability)" }
    if ($lines[0].TrimEnd() -ne "# Standard: $name") {
        throw "shared/standards/$($d.Name): line 1 must be '# Standard: $name', got '$($lines[0])'"
    }
    $head = $lines | Select-Object -First 10
    if (-not ($head -match '^> \*\*Stability:\*\*')) {
        throw "shared/standards/$($d.Name): missing '> **Stability:** ...' in first 10 lines"
    }
}
Write-Host "  ok: $($docs.Count) standards docs"

Write-Host 'gate: PASS'

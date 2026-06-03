#Requires -Version 7
$ErrorActionPreference = 'Stop'

# Mechanical commit gate for the #122 mirror-bitbucket tag fix.
# Replicates the slices of this repo's CI (.github/workflows/ci.yml) that the
# ticket touches: whitespace hygiene, workflow/template YAML parsing, and the
# standards-doc structure check. CI additionally runs PSScriptAnalyzer and the
# Pester rollout smoke; both stay green for a config+docs change.

Write-Host '== gate: git diff --check =='
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'git diff --check found whitespace/conflict errors' }

# Placeholder substitution mirrors the CI "Templates parse" job, so the stub
# templates are validated exactly as an adopted repo would receive them.
$placeholders = @{
    '{{App}}'             = 'TestApp'
    '{{Repo}}'            = 'test-repo'
    '{{Archetype}}'       = 'A'
    '{{Owner}}'           = 'test-owner'
    '{{LucaUser}}'        = 'test-luca'
    '{{StandardVersion}}' = 'v0.0.0'
    '{{Author}}'          = 'Test Author'
    '{{Description}}'     = 'test description'
    '{{Year}}'            = '2026'
}
function Expand-Placeholder {
    param([string]$Text)
    foreach ($key in $placeholders.Keys) { $Text = $Text.Replace($key, $placeholders[$key]) }
    return $Text
}

Import-Module powershell-yaml -ErrorAction Stop

Write-Host '== gate: workflow + template YAML parses =='
$root = (Get-Location).Path
$yamlFiles = @(
    Get-ChildItem -Path '.github/workflows' -Recurse -File -Include *.yml, *.yaml
    Get-ChildItem -Path 'shared/templates'  -Recurse -File -Include *.yml, *.yaml
)
$yamlFailed = $false
foreach ($file in $yamlFiles) {
    $rel     = [System.IO.Path]::GetRelativePath($root, $file.FullName)
    $content = Expand-Placeholder ([System.IO.File]::ReadAllText($file.FullName))
    try {
        [void](ConvertFrom-Yaml -Yaml $content)
        Write-Host "ok: $rel"
    } catch {
        Write-Host "FAIL: $rel -- $($_.Exception.Message)"
        $yamlFailed = $true
    }
}
if ($yamlFailed) { throw 'workflow/template YAML parse failures' }

Write-Host '== gate: standards-doc structure =='
$docFailed = $false
foreach ($doc in (Get-ChildItem -Path 'shared/standards' -Filter *.md -File)) {
    $name  = [System.IO.Path]::GetFileNameWithoutExtension($doc.Name)
    $lines = Get-Content $doc.FullName
    if ($lines.Count -lt 3 -or $lines[0].TrimEnd() -ne "# Standard: $name") {
        Write-Host "FAIL: shared/standards/$($doc.Name) -- bad H1 (expected '# Standard: $name')"
        $docFailed = $true
        continue
    }
    $head = $lines | Select-Object -First 10
    if (-not ($head -match '^> \*\*Stability:\*\*')) {
        Write-Host "FAIL: shared/standards/$($doc.Name) -- missing '> **Stability:** ...' line"
        $docFailed = $true
    }
}
if ($docFailed) { throw 'standards-doc structure failures' }

Write-Host 'gate: PASS'

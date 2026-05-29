#!/usr/bin/env pwsh
# Ephemeral commit gate for PR #94 (F#-specific shapes in cross-repo standards).
# Mirrors .github/workflows/ci.yml. Removed in a dedicated
# `chore: drop gate.ps1` commit before the PR is marked ready.
#Requires -Version 7.0
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $repoRoot
try {
    Write-Host '== PSScriptAnalyzer ==' -ForegroundColor Cyan
    Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSScriptAnalyzerSettings.psd1 -EnableExit

    Write-Host '== Pester ==' -ForegroundColor Cyan
    Invoke-Pester -Path eng/tests -CI

    Write-Host 'gate.ps1: PASS' -ForegroundColor Green
}
finally {
    Pop-Location
}

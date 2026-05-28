#Requires -Version 7
$ErrorActionPreference = 'Stop'

# Universal: catch whitespace errors in the diff.
git diff --check

# Standards repo local equivalent of CI's static checks: the Pester suite
# in eng/tests/ validates rollout, archetype overlay, idempotency, and
# -Minimal lock preservation. See feedback-standards-repo-prepush-check.
Import-Module Pester -RequiredVersion 5.7.1
$result = Invoke-Pester -Path eng/tests/Apply-RepoStandard.Tests.ps1 -Output Detailed -PassThru
if ($result.FailedCount -gt 0) {
    throw "Pester: $($result.FailedCount) failed test(s)."
}

# Ticket #113: assert the new category-filter input is wired through both
# dotnet test invocations in dotnet-ci.yml.
$ci = Get-Content -Raw .github/workflows/dotnet-ci.yml
if ($ci -notmatch '(?ms)inputs:\s*\r?\n\s*category-filter:') {
    throw "dotnet-ci.yml: missing 'category-filter' input."
}
$dotnetTestLines = Select-String -Path .github/workflows/dotnet-ci.yml -Pattern '\bdotnet test\b'
foreach ($line in $dotnetTestLines) {
    if ($line.Line -notmatch '--filter') {
        throw "dotnet-ci.yml line $($line.LineNumber): 'dotnet test' missing --filter."
    }
}

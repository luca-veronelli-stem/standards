#requires -Version 5.1
#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

# Smoke test for eng/apply-repo-standard.ps1 -- the rollout script that copies
# templates and standards into adopted repos and substitutes {{Placeholder}}
# tokens. Exercises the script end-to-end against a throwaway repo and asserts
# the output shape; does not unit-test internal helpers.

Describe 'apply-repo-standard.ps1 (smoke)' {

    BeforeAll {
        # Pester v5 runs Describe blocks in a separate runspace, so resolve
        # paths inside BeforeAll rather than at script top.
        $script:rolloutPs1 = Resolve-Path (Join-Path $PSScriptRoot '..\apply-repo-standard.ps1')

        $script:target = Join-Path ([System.IO.Path]::GetTempPath()) `
            "stem-rollout-smoke-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $script:target -Force | Out-Null

        # The rollout requires .git/ in the target. A bare init is enough --
        # no commits or remotes needed for the rollout to operate.
        Push-Location $script:target
        try {
            git init --quiet 2>&1 | Out-Null
        } finally {
            Pop-Location
        }

        # Bootstrap with a full param set. Archetype A so the overlay path is
        # also exercised (release.yml).
        & $script:rolloutPs1 `
            -RepoPath        $script:target `
            -App             'SmokeApp' `
            -Repo            'smoke-repo' `
            -Archetype       'A' `
            -Owner           'smoke-owner' `
            -LucaUser        'smoke-luca' `
            -StandardVersion 'v0.0.0-smoke' `
            -Description     'Smoke test fixture' 6>&1 | Out-Null
        $script:exit1 = $LASTEXITCODE
    }

    AfterAll {
        if ($script:target -and (Test-Path $script:target)) {
            Remove-Item $script:target -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'exits zero on first run' {
        $script:exit1 | Should -Be 0
    }

    It 'writes .stem-standard.json with the passed config' {
        $cfg = Get-Content (Join-Path $script:target '.stem-standard.json') -Raw | ConvertFrom-Json
        $cfg.app             | Should -Be 'SmokeApp'
        $cfg.repo            | Should -Be 'smoke-repo'
        $cfg.archetype       | Should -Be 'A'
        $cfg.owner           | Should -Be 'smoke-owner'
        $cfg.lucaUser        | Should -Be 'smoke-luca'
        $cfg.standardVersion | Should -Be 'v0.0.0-smoke'
    }

    It 'writes .stem-standard.lock with file hashes' {
        $lockPath = Join-Path $script:target '.stem-standard.lock'
        $lockPath | Should -Exist
        $lock = Get-Content $lockPath -Raw | ConvertFrom-Json
        $lock.standardVersion                 | Should -Be 'v0.0.0-smoke'
        $lock.files.PSObject.Properties.Count | Should -BeGreaterThan 0
    }

    It 'copies common templates (verbatim and substituted)' {
        Join-Path $script:target 'Directory.Build.props' | Should -Exist
        Join-Path $script:target 'global.json'           | Should -Exist
        $claude = Get-Content (Join-Path $script:target 'CLAUDE.md') -Raw
        $claude | Should -Match 'SmokeApp'
        $claude | Should -Not -Match '\{\{App\}\}'
    }

    It 'applies the archetype A overlay (release.yml)' {
        Join-Path $script:target '.github/workflows/release.yml' | Should -Exist
        $release = Get-Content (Join-Path $script:target '.github/workflows/release.yml') -Raw
        $release | Should -Match 'smoke-repo'
        $release | Should -Not -Match '\{\{Repo\}\}'
    }

    It 'copies all 17 standards under docs/Standards/' {
        $docs = Join-Path $script:target 'docs/Standards'
        $docs | Should -Exist
        (Get-ChildItem -Path $docs -Filter *.md -File `
            | Where-Object { $_.Name -ne 'README.md' }).Count `
            | Should -Be 17
        Join-Path $docs 'REPO_STRUCTURE.md' | Should -Exist
    }

    It 'generates docs/Standards/README.md with the standards table' {
        $indexPath = Join-Path $script:target 'docs/Standards/README.md'
        $indexPath | Should -Exist
        $index = Get-Content $indexPath -Raw
        $index | Should -Match 'v0\.0\.0-smoke'
        $index | Should -Match '\| \[REPO_STRUCTURE\.md\]'
    }

    It 'is idempotent on re-run with the same parameters' {
        & $script:rolloutPs1 `
            -RepoPath        $script:target `
            -App             'SmokeApp' `
            -Repo            'smoke-repo' `
            -Archetype       'A' `
            -Owner           'smoke-owner' `
            -LucaUser        'smoke-luca' `
            -StandardVersion 'v0.0.0-smoke' `
            -Description     'Smoke test fixture' 6>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
}

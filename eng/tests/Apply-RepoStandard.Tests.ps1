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

    It 'copies all 19 standards under docs/Standards/' {
        $docs = Join-Path $script:target 'docs/Standards'
        $docs | Should -Exist
        (Get-ChildItem -Path $docs -Filter *.md -File `
            | Where-Object { $_.Name -ne 'README.md' }).Count `
            | Should -Be 19
        Join-Path $docs 'REPO_STRUCTURE.md' | Should -Exist
    }

    It 'generates docs/Standards/README.md with the standards table' {
        $indexPath = Join-Path $script:target 'docs/Standards/README.md'
        $indexPath | Should -Exist
        $index = Get-Content $indexPath -Raw
        $index | Should -Match 'v0\.0\.0-smoke'
        $index | Should -Match '\| \[REPO_STRUCTURE\.md\]'
    }

    It 'copies Poppins fonts into the per-app GUI project (path placeholders + binary copy)' {
        # Exercises two rollout behaviours together:
        #   - path-segment placeholder substitution (`{{App}}` -> SmokeApp in
        #     archetypes/A/src/{{App}}.GUI/...)
        #   - binary file handling (TTF must not be UTF-8/LF-normalized).
        $fontsDir = Join-Path $script:target 'src/SmokeApp.GUI/Resources/fonts'
        $fontsDir | Should -Exist
        foreach ($weight in @('Light','Regular','Medium','SemiBold','Bold')) {
            $ttf = Join-Path $fontsDir "Poppins-$weight.ttf"
            $ttf | Should -Exist
            $magic = [System.IO.File]::ReadAllBytes($ttf)[0..3]
            ($magic[0] -eq 0 -and $magic[1] -eq 1 -and $magic[2] -eq 0 -and $magic[3] -eq 0) `
                | Should -BeTrue -Because 'binary copy must preserve TrueType magic (00 01 00 00)'
        }
        Join-Path $fontsDir 'OFL.txt' | Should -Exist
    }

    It 'lays down the archetype A greenfield scaffold (slnx + Core + Tests)' {
        # The scaffold is what makes the bootstrap PR green on CI without
        # a hand-rolled follow-up: rollout emits Core + Tests + .slnx, dotnet-ci
        # finds them, build/restore/test succeed.
        $slnx = Get-Content (Join-Path $script:target 'Stem.SmokeApp.slnx') -Raw
        $slnx | Should -Match 'src/SmokeApp\.Core/SmokeApp\.Core\.fsproj'
        $slnx | Should -Match 'tests/SmokeApp\.Tests/SmokeApp\.Tests\.fsproj'
        $slnx | Should -Not -Match '\{\{App\}\}'

        $coreProj = Get-Content (Join-Path $script:target 'src/SmokeApp.Core/SmokeApp.Core.fsproj') -Raw
        $coreProj | Should -Match '<RootNamespace>Stem\.SmokeApp\.Core</RootNamespace>'
        $coreProj | Should -Match '<PackageReference Include="FSharp\.Core" />'
        $coreProj | Should -Not -Match '\{\{App\}\}'

        $coreFs = Get-Content (Join-Path $script:target 'src/SmokeApp.Core/Placeholder.fs') -Raw
        $coreFs | Should -Match 'module Stem\.SmokeApp\.Core\.Placeholder'

        $testsProj = Get-Content (Join-Path $script:target 'tests/SmokeApp.Tests/SmokeApp.Tests.fsproj') -Raw
        $testsProj | Should -Match '<RootNamespace>Stem\.SmokeApp\.Tests</RootNamespace>'
        $testsProj | Should -Match '<GenerateProgramFile>true</GenerateProgramFile>' `
            -Because 'F#-on-xunit test discovery on .NET 10 needs the SDK-generated Program.fs'
        $testsProj | Should -Match '<ProjectReference Include="\.\./\.\./src/SmokeApp\.Core/SmokeApp\.Core\.fsproj" />'
        $testsProj | Should -Not -Match '\{\{App\}\}'

        $testsFs = Get-Content (Join-Path $script:target 'tests/SmokeApp.Tests/PlaceholderTests.fs') -Raw
        $testsFs | Should -Match 'module Stem\.SmokeApp\.Tests\.PlaceholderTests'
        $testsFs | Should -Match 'open Stem\.SmokeApp\.Core'
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

Describe 'apply-repo-standard.ps1 (scaffold preservation)' {

    # The greenfield scaffold is seed code: once the adopter starts editing
    # Placeholder.fs (or deletes it entirely), the rollout must not revert
    # or recreate it. Bootstrap-only protection enforces this. Separate
    # Describe so the fixture is independent of the main smoke run.
    BeforeAll {
        $script:rolloutPs1 = Resolve-Path (Join-Path $PSScriptRoot '..\apply-repo-standard.ps1')

        $script:preserveTarget = Join-Path ([System.IO.Path]::GetTempPath()) `
            "stem-rollout-preserve-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $script:preserveTarget -Force | Out-Null

        Push-Location $script:preserveTarget
        try {
            git init --quiet 2>&1 | Out-Null
        } finally {
            Pop-Location
        }

        # First run: scaffold lands.
        & $script:rolloutPs1 `
            -RepoPath        $script:preserveTarget `
            -App             'PreserveApp' `
            -Repo            'preserve-repo' `
            -Archetype       'A' `
            -Owner           'preserve-owner' `
            -LucaUser        'preserve-luca' `
            -StandardVersion 'v0.0.0-smoke' `
            -Description     'Preservation fixture' 6>&1 | Out-Null

        # Adopter writes real code over Placeholder.fs, and deletes the test
        # placeholder entirely after wiring up their own first test module.
        $script:realCore = "module Stem.PreserveApp.Core.RealModule`n`nlet value = 42`n"
        Set-Content -Path (Join-Path $script:preserveTarget 'src/PreserveApp.Core/Placeholder.fs') `
            -Value $script:realCore -NoNewline
        Remove-Item (Join-Path $script:preserveTarget 'tests/PreserveApp.Tests/PlaceholderTests.fs') -Force

        # Second run.
        & $script:rolloutPs1 `
            -RepoPath        $script:preserveTarget `
            -App             'PreserveApp' `
            -Repo            'preserve-repo' `
            -Archetype       'A' `
            -Owner           'preserve-owner' `
            -LucaUser        'preserve-luca' `
            -StandardVersion 'v0.0.0-smoke' `
            -Description     'Preservation fixture' 6>&1 | Out-Null
        $script:preserveExit = $LASTEXITCODE
    }

    AfterAll {
        if ($script:preserveTarget -and (Test-Path $script:preserveTarget)) {
            Remove-Item $script:preserveTarget -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 're-run exits zero' {
        $script:preserveExit | Should -Be 0
    }

    It 'does not clobber adopter-edited Placeholder.fs' {
        $disk = Get-Content (Join-Path $script:preserveTarget 'src/PreserveApp.Core/Placeholder.fs') -Raw
        $disk | Should -Be $script:realCore
    }

    It 'does not recreate adopter-deleted PlaceholderTests.fs' {
        Join-Path $script:preserveTarget 'tests/PreserveApp.Tests/PlaceholderTests.fs' | Should -Not -Exist
    }
}

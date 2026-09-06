$runIntegration = $env:RUN_FONT_INTEGRATION_TESTS -eq '1'
$bucketDir = Join-Path $PSScriptRoot '..\..\bucket' -Resolve
$modulesDir = Join-Path $PSScriptRoot '..\Modules' -Resolve
$fontsDir = Join-Path $PSScriptRoot '..\Fonts' -Resolve

$targetManifests = @()
if ($env:FONT_INTEGRATION_MODULE) {
    $moduleFile = Join-Path $fontsDir "$($env:FONT_INTEGRATION_MODULE).psm1"
    if (-not (Test-Path $moduleFile)) {
        $availableModules = @(Get-ChildItem $fontsDir -Filter '*.psm1' | ForEach-Object { $_.BaseName })
        throw "Specified integration module not found: '$($env:FONT_INTEGRATION_MODULE)'. Available font modules: $($availableModules -join ', '). If you intended to test the font manifest '$($env:FONT_INTEGRATION_MODULE)', use `$env:FONT_INTEGRATION_MANIFEST instead."
    }
    Import-Module $moduleFile -Force
    $fn = "Get-$($env:FONT_INTEGRATION_MODULE)Fonts"
    if (-not (Get-Command -Name $fn -ErrorAction SilentlyContinue)) {
        $fn = "Get-$($env:FONT_INTEGRATION_MODULE)"
    }
    $declarations = & $fn
    $targetManifests = @($declarations.Keys)
} elseif ($env:FONT_INTEGRATION_MANIFEST) {
    $regex = $env:FONT_INTEGRATION_MANIFEST
    $targetManifests = @(Get-ChildItem $bucketDir -Filter '*.json' | Where-Object { $_.BaseName -match $regex } | ForEach-Object { $_.BaseName })
    if ($targetManifests.Count -eq 0) {
        Write-Warning "No bucket manifest matched regex '$regex'"
    }
} else {
    $targetManifests = @('JetBrainsMono')
}

Describe 'Generated font manifest installation' {
    BeforeAll {
        $bucketDir = Join-Path $PSScriptRoot '..\..\bucket' -Resolve
        $fontDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
        $modulesDir = Join-Path $PSScriptRoot '..\Modules' -Resolve
        Import-Module (Join-Path $modulesDir 'ManifestSources.psm1') -Force
        Import-Module (Join-Path $modulesDir 'ScoopArtifactCache.psm1') -Force
    }

    $testCases = @($targetManifests | ForEach-Object { @{ ManifestName = $_ } })
    It 'installs and uninstalls <ManifestName>' -TestCases $testCases -Skip:(-not $runIntegration) {
        param($ManifestName)

        $manifestPath = Join-Path $bucketDir "$ManifestName.json"
        if (-not (Test-Path $manifestPath)) {
            throw "Manifest file not found: $manifestPath"
        }
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $filterRegex = if ($manifest.installer.script[0] -match '^\$filter\s*=\s*''([^'']+)''') { $matches[1] } else { "^$ManifestName" }

        $before = @(Get-ChildItem $fontDirectory -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $filterRegex })
        if ($before.Count -ne 0) {
            throw "Cannot run integration test because matching fonts are already installed: $($before.Name -join ', ')"
        }

        try {
            $scoopCachePath = Initialize-ScoopArtifactCache -App $ManifestName -Version $manifest.version -DownloadUrl $manifest.url -ExpectedHash $manifest.hash
            Write-Host "Initialized Scoop cache: $scoopCachePath"
            & scoop install "$manifestPath" --no-update-scoop
            if ($LASTEXITCODE -ne 0) {
                throw "scoop install failed with exit code $LASTEXITCODE"
            }

            $installed = @(Get-ChildItem $fontDirectory -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $filterRegex })
            $installed.Count | Should -BeGreaterThan 0
        } finally {
            & scoop uninstall "$ManifestName"
        }

        @(Get-ChildItem $fontDirectory -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $filterRegex }).Count | Should -Be 0
    }
}

Describe 'Installer failure handling' {
    BeforeAll {
        $bucketDir = Join-Path $PSScriptRoot '..\..\bucket' -Resolve
        $fontDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
        $modulesDir = Join-Path $PSScriptRoot '..\Modules' -Resolve
        Import-Module (Join-Path $modulesDir 'ManifestSources.psm1') -Force
        Import-Module (Join-Path $modulesDir 'ScoopArtifactCache.psm1') -Force
    }

    It 'aborts installation and leaves no fonts when filter matches zero files' -Skip:(-not $runIntegration) {
        $sampleName = if ($targetManifests.Count -gt 0) { $targetManifests[0] } else { 'CascadiaCodeNF' }
        $sampleManifestPath = Join-Path $bucketDir "$sampleName.json"
        if (-not (Test-Path $sampleManifestPath)) {
            throw "Manifest file not found: $sampleManifestPath"
        }
        $manifest = Get-Content $sampleManifestPath -Raw | ConvertFrom-Json
        $filterRegex = if ($manifest.installer.script[0] -match '^\$filter\s*=\s*''([^'']+)''') { $matches[1] } else { "^$sampleName" }

        $testAppName = "TestFilterMismatch-$sampleName"
        $tempManifestPath = Join-Path $env:TEMP "$testAppName.json"

        # Seed Scoop cache for the test app without network download
        Initialize-ScoopArtifactCache -App $testAppName `
            -Version $manifest.version `
            -DownloadUrl $manifest.url `
            -ExpectedHash $manifest.hash

        # Tamper installer filter in memory to an impossible pattern
        $manifest.installer.script[0] = '$filter = ''^NonExistentPattern.*\.ttf$'''
        $manifest | ConvertTo-Json -Depth 10 | Set-Content $tempManifestPath -Encoding utf8

        try {
            $scoopFailed = $false
            $errorOutput = $null
            try {
                $output = & scoop install "$tempManifestPath" --no-update-scoop 2>&1
                if (-not $? -or $LASTEXITCODE -ne 0) {
                    $scoopFailed = $true
                }
            } catch {
                $scoopFailed = $true
                $errorOutput = $_.ToString()
            }
            $allOutput = (@($output) + @($errorOutput)) -join "`n"

            $scoopFailed | Should -Be $true
            $allOutput | Should -Match 'Failed to find fonts to install\. Please recheck the filter\.'

            $installedFonts = @(Get-ChildItem $fontDirectory -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $filterRegex })
            $installedFonts.Count | Should -Be 0
        } finally {
            & scoop uninstall "$testAppName" 2>&1 | Out-Null
            Remove-Item $tempManifestPath -Force -ErrorAction SilentlyContinue
            Remove-Item (Join-Path $env:USERPROFILE "scoop\cache\$testAppName*") -Force -ErrorAction SilentlyContinue
        }
    }
}

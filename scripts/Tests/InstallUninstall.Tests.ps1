$runIntegration = $env:RUN_FONT_INTEGRATION_TESTS -eq '1'
$bucketDir = Join-Path $PSScriptRoot '..\..\bucket' -Resolve
$modulesDir = Join-Path $PSScriptRoot '..\Modules' -Resolve
$fontsDir = Join-Path $PSScriptRoot '..\Fonts' -Resolve

$targetManifests = @()
if ($env:FONT_INTEGRATION_MODULE) {
    $pattern = $env:FONT_INTEGRATION_MODULE
    $matchedModules = @(Get-ChildItem $fontsDir -Filter '*.psm1' | Where-Object { $_.BaseName -match $pattern } | Sort-Object Name)
    if ($matchedModules.Count -eq 0) {
        $availableModules = @(Get-ChildItem $fontsDir -Filter '*.psm1' | ForEach-Object { $_.BaseName })
        throw "Specified integration module regex '$pattern' did not match any font modules. Available font modules: $($availableModules -join ', '). If you intended to test the font manifest '$pattern', use `$env:FONT_INTEGRATION_MANIFEST instead."
    }
    foreach ($module in $matchedModules) {
        Import-Module $module.FullName -Force
        $fn = "Get-$($module.BaseName)Resources"
        $declarations = & $fn
        $targetManifests += @($declarations.Keys)
    }
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

        $beforeFiles = @(Get-ChildItem $fontDirectory -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)

        $baseName = ($ManifestName -replace '-(OTF|TTF|Variable|unhinted).*$', '')
        $preExisting = @($beforeFiles | Where-Object { $_ -match "^$baseName" })
        if ($preExisting.Count -ne 0) {
            throw "Cannot run integration test because matching fonts are already installed: $($preExisting -join ', ')"
        }

        $addedFiles = @()
        try {
            $scoopCachePath = Initialize-ScoopArtifactCache -App $ManifestName -Version $manifest.version -DownloadUrl $manifest.url -ExpectedHash $manifest.hash
            Write-Host "Initialized Scoop cache: $scoopCachePath"
            & scoop install "$manifestPath" --no-update-scoop
            if ($LASTEXITCODE -ne 0) {
                throw "scoop install failed with exit code $LASTEXITCODE"
            }

            $afterInstall = @(Get-ChildItem $fontDirectory -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
            $addedFiles = @($afterInstall | Where-Object { $_ -notin $beforeFiles })
            $addedFiles.Count | Should -BeGreaterThan 0
        } finally {
            & scoop uninstall "$ManifestName"
        }

        $afterUninstall = @(Get-ChildItem $fontDirectory -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
        $remaining = @($afterUninstall | Where-Object { $_ -in $addedFiles })
        $remaining.Count | Should -Be 0
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
        $sampleName = if ($targetManifests.Count -gt 0) { $targetManifests[0] } else { 'CascadiaCode' }
        $sampleManifestPath = Join-Path $bucketDir "$sampleName.json"
        if (-not (Test-Path $sampleManifestPath)) {
            throw "Manifest file not found: $sampleManifestPath"
        }
        $manifest = Get-Content $sampleManifestPath -Raw | ConvertFrom-Json

        $testAppName = "TestFilterMismatch-$sampleName"
        $tempManifestPath = Join-Path $env:TEMP "$testAppName.json"

        # Seed Scoop cache for the test app without network download
        Initialize-ScoopArtifactCache -App $testAppName `
            -Version $manifest.version `
            -DownloadUrl $manifest.url `
            -ExpectedHash $manifest.hash

        # Tamper installer filter in memory to an impossible pattern
        $manifest.installer.script = @($manifest.installer.script | ForEach-Object {
                if ($_ -match '^\$filter\s*=') {
                    '$filter = ''^NonExistentPattern.*\.ttf$'''
                } else {
                    $_
                }
            })
        $manifest | ConvertTo-Json -Depth 10 | Set-Content $tempManifestPath -Encoding utf8

        $beforeCount = @(Get-ChildItem $fontDirectory -File -ErrorAction SilentlyContinue).Count

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

            @(Get-ChildItem $fontDirectory -File -ErrorAction SilentlyContinue).Count | Should -Be $beforeCount
        } finally {
            & scoop uninstall "$testAppName" 2>&1 | Out-Null
            Remove-Item $tempManifestPath -Force -ErrorAction SilentlyContinue
            Remove-Item (Join-Path $env:USERPROFILE "scoop\cache\$testAppName*") -Force -ErrorAction SilentlyContinue
        }
    }
}

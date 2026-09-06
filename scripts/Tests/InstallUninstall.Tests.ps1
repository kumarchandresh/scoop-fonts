$runIntegration = $env:RUN_FONT_INTEGRATION_TESTS -eq '1'
$bucketDir = Join-Path $PSScriptRoot '..\..\bucket' -Resolve
$modulesDir = Join-Path $PSScriptRoot '..\Modules' -Resolve

$targetManifests = @()
if ($env:FONT_INTEGRATION_MODULE) {
    $moduleFile = Join-Path $modulesDir "$($env:FONT_INTEGRATION_MODULE).psm1"
    if (-not (Test-Path $moduleFile)) {
        $availableModules = @(Get-ChildItem $modulesDir -Filter '*.psm1' | Where-Object { $_.BaseName -notmatch '^(Manifest|ScoopArtifactCache)' } | ForEach-Object { $_.BaseName })
        throw "Specified integration module not found: '$($env:FONT_INTEGRATION_MODULE)'. Available font modules: $($availableModules -join ', '). If you intended to test the font manifest '$($env:FONT_INTEGRATION_MODULE)', use `$env:FONT_INTEGRATION_MANIFEST instead."
    }
    Import-Module $moduleFile -Force
    $fn = "Get-$($env:FONT_INTEGRATION_MODULE)Fonts"
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

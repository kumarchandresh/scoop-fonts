$runIntegration = $env:RUN_FONT_INTEGRATION_TESTS -eq '1'
$bucketDir = Join-Path $PSScriptRoot '..\..\bucket' -Resolve
$fontDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$modulesDir = Join-Path $PSScriptRoot '..\Modules' -Resolve
Import-Module (Join-Path $modulesDir 'ManifestSources.psm1') -Force
Import-Module (Join-Path $modulesDir 'ScoopArtifactCache.psm1') -Force

$targetManifests = @()
if ($env:FONT_INTEGRATION_MODULE) {
    $moduleFile = Join-Path $modulesDir "$($env:FONT_INTEGRATION_MODULE).psm1"
    if (-not (Test-Path $moduleFile)) {
        throw "Specified integration module not found: $moduleFile"
    }
    Import-Module $moduleFile -Force
    $fn = "Get-$($env:FONT_INTEGRATION_MODULE)Fonts"
    $declarations = & $fn
    $targetManifests = @($declarations.Keys)
} elseif ($env:FONT_INTEGRATION_MANIFEST) {
    $patterns = @($env:FONT_INTEGRATION_MANIFEST -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $allBucketFiles = Get-ChildItem $bucketDir -Filter '*.json'
    foreach ($pattern in $patterns) {
        $matched = @($allBucketFiles | Where-Object { $_.BaseName -like $pattern -or $_.BaseName -match "^$pattern$" } | ForEach-Object { $_.BaseName })
        if ($matched.Count -eq 0) {
            Write-Warning "No bucket manifest matched '$pattern'"
        }
        $targetManifests += $matched
    }
    $targetManifests = @($targetManifests | Sort-Object -Unique)
} else {
    $targetManifests = @('JetBrainsMono')
}

Describe 'Generated font manifest installation' {
    foreach ($manifestName in $targetManifests) {
        It "installs and uninstalls $manifestName" -Skip:(-not $runIntegration) {
            $before = @(Get-ChildItem $fontDirectory -Filter "*$manifestName*" -ErrorAction SilentlyContinue)
            if ($before.Count -ne 0) {
                throw "Cannot run integration test because matching fonts are already installed: $($before.Name -join ', ')"
            }

            try {
                $manifestPath = Join-Path $bucketDir "$manifestName.json"
                if (-not (Test-Path $manifestPath)) {
                    throw "Manifest file not found: $manifestPath"
                }
                $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
                $scoopCachePath = Seed-ScoopArtifactCache -App $manifestName -Version $manifest.version -DownloadUrl $manifest.url -ExpectedHash $manifest.hash
                Write-Host "Seeded Scoop cache: $scoopCachePath"
                & scoop install "$manifestPath" --no-update-scoop
                if ($LASTEXITCODE -ne 0) {
                    throw "scoop install failed with exit code $LASTEXITCODE"
                }

                $installed = @(Get-ChildItem $fontDirectory -Filter "*$manifestName*" -ErrorAction SilentlyContinue)
                $installed.Count | Should BeGreaterThan 0
            } finally {
                & scoop uninstall "$manifestName"
            }

            @(Get-ChildItem $fontDirectory -Filter "*$manifestName*" -ErrorAction SilentlyContinue).Count | Should Be 0
        }
    }
}

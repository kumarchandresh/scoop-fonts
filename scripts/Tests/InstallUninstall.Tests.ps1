$runIntegration = $env:RUN_FONT_INTEGRATION_TESTS -eq '1'
$manifestName = if ($env:FONT_INTEGRATION_MANIFEST) { $env:FONT_INTEGRATION_MANIFEST } else { 'JetBrainsMono' }
$fontDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$modulesDir = Join-Path $PSScriptRoot '..\Modules' -Resolve
Import-Module (Join-Path $modulesDir 'ManifestSources.psm1') -Force
Import-Module (Join-Path $modulesDir 'ScoopArtifactCache.psm1') -Force

Describe 'Generated font manifest installation' {
    It "installs and uninstalls $manifestName" -Skip:(-not $runIntegration) {
        $before = @(Get-ChildItem $fontDirectory -Filter "*$manifestName*" -ErrorAction SilentlyContinue)
        if ($before.Count -ne 0) {
            throw "Cannot run integration test because matching fonts are already installed: $($before.Name -join ', ')"
        }

        try {
            $manifestPath = Join-Path $PSScriptRoot "..\..\bucket\$manifestName.json" -Resolve
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $scoopCachePath = Seed-ScoopArtifactCache -App $manifestName -Version $manifest.version -DownloadUrl $manifest.url -ExpectedHash $manifest.hash
            Write-Host "Seeded Scoop cache: $scoopCachePath"
            & scoop install "fonts/$manifestName"
            if ($LASTEXITCODE -ne 0) {
                throw "scoop install failed with exit code $LASTEXITCODE"
            }

            $installed = @(Get-ChildItem $fontDirectory -Filter "*$manifestName*" -ErrorAction SilentlyContinue)
            $installed.Count | Should BeGreaterThan 0
        } finally {
            & scoop uninstall "fonts/$manifestName"
        }

        @(Get-ChildItem $fontDirectory -Filter "*$manifestName*" -ErrorAction SilentlyContinue).Count | Should Be 0
    }
}

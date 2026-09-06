$runIntegration = $env:RUN_FONT_INTEGRATION_TESTS -eq '1'
$manifestName = if ($env:FONT_INTEGRATION_MANIFEST) { $env:FONT_INTEGRATION_MANIFEST } else { 'JetBrainsMono' }
$fontDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'

Describe 'Generated font manifest installation' {
    It "installs and uninstalls $manifestName" -Skip:(-not $runIntegration) {
        $before = @(Get-ChildItem $fontDirectory -Filter "*$manifestName*" -ErrorAction SilentlyContinue)
        if ($before.Count -ne 0) {
            throw "Cannot run integration test because matching fonts are already installed: $($before.Name -join ', ')"
        }

        try {
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

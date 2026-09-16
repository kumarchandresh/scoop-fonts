Import-Module (Join-Path $PSScriptRoot 'ManifestSources.psm1')

function Get-AllFontDeclarations {
    param(
        [Parameter()]
        [string]$FontsDirectory
    )

    if (-not $FontsDirectory) {
        $FontsDirectory = Join-Path $PSScriptRoot '..\Fonts' -Resolve
    }


    $allFonts = [ordered]@{}
    $fontModules = @(Get-ChildItem -LiteralPath $FontsDirectory -Filter '*.psm1' | Sort-Object Name)

    foreach ($module in $fontModules) {
        Import-Module -Force $module.FullName
        $fnName = "Get-$($module.BaseName)Resources"
        if (-not (Get-Command -Name $fnName -ErrorAction SilentlyContinue)) {
            Write-Warning "Could not find font declaration function '$fnName' in $($module.Name)"
            continue
        }
        $fontDeclarations = & $fnName
        foreach ($entry in $fontDeclarations.GetEnumerator()) {
            $allFonts[$entry.Key] = $entry.Value
        }
    }

    return $allFonts
}

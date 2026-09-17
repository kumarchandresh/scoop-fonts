Import-Module (Join-Path $PSScriptRoot 'ManifestSources.psm1')

function Get-AllFontDeclarations {
    param(
        [Parameter()]
        [string]$FontsDirectory,
        [Parameter()]
        [string]$ModuleFilter,
        [Parameter()]
        [switch]$Force
    )

    if (-not $FontsDirectory) {
        $FontsDirectory = Join-Path $PSScriptRoot '..\Fonts' -Resolve
    }

    $allFonts = [ordered]@{}
    $fontModules = @(Get-ChildItem -LiteralPath $FontsDirectory -Filter '*.psm1' | Sort-Object Name)

    if ($ModuleFilter) {
        $cleanFilter = $ModuleFilter -replace '\.psm1$', ''
        $fontModules = @($fontModules | Where-Object { $_.BaseName -like "*$cleanFilter*" })
    }

    foreach ($module in $fontModules) {
        Import-Module -Global -Force $module.FullName
        $fnName = "Get-$($module.BaseName)Resources"
        if (-not (Get-Command -Name $fnName -ErrorAction SilentlyContinue)) {
            Write-Warning "Could not find font declaration function '$fnName' in $($module.Name)"
            continue
        }
        $fontDeclarations = if ($module.BaseName -eq 'NerdFonts') {
            & $fnName -Force:$Force
        } else {
            & $fnName
        }
        foreach ($entry in $fontDeclarations.GetEnumerator()) {
            if ($entry.Value -is [System.Collections.IDictionary]) {
                $entry.Value['Module'] = $module.BaseName
            }
            $allFonts[$entry.Key] = $entry.Value
        }
    }

    return $allFonts
}


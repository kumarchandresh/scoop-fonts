function Get-AllFontDeclarations {
    param(
        [Parameter()]
        [string]$CacheDirectory,
        [Parameter()]
        [switch]$Offline
    )

    $allFonts = [ordered]@{}
    $declarations = @(
        @{ Module = '0xType.psm1'; Function = 'Get-0xTypeFonts' }
        @{ Module = 'CascadiaCode.psm1'; Function = 'Get-CascadiaCodeFonts' }
        @{ Module = 'FiraCode.psm1'; Function = 'Get-FiraCodeFonts' }
        @{ Module = 'Geist.psm1'; Function = 'Get-GeistFonts' }
        @{ Module = 'GoogleSansCode.psm1'; Function = 'Get-GoogleSansCodeFonts' }
        @{ Module = 'IBMPlex.psm1'; Function = 'Get-IBMPlexFonts' }
        @{ Module = 'IntelOneMono.psm1'; Function = 'Get-IntelOneMonoFonts' }
        @{ Module = 'Iosevka.psm1'; Function = 'Get-IosevkaFonts' }
        @{ Module = 'JetbrainsMono.psm1'; Function = 'Get-JetBrainsMonoFonts' }
        @{ Module = 'MapleMono.psm1'; Function = 'Get-MapleMonoFonts' }
        @{ Module = 'MonaSans.psm1'; Function = 'Get-MonaSansFonts' }
        @{ Module = 'Monaspace.psm1'; Function = 'Get-MonaspaceFonts' }
        @{ Module = 'NerdFonts.psm1'; Function = 'Get-NerdFonts' }
    )

    foreach ($declaration in $declarations) {
        Import-Module -Force (Join-Path $PSScriptRoot $declaration.Module)
        if ($declaration.Function -eq 'Get-NerdFonts') {
            $fontDeclarations = & $declaration.Function -CacheDirectory $CacheDirectory -Offline:$Offline
        } else {
            $fontDeclarations = & $declaration.Function
        }
        $fontDeclarations.GetEnumerator() | ForEach-Object { $allFonts[$_.Key] = $_.Value }
    }

    return $allFonts
}

function Get-NerdFontsResources {
    param(
        [Parameter()]
        $Catalog,
        [Parameter()]
        [switch]$Force
    )

    $fonts = if ($Catalog) {
        $Catalog
    } else {
        if (-not (Get-Command -Name Get-NerdFontsCatalog -ErrorAction SilentlyContinue)) {
            Import-Module (Join-Path $PSScriptRoot '..\Modules\ManifestSources.psm1' -Resolve) -Force
        }
        Get-NerdFontsCatalog -Force:$Force
    }
    $flavorOverrides = @{
        'Arimo'                = { param($p) @(@{ patchedName = $p; variants = @('', 'Propo') }) }
        'BigBlueTerminal'      = { param($p) @(
                @{ patchedName = 'BigBlueTerm437'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'BigBlueTermPlus'; variants = @('', 'Mono', 'Propo') }
            ) }
        'D2CodingLigature'     = { param($p) @(@{ patchedName = 'D2KodingLigature'; variants = @('', 'Mono', 'Propo') }) }
        'Gohu'                 = { param($p) @(
                @{ patchedName = 'GohuFont11'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'GohuFont14'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'GohuFontuni11'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'GohuFontuni14'; variants = @('', 'Mono', 'Propo') }
            ) }
        'HeavyData'            = { param($p) @(@{ patchedName = $p; variants = @('', 'Propo') }) }
        'iA-Writer'            = { param($p) @(
                @{ patchedName = 'iMWritingMono'; variants = @('', 'Propo') },
                @{ patchedName = 'iMWritingDuo'; variants = @('', 'Propo') },
                @{ patchedName = 'iMWritingQuat'; variants = @('', 'Propo') }
            ) }
        'InconsolataLGC'       = { param($p) @(@{ patchedName = 'InconsolataLGC'; variants = @('', 'Mono', 'Propo') }) }
        'JetBrainsMono'        = { param($p) @(
                @{ patchedName = 'JetBrainsMono'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'JetBrainsMonoNL'; variants = @('', 'Mono', 'Propo') }
            ) }
        'LiberationMono'       = { param($p) @(
                @{ patchedName = 'LiterationMono'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'LiterationSans'; variants = @('', 'Propo') },
                @{ patchedName = 'LiterationSerif'; variants = @('', 'Propo') }
            ) }
        'Meslo'                = { param($p) @(
                @{ patchedName = 'MesloLGL'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'MesloLGLDZ'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'MesloLGM'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'MesloLGMDZ'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'MesloLGS'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'MesloLGSDZ'; variants = @('', 'Mono', 'Propo') }
            ) }
        'Monaspace'            = { param($p) @(
                @{ patchedName = 'MonaspiceAr'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'MonaspiceKr'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'MonaspiceNe'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'MonaspiceRn'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'MonaspiceXe'; variants = @('', 'Mono', 'Propo') }
            ) }
        'MPlus'                = { param($p) @(
                @{ patchedName = 'M+1'; variants = @('', 'Propo') },
                @{ patchedName = 'M+2'; variants = @('', 'Propo') },
                @{ patchedName = 'M+1Code'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'M+CodeLat50'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'M+CodeLat60'; variants = @('', 'Mono', 'Propo') }
            ) }
        'NerdFontsSymbolsOnly' = { param($p) @(@{ patchedName = $p; variants = @('', 'Mono') }) }
        'Noto'                 = { param($p) @(
                @{ patchedName = 'NotoMono'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'NotoSansM'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'NotoSans'; variants = @('', 'Propo') },
                @{ patchedName = 'NotoSerif'; variants = @('', 'Propo') }
            ) }
        'OpenDyslexic'         = { param($p) @(
                @{ patchedName = 'OpenDyslexic'; variants = @('', 'Propo') },
                @{ patchedName = 'OpenDyslexicAlt'; variants = @('', 'Propo') },
                @{ patchedName = 'OpenDyslexicM'; variants = @('', 'Mono', 'Propo') }
            ) }
        'Overpass'             = { param($p) @(
                @{ patchedName = 'Overpass'; variants = @('', 'Propo') },
                @{ patchedName = 'OverpassM'; variants = @('', 'Mono', 'Propo') }
            ) }
        'ProFont'              = { param($p) @(@{ patchedName = 'ProFontWindows'; variants = @('', 'Mono', 'Propo') }) }
        'ProggyClean'          = { param($p) @(
                @{ patchedName = 'ProggyClean'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'ProggyCleanCE'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'ProggyCleanSZ'; variants = @('', 'Mono', 'Propo') }
            ) }
        'Recursive'            = { param($p) @(
                @{ patchedName = 'RecMonoCasual'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'RecMonoDuotone'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'RecMonoLinear'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'RecMonoSmCasual'; variants = @('', 'Mono', 'Propo') }
            ) }
        'Tinos'                = { param($p) @(@{ patchedName = $p; variants = @('', 'Propo') }) }
        'Ubuntu'               = { param($p) @(@{ patchedName = $p; variants = @('', 'Propo') }) }
        'UbuntuSans'           = { param($p) @(
                @{ patchedName = 'UbuntuSans'; variants = @('', 'Propo') },
                @{ patchedName = 'UbuntuSansMono'; variants = @('', 'Mono', 'Propo') }
            ) }
    }

    $manifests = [ordered]@{}
    foreach ($font in $fonts) {
        $folderName = $font.folderName
        $flavors = if ($flavorOverrides.ContainsKey($folderName)) {
            & $flavorOverrides[$folderName] $font.patchedName
        } else {
            @(@{ patchedName = $font.patchedName; variants = @('', 'Mono', 'Propo') })
        }
        $folderRegex = [regex]::Escape($folderName)
        foreach ($flavor in $flavors) {
            $patchedName = $flavor.patchedName
            foreach ($variant in $flavor.variants) {
                $fontName = "${patchedName}NerdFont${variant}"
                $fontRegex = [regex]::Escape($fontName)
                $manifests[$fontName] = @{
                    Repo    = 'ryanoasis/nerd-fonts'
                    Regex   = "/v?([\d.]+)/${folderRegex}\.tar\.xz"
                    Filter  = "${fontRegex}-.*\.[ot]tf$"
                    License = $font.licenseId
                    Desc    = $font.description
                    Latest  = $true
                }
            }
        }
    }

    return $manifests
}

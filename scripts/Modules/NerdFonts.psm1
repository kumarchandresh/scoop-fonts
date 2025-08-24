function Get-NerdFonts {
    Write-Host 'Fetching release data for Nerd Fonts...'
    $fonts = ((Invoke-WebRequest 'https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/heads/master/bin/scripts/lib/fonts.json').Content | ConvertFrom-Json).fonts
    if ($fonts.Count -eq 0) {
        Write-Warning 'Nerd Fonts: Failed to fetch release data from GitHub.'
    }
    $manifests = [ordered]@{}
    foreach ($font in $fonts) {
        $folderName = $font.folderName
        $flavors = if ($folderName -eq 'Arimo') {
            @(
                @{patchedName = $font.patchedName; variants = @('', 'Propo') }
            )
        } elseif ($folderName -eq 'Gohu') {
            @(
                @{ patchedName = 'GohuFont11'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'GohuFont14'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'GohuFontuni11'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'GohuFontuni14'; variants = @('', 'Mono', 'Propo') }
            )
        } elseif ($folderName -eq 'iA-Writer') {
            @(
                @{ patchedName = 'iMWritingMono'; variants = @('', 'Propo') },
                @{ patchedName = 'iMWritingDuo'; variants = @('', 'Propo') },
                @{ patchedName = 'iMWritingQuat'; variants = @('', 'Propo') }
            )
        } elseif ($folderName -eq 'JetBrainsMono') {
            @(
                @{ patchedName = 'JetBrainsMono'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'JetBrainsMonoNL'; variants = @('', 'Mono', 'Propo') }
            )
        } elseif ($folderName -eq 'LiberationMono') {
            @(
                @{ patchedName = 'LiterationMono'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'LiterationSans'; variants = @('', 'Propo') },
                @{ patchedName = 'LiterationSerif'; variants = @('', 'Propo') }
            )
        } elseif ($folderName -eq 'Meslo') {
            @(
                @{ patchedName = 'MesloLGL'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'MesloLGLDZ'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'MesloLGM'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'MesloLGMDZ'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'MesloLGS'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'MesloLGSDZ'; variants = @('', 'Mono', 'Propo') }
            )
        } elseif ($folderName -eq 'Monaspace') {
            @(
                @{ patchedName = 'MonaspiceAr'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'MonaspiceKr'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'MonaspiceNe'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'MonaspiceRn'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'MonaspiceXe'; variants = @('', 'Mono', 'Propo') }
            )
        } elseif ($folderName -eq 'MPlus') {
            @(
                @{ patchedName = 'M+1'; variants = @('', 'Propo') },
                @{ patchedName = 'M+2'; variants = @('', 'Propo') },
                @{ patchedName = 'M+1Code'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'M+CodeLat50'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'M+CodeLat60'; variants = @('', 'Mono', 'Propo') }
            )
        } elseif ($folderName -eq 'NerdFontsSymbolsOnly') {
            @(
                @{patchedName = $font.patchedName; variants = @('', 'Mono') }
            )
        } elseif ($folderName -eq 'Noto') {
            @(
                @{ patchedName = 'NotoMono'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'NotoSansM'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'NotoSans'; variants = @('', 'Propo') },
                @{ patchedName = 'NotoSerif'; variants = @('', 'Propo') }
            )
        } elseif ($folderName -eq 'OpenDyslexic') {
            @(
                @{ patchedName = 'OpenDyslexic'; variants = @('', 'Propo') },
                @{ patchedName = 'OpenDyslexicAlt'; variants = @('', 'Propo') },
                @{ patchedName = 'OpenDyslexicM'; variants = @('', 'Mono', 'Propo') }
            )
        } elseif ($folderName -eq 'Overpass') {
            @(
                @{ patchedName = 'Overpass'; variants = @('', 'Propo') },
                @{ patchedName = 'OverpassM'; variants = @('', 'Mono', 'Propo') }
            )
        } elseif ($folderName -eq 'ProFont') {
            @(
                @{ patchedName = 'ProFontWindows'; variants = @('', 'Mono', 'Propo') }
            )
        } elseif ($folderName -eq 'ProggyClean') {
            @(
                @{ patchedName = 'ProggyClean'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'ProggyCleanCE'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'ProggyCleanSZ'; variants = @('', 'Mono', 'Propo') }
            )
        } elseif ($folderName -eq 'Recursive') {
            @(
                @{ patchedName = 'RecMonoCasual'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'RecMonoDuotone'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'RecMonoLinear'; variants = @('', 'Mono', 'Propo') },
                @{ patchedName = 'RecMonoSmCasual'; variants = @('', 'Mono', 'Propo') }
            )
        } elseif ($folderName -eq 'Tinos') {
            @(
                @{ patchedName = $font.patchedName; variants = @('', 'Propo') }
            )
        } elseif ($folderName -eq 'UbuntuSans') {
            @(
                @{ patchedName = 'UbuntuSans'; variants = @('', 'Propo') },
                @{ patchedName = 'UbuntuSansMono'; variants = @('', 'Mono', 'Propo') }
            )
        } else {
            @(
                @{patchedName = $font.patchedName; variants = @('', 'Mono', 'Propo') }
            )
        }
        $folderRegex = [regex]::Escape($folderName)
        foreach ($flavor in $flavors) {
            $patchedName = $flavor.patchedName
            foreach ($variant in $flavor.variants) {
                $fontName = "${patchedName}NerdFont${variant}"
                $fontRegex = [regex]::Escape($fontName)
                $manifests[$fontName] = @{
                    Name    = $fontName
                    Repo    = 'ryanoasis/nerd-fonts'
                    Regex   = "/v?([\d.]+)/${folderRegex}\.tar\.xz"
                    Filter  = "${fontRegex}-.*\.[ot]tf$"
                    License = $font.licenseId
                    Desc    = $font.description
                }
            }
        }
    }

    # $manifests.GetEnumerator() | ForEach-Object {
    #     [PSCustomObject]@{
    #         Name    = $_.Value.Name
    #         Repo    = $_.Value.Repo
    #         Regex   = $_.Value.Regex
    #         Filter  = $_.Value.Filter
    #         License = $_.Value.License
    #         Desc    = $_.Value.Desc
    #     }
    # }
    # exit 0

    return $manifests

}

function Get-IosevkaResources {
    $manifests = [ordered]@{}
    $fontNames = @(
        'Iosevka'
        'IosevkaCurly'
        'IosevkaCurlySlab'
        'IosevkaAile'
        'IosevkaEtoile'
        'IosevkaFixed'
        'IosevkaFixedCurly'
        'IosevkaFixedCurlySlab'
        'IosevkaFixedSlab'
        'IosevkaSlab'
        'IosevkaTerm'
        'IosevkaTermCurly'
        'IosevkaTermCurlySlab'
        'IosevkaTermSlab'
    )
    foreach ($prefix in @('Iosevka', 'IosevkaFixed', 'IosevkaTerm')) {
        foreach ($style in 1..18) {
            $fontNames += "${prefix}SS$('{0:D2}' -f $style)"
        }
    }

    foreach ($fontName in $fontNames) {
        foreach ($package in @(@('TTF', ''), @('TTF-Unhinted', '-Unhinted'))) {
            $prefix = $package[0]
            $suffix = $package[1]
            $name = "${fontName}${suffix}"
            $manifests[$name] = @{
                Repo   = 'be5invis/Iosevka'
                Regex  = "/v?([\d.]+)/Pkg${prefix}-${fontName}-[\d.]+\.zip"
                Filter = "${fontName}-.*\.ttf$"
            }
        }
    }

    $standardTtcFonts = $fontNames | Where-Object { $_ -notmatch '^Iosevka(Fixed|Term)' }
    foreach ($fontName in $standardTtcFonts) {
        foreach ($package in @(@('TTC', 'PkgTTC', ''), @('SuperTTC', 'SuperTTC', ''))) {
            $prefix = $package[0]
            $archivePrefix = $package[1]
            $sgr = $package[2]
            $suffix = "-$prefix"
            $name = "${fontName}${suffix}"
            $filter = if ($sgr) { "SGr-${fontName}-.*\.ttc$" } else { "${fontName}-.*\.ttc$" }
            $manifests[$name] = @{
                Repo   = 'be5invis/Iosevka'
                Regex  = "/v?([\d.]+)/${archivePrefix}-${fontName}-[\d.]+\.zip"
                Filter = $filter
            }
        }
    }

    $sgrTtcFonts = $fontNames | Where-Object { $_ -notmatch '^Iosevka(Aile|Etoile)$' }
    foreach ($fontName in $sgrTtcFonts) {
        foreach ($package in @(@('TTC-SGr', 'PkgTTC-SGr'), @('SuperTTC-SGr', 'SuperTTC-SGr'))) {
            $prefix = $package[0]
            $archivePrefix = $package[1]
            $name = "${fontName}-${prefix}"
            $manifests[$name] = @{
                Repo   = 'be5invis/Iosevka'
                Regex  = "/v?([\d.]+)/${archivePrefix}-${fontName}-[\d.]+\.zip"
                Filter = "SGr-${fontName}-.*\.ttc$"
            }
        }
    }

    return $manifests
}


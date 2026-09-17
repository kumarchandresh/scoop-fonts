function Get-MonaspaceResources {
    $config = @{
        static    = @{ dir = 'Static Fonts'  ; suffix = '' }
        variable  = @{ dir = 'Variable Fonts'; suffix = 'Var' }
        nerdfonts = @{ dir = 'NerdFonts'     ; suffix = 'NF' }
        frozen    = @{ dir = 'Frozen Fonts'  ; suffix = 'Frozen' }
    }
    $manifests = [ordered]@{}
    $variants = @(
        'static'
        'variable'
        'nerdfonts'
        'frozen'
    )
    $flavors = @(
        'Argon'
        'Krypton'
        'Neon'
        'Radon'
        'Xenon'
    )

    foreach ($variant in $variants) {
        $suffix = $config[$variant].suffix
        foreach ($flavor in $flavors) {
            $fontName = "Monaspace${flavor}$suffix"
            $name = $fontName -replace ' ', ''
            $manifests[$name] = @{
                Repo   = 'githubnext/monaspace'
                Regex  = "/v?([\d.]+)/monaspace-${variant}-v?[\d.]+\.zip"
                Filter = "\.[ot]tf$"
                Dir    = "$($config[$variant].dir)\Monaspace $flavor"
                Latest = $true
            }
        }
        $fontName = "Monaspace${suffix}"
        $manifests[$fontName] = @{
            Repo   = 'githubnext/monaspace'
            Regex  = "/v?([\d.]+)/monaspace-${variant}-v?[\d.]+\.zip"
            Filter = "\.[ot]tf$"
            Dir    = $config[$variant].dir
            Latest = $true
        }
    }

    return $manifests
}

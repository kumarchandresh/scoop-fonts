function Get-MonaspaceFonts {
    $config = @{
        static    = @{ dir = 'Static Fonts'  ; suffix = '' }
        variable  = @{ dir = 'Variable Fonts'; suffix = 'Var' }
        nerdfonts = @{ dir = 'NerdFonts'     ; suffix = 'NF' }
        frozen    = @{ dir = 'Frozen Fonts'  ; suffix = 'Frozen' }
    }
    $manifests = [ordered]@{}
    foreach ($variant in @('static', 'variable', 'nerdfonts', 'frozen')) {
        $suffix = $config[$variant].suffix
        foreach ($flavor in @('Argon', 'Krypton', 'Neon', 'Radon', 'Xenon')) {
            $fontName = "Monaspace${flavor}$suffix"
            $name = $fontName -replace ' ', ''
            $manifests[$name] = @{
                Name   = $name
                Repo   = 'githubnext/monaspace'
                Regex  = "/v?([\d.]+)/monaspace-${variant}-v?[\d.]+\.zip"
                Filter = "\.[ot]tf$"
                Dir    = "$($config[$variant].dir)\Monaspace $flavor"
            }
        }
        $fontName = "Monaspace${suffix}"
        $manifests[$fontName] = @{
            Name   = $fontName
            Repo   = 'githubnext/monaspace'
            Regex  = "/v?([\d.]+)/monaspace-${variant}-v?[\d.]+\.zip"
            Filter = "\.[ot]tf$"
            Dir    = $config[$variant].dir
        }
    }

    # $manifests.GetEnumerator() | ForEach-Object {
    #     [PSCustomObject]@{
    #         Name   = $_.Value.Name
    #         Repo   = $_.Value.Repo
    #         Regex  = $_.Value.Regex
    #         Filter = $_.Value.Filter
    #         Dir    = $_.Value.Dir
    #     }
    # }
    # exit 0

    return $manifests
}

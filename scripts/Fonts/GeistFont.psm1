function Get-GeistFontResources {
    $manifests = [ordered]@{}
    $variants = @(
        'Geist'
        'GeistMono'
        'GeistPixel'
    )
    $packages = @(
        @{ Suffix = ''; Dir = 'ttf' }
        @{ Suffix = '-OTF'; Dir = 'otf' }
        @{ Suffix = '-Variable'; Dir = 'variable' }
    )

    foreach ($pkg in $packages) {
        foreach ($variant in $variants) {
            $name = "$variant$($pkg.Suffix)"
            $manifests[$name] = @{
                Repo   = 'vercel/geist-font'
                Regex  = '/geist-font-v?([\d.]+)\.zip'
                Filter = '\.[ot]tf$'
                Latest = $true
                Dir    = "geist-font/$variant/$($pkg.Dir)"
            }
        }
    }

    return $manifests
}

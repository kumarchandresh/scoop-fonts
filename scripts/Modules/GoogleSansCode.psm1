function Get-GoogleSansCodeFonts {
    $manifests = [ordered]@{
        'GoogleSansCode' = @{Repo = 'googlefonts/googlesans-code'; Regex = '/v([\d.]+)/GoogleSansCode-v[\d.]+.zip'; Filter = "\.[ot]tf$" }
    }
    return $manifests
}

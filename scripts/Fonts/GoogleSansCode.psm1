function Get-GoogleSansCodeResources {
    $manifests = [ordered]@{
        'GoogleSansCode' = @{Repo = 'googlefonts/googlesans-code'; Regex = '/GoogleSansCode-v?([\d.]+)+.zip'; Filter = "\.[ot]tf$" }
    }
    return $manifests
}

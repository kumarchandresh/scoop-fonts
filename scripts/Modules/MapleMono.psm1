function Get-MapleMonoFonts {
    $urls = (Invoke-WebRequest 'https://api.github.com/repos/subframe7536/maple-font/releases/latest').Content | jq -r '.assets[] | .browser_download_url' | Where-Object { $_ -match '\.zip$' -and $_ -notmatch '-Woff2' }

    $manifests = [ordered]@{}
    foreach ($url in $urls) {
        $regex = [regex]::new('(MapleMono\w*-[\w-]+)\.zip')
        $match = $regex.Match($url)
        $fileName = $match.Groups[1].Value
        $fontName = ($fileName -replace '-TTF$', '-unhinted') -replace '-TTF-AutoHint', ''
        $manifests[$fontName] = @{
            Name   = $fontName
            Repo   = 'subframe7536/maple-font'
            Regex  = "/v?([\d.]+)/${fileName}\.zip"
            Filter = "\.[ot]tf$"
            Desc   = 'Maple Mono is an open source monospace font focused on smoothing your coding flow.'
        }
    }

    # $manifests.GetEnumerator() | ForEach-Object {
    #     [PSCustomObject]@{
    #         Name   = $_.Key
    #         Repo   = $_.Value.Repo
    #         Regex  = $_.Value.Regex
    #         Filter = $_.Value.Filter
    #         Desc   = $_.Value.Desc
    #     }
    # }
    # exit 0

    return $manifests
}

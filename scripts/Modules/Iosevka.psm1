function Get-IosevkaFonts {
    $headers = @{
        "User-Agent" = "PowerShell"
        "Accept"     = "application/vnd.github.v3+json"
    }
    if ($env:GITHUB_TOKEN) {
        $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
    }
    Write-Host 'Fetching release data for Iosevka...'
    $urls = Invoke-RestMethod 'https://api.github.com/repos/be5invis/Iosevka/releases/latest' -Headers $headers | ForEach-Object { $_.assets.browser_download_url } | Where-Object { $_ -match '\.zip$' }
    if ($urls.Count -eq 0) {
        Write-Warning 'Iosevka: Failed to fetch release data from GitHub API.'
    }
    $manifests = [ordered]@{}
    $ttfRegex = 'Pkg(TTF(-Unhinted)?)-(Iosevka\w*)-[\d.]+\.zip'
    foreach ($url in ($urls | Where-Object { $_ -match $ttfRegex })) {
        $regex = [regex]::new($ttfRegex)
        $match = $regex.Match($url)
        $prefix = $match.Groups[1].Value
        $suffix = $match.Groups[2].Value
        $fontName = $match.Groups[3].Value
        $manifests["${fontName}${suffix}"] = @{
            Name   = "${fontName}${suffix}"
            Repo   = 'be5invis/Iosevka'
            Regex  = "/v?([\d.]+)/Pkg${prefix}-${fontName}-[\d.]+\.zip"
            Filter = "${fontName}-.*\.ttf$"
        }
    }
    $ttcRegex = '((Pkg|Super)TTC(-SGr)?)-(Iosevka\w*)-[\d.]+\.zip'
    foreach ($url in ($urls | Where-Object { $_ -match $ttcRegex })) {
        $regex = [regex]::new($ttcRegex)
        $match = $regex.Match($url)
        $prefix = $match.Groups[1].Value
        $suffix = $prefix -replace '^Pkg', ''
        $sgr = $match.Groups[3].Value
        $fontName = $match.Groups[4].Value
        $manifests["${fontName}-${suffix}"] = @{
            Name   = "${fontName}-${suffix}"
            Repo   = 'be5invis/Iosevka'
            Regex  = "/v?([\d.]+)/${prefix}-${fontName}-[\d.]+\.zip"
            Filter = if ($sgr) { "SGr-${fontName}-.*\.ttc$" } else { "${fontName}-.*\.ttc$" }
        }
    }

    # $manifests.GetEnumerator() | ForEach-Object {
    #     [PSCustomObject]@{
    #         Name   = $_.Value.Name
    #         Repo   = $_.Value.Repo
    #         Regex  = $_.Value.Regex
    #         Filter = $_.Value.Filter
    #     }
    # }
    # exit 0

    return $manifests
}


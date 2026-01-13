function Get-JetBrainsMonoFonts {
    $headers = @{
        "User-Agent" = "PowerShell"
        "Accept"     = "application/vnd.github.v3+json"
    }
    if ($env:GITHUB_TOKEN) {
        $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
    }
    Write-Host 'Fetching release data for JetBrains Mono...'
    $urls = Invoke-RestMethod 'https://api.github.com/repos/JetBrains/JetBrainsMono/releases/latest' -Headers $headers | ForEach-Object { $_.assets.browser_download_url } | Where-Object { $_ -match '\.zip$' }
    if ($urls.Count -eq 0) {
        Write-Warning 'JetBrains Mono: Failed to fetch release data from GitHub API.'
    }
    $manifests = [ordered]@{}
    foreach ($url in $urls) {
        $regex = [regex]::new('(JetBrainsMono-[\d.]+)\.zip')
        $match = $regex.Match($url)
        $fileName = $match.Groups[1].Value
        $manifests['JetBrainsMono'] = @{
            Name   = 'JetBrainsMono'
            Repo   = 'JetBrains/JetBrainsMono'
            Regex  = "/v?([\d.]+)/${fileName}\.zip"
            Filter = "JetBrainsMono-.*\.ttf$"
            Dir = "fonts/ttf"
        }
        $manifests['JetBrainsMono-NL'] = @{
            Name   = 'JetBrainsMono-NL'
            Repo   = 'JetBrains/JetBrainsMono'
            Regex  = "/v?([\d.]+)/${fileName}\.zip"
            Filter = "JetBrainsMonoNL-.*\.ttf$"
            Dir = "fonts/ttf"
        }
    }

    # $manifests.GetEnumerator() | ForEach-Object {
    #     [PSCustomObject]@{
    #         Name   = $_.Key
    #         Repo   = $_.Value.Repo
    #         Regex  = $_.Value.Regex
    #         Filter = $_.Value.Filter
    #     }
    # }
    # exit 0

    return $manifests
}

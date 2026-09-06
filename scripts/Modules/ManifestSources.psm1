function New-GitHubHeaders {
    $headers = @{
        "User-Agent" = "PowerShell"
        "Accept"     = "application/vnd.github.v3+json"
    }
    if ($env:GITHUB_TOKEN) {
        $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
    }
    return $headers
}

function Invoke-GitHubRateLimitedRestMethod {
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [Parameter(Mandatory)]
        [hashtable]$Headers,
        [Parameter(Mandatory)]
        [hashtable]$RateLimitState
    )

    if ($RateLimitState.LastApiCall) {
        $elapsed = (Get-Date) - $RateLimitState.LastApiCall
        if ($elapsed.TotalMilliseconds -lt $RateLimitState.ApiCallInterval) {
            Start-Sleep -Milliseconds ($RateLimitState.ApiCallInterval - $elapsed.TotalMilliseconds)
        }
    }

    $RateLimitState.LastApiCall = Get-Date
    return Invoke-RestMethod -Uri $Uri -Headers $Headers
}

function Get-GitHubRepositoryMetadata {
    param(
        [Parameter(Mandatory)]
        [string]$Repository,
        [Parameter(Mandatory)]
        [hashtable]$Headers,
        [Parameter(Mandatory)]
        [hashtable]$Cache,
        [Parameter(Mandatory)]
        [hashtable]$RateLimitState,
        [Parameter()]
        [string]$FallbackLicense
    )

    $cacheKey = $Repository.ToLower()
    if ($Cache.ContainsKey($cacheKey)) {
        return $Cache[$cacheKey]
    }

    $repo = Invoke-GitHubRateLimitedRestMethod -Uri "https://api.github.com/repos/$Repository" -Headers $Headers -RateLimitState $RateLimitState
    $license = Invoke-GitHubRateLimitedRestMethod -Uri "https://api.github.com/repos/$Repository/license" -Headers $Headers -RateLimitState $RateLimitState |
        Select-Object @{ Name = "License"; Expression = { $_.license.spdx_id } } |
        Select-Object -ExpandProperty License
    if ('NOASSERTION' -eq $license) {
        $license = $FallbackLicense
    }

    $metadata = @{ Repo = $repo; License = $license }
    $Cache[$cacheKey] = $metadata
    return $metadata
}

function Get-GitHubReleaseData {
    param(
        [Parameter(Mandatory)]
        [string]$Repository,
        [Parameter(Mandatory)]
        [bool]$Latest,
        [Parameter(Mandatory)]
        [hashtable]$Headers,
        [Parameter(Mandatory)]
        [hashtable]$Cache,
        [Parameter(Mandatory)]
        [hashtable]$RateLimitState
    )

    $releaseUrl = if ($Latest) {
        "https://api.github.com/repos/$Repository/releases/latest"
    } else {
        "https://api.github.com/repos/$Repository/releases"
    }
    $cacheKey = $releaseUrl.ToLower()
    if ($Cache.ContainsKey($cacheKey)) {
        $releaseInfo = $Cache[$cacheKey]
    } else {
        $releaseInfo = Invoke-GitHubRateLimitedRestMethod -Uri $releaseUrl -Headers $Headers -RateLimitState $RateLimitState
        if ($null -eq $releaseInfo) {
            return $null
        }
        $Cache[$cacheKey] = $releaseInfo
    }

    return @{
        Info = $releaseInfo
        Url = $releaseUrl
        JsonPath = if ($Latest) { '$.assets[*].browser_download_url' } else { '$[*].assets[*].browser_download_url' }
    }
}

function Find-GitHubDownloadUrl {
    param(
        [Parameter(Mandatory)]
        $ReleaseInfo,
        [Parameter(Mandatory)]
        [bool]$Latest,
        [Parameter(Mandatory)]
        [string]$Regex
    )

    if ($Latest) {
        return @($ReleaseInfo.assets.browser_download_url) |
            Where-Object { $_ -match $Regex } |
            Select-Object -First 1
    }

    return $ReleaseInfo |
        ForEach-Object { $_.assets.browser_download_url } |
        Where-Object { $_ -match $Regex } |
        Select-Object -First 1
}

function Get-NerdFontsCatalog {
    $headers = New-GitHubHeaders
    Write-Host 'Fetching release data for Nerd Fonts...'
    $fonts = (Invoke-RestMethod 'https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/heads/master/bin/scripts/lib/fonts.json' -Headers $headers).fonts
    if ($fonts.Count -eq 0) {
        Write-Warning 'Nerd Fonts: Failed to fetch release data from GitHub.'
    }
    return $fonts
}

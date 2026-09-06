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

function Get-ManifestCacheKey {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value.ToLower())
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLower()
    } finally {
        $sha.Dispose()
    }
}

function Get-ManifestCachePath {
    param(
        [Parameter(Mandatory)]
        [string]$CacheDirectory,
        [Parameter(Mandatory)]
        [string]$Key,
        [Parameter(Mandatory)]
        [string]$Extension
    )

    return Join-Path $CacheDirectory "$Key.$Extension"
}

function ConvertTo-ManifestCachePathPart {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    $part = $Value.Trim() -replace '[<>:"/\\|?*]', '_'
    if ([string]::IsNullOrWhiteSpace($part) -or $part -in @('.', '..')) {
        return '_'
    }
    return $part
}

function Get-ManifestArtifactPath {
    param(
        [Parameter(Mandatory)]
        [string]$DownloadUrl,
        [Parameter(Mandatory)]
        [string]$Version,
        [Parameter()]
        [string]$CacheDirectory
    )

    $uri = [uri]$DownloadUrl
    $segments = @($uri.AbsolutePath.Trim('/') -split '/' | Where-Object { $_ })
    if ($segments.Count -eq 0) {
        throw "Cannot derive an artifact filename from URL: $DownloadUrl"
    }

    $fileName = ConvertTo-ManifestCachePathPart ([uri]::UnescapeDataString($segments[-1]))
    if ($uri.Host -eq 'github.com' -and $segments.Count -ge 3) {
        $owner = ConvertTo-ManifestCachePathPart $segments[0]
        $repo = ConvertTo-ManifestCachePathPart ($segments[1] -replace '\.git$', '')
    } else {
        $owner = ConvertTo-ManifestCachePathPart $uri.Host
        $repo = ConvertTo-ManifestCachePathPart $(if ($segments.Count -gt 1) { $segments[0] } else { 'artifacts' })
    }

    $root = if ($CacheDirectory) {
        Join-Path $CacheDirectory 'artifacts'
    } else {
        Join-Path $env:TEMP 'scoop-fonts'
    }
    return Join-Path (Join-Path (Join-Path (Join-Path $root $owner) $repo) (ConvertTo-ManifestCachePathPart $Version)) $fileName
}

function Invoke-GitHubRateLimitedRestMethod {
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [Parameter(Mandatory)]
        [hashtable]$Headers,
        [Parameter(Mandatory)]
        [hashtable]$RateLimitState,
        [Parameter()]
        [string]$CacheDirectory,
        [Parameter()]
        [switch]$Offline
    )

    $cacheFile = $null
    if ($CacheDirectory) {
        $cacheFile = Get-ManifestCachePath -CacheDirectory (Join-Path $CacheDirectory 'responses') -Key (Get-ManifestCacheKey $Uri) -Extension 'json'
        if (Test-Path $cacheFile) {
            return Get-Content $cacheFile -Raw | ConvertFrom-Json -Depth 100
        }
        if ($Offline) {
            throw "Offline input cache miss: $Uri"
        }
        New-Item -ItemType Directory -Force -Path (Split-Path $cacheFile) | Out-Null
    }

    if ($RateLimitState.LastApiCall) {
        $elapsed = (Get-Date) - $RateLimitState.LastApiCall
        if ($elapsed.TotalMilliseconds -lt $RateLimitState.ApiCallInterval) {
            Start-Sleep -Milliseconds ($RateLimitState.ApiCallInterval - $elapsed.TotalMilliseconds)
        }
    }

    $RateLimitState.LastApiCall = Get-Date
    $response = Invoke-RestMethod -Uri $Uri -Headers $Headers
    if ($cacheFile) {
        ConvertTo-Json $response -Depth 100 | Out-File -Encoding utf8 -FilePath $cacheFile
    }
    return $response
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
        [string]$FallbackLicense,
        [Parameter()]
        [string]$CacheDirectory,
        [Parameter()]
        [switch]$Offline
    )

    $cacheKey = $Repository.ToLower()
    if ($Cache.ContainsKey($cacheKey)) {
        return $Cache[$cacheKey]
    }

    $repo = Invoke-GitHubRateLimitedRestMethod -Uri "https://api.github.com/repos/$Repository" -Headers $Headers -RateLimitState $RateLimitState -CacheDirectory $CacheDirectory -Offline:$Offline
    $license = Invoke-GitHubRateLimitedRestMethod -Uri "https://api.github.com/repos/$Repository/license" -Headers $Headers -RateLimitState $RateLimitState -CacheDirectory $CacheDirectory -Offline:$Offline |
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
        [hashtable]$RateLimitState,
        [Parameter()]
        [string]$CacheDirectory,
        [Parameter()]
        [switch]$Offline
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
        $releaseInfo = Invoke-GitHubRateLimitedRestMethod -Uri $releaseUrl -Headers $Headers -RateLimitState $RateLimitState -CacheDirectory $CacheDirectory -Offline:$Offline
        if ($null -eq $releaseInfo) {
            return $null
        }
        $Cache[$cacheKey] = $releaseInfo
    }

    return @{
        Info     = $releaseInfo
        Url      = $releaseUrl
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
    param(
        [Parameter()]
        [string]$CacheDirectory,
        [Parameter()]
        [switch]$Offline
    )

    $headers = New-GitHubHeaders
    Write-Host 'Fetching release data for Nerd Fonts...'
    $rateLimitState = @{ LastApiCall = $null; ApiCallInterval = 0 }
    $fonts = (Invoke-GitHubRateLimitedRestMethod -Uri 'https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/heads/master/bin/scripts/lib/fonts.json' -Headers $headers -RateLimitState $rateLimitState -CacheDirectory $CacheDirectory -Offline:$Offline).fonts
    if ($fonts.Count -eq 0) {
        Write-Warning 'Nerd Fonts: Failed to fetch release data from GitHub.'
    }
    return $fonts
}

function Get-ManifestArtifactHash {
    param(
        [Parameter(Mandatory)]
        [string]$DownloadUrl,
        [Parameter(Mandatory)]
        [string]$Version,
        [Parameter(Mandatory)]
        [hashtable]$Headers,
        [Parameter(Mandatory)]
        [hashtable]$Cache,
        [Parameter()]
        [string]$CacheDirectory,
        [Parameter()]
        [switch]$Offline
    )

    $cacheKey = $DownloadUrl.ToLower()
    if ($Cache.ContainsKey($cacheKey)) {
        return $Cache[$cacheKey]
    }

    $outfile = Get-ManifestArtifactPath -DownloadUrl $DownloadUrl -Version $Version -CacheDirectory $CacheDirectory
    if (-not (Test-Path $outfile)) {
        if ($Offline) {
            return $null
        }
        New-Item -ItemType Directory -Force -Path (Split-Path $outfile) | Out-Null
        $partial = "$outfile.download"
        try {
            Invoke-WebRequest -Uri $DownloadUrl -Headers $Headers -OutFile $partial
            Move-Item -Force $partial $outfile
        } finally {
            Remove-Item -Force $partial -ErrorAction SilentlyContinue
        }
    }
    if (-not (Test-Path $outfile)) {
        return $null
    }

    $hash = (Get-FileHash $outfile -Algorithm SHA256).Hash.ToLower()
    $Cache[$cacheKey] = $hash
    return $hash
}

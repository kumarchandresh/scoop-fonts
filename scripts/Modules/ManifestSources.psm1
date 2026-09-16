function Get-ScoopConfig {
    param([string]$Name)
    $configHome = $env:XDG_CONFIG_HOME, "$([System.Environment]::GetFolderPath('UserProfile'))\.config" | Where-Object { $_ } | Select-Object -First 1
    $configFile = Join-Path $configHome 'scoop\config.json'
    if (Test-Path -LiteralPath $configFile) {
        try {
            $json = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
            $prop = $Name.ToLowerInvariant()
            return $json.$prop
        } catch {}
    }
    return $null
}

function Get-GitHubToken {
    return $env:SCOOP_GH_TOKEN, (Get-ScoopConfig 'gh_token'), $env:GH_TOKEN, $env:GITHUB_TOKEN |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -First 1
}

function New-GitHubHeaders {
    $headers = @{
        "User-Agent" = "PowerShell"
        "Accept"     = "application/vnd.github.v3+json"
    }
    $token = Get-GitHubToken
    if ($token) {
        $headers["Authorization"] = "Bearer $token"
    }
    return $headers
}

function Show-GitHubRateLimit {
    param([hashtable]$Headers = (New-GitHubHeaders))
    try {
        $response = Invoke-RestMethod -Uri 'https://api.github.com/rate_limit' -Headers $Headers
        Write-Host ("GITHUB API RATE LIMIT: " + ($response.rate | ConvertTo-Json -Compress))
    } catch {
        Write-Warning "Failed to query GitHub API rate limit: $($_.Exception.Message)"
    }
}

function Enable-ScoopGitHubAuthForCheckver {
    $token = Get-GitHubToken
    if (-not $token) { return $null }

    $configHome = $env:XDG_CONFIG_HOME, "$([System.Environment]::GetFolderPath('UserProfile'))\.config" | Where-Object { $_ } | Select-Object -First 1
    $configFile = Join-Path $configHome 'scoop\config.json'
    if (-not (Test-Path -LiteralPath $configFile)) { return $null }

    try {
        $cfg = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
        $origHosts = $cfg.private_hosts
        $hasGithub = $false
        if ($origHosts) {
            foreach ($h in $origHosts) {
                if ($h.match -match 'api\.github\.com') {
                    $hasGithub = $true
                    break
                }
            }
        }
        if (-not $hasGithub) {
            $entry = [PSCustomObject]@{
                match   = 'api\.github\.com'
                headers = "Authorization=token $token"
            }
            $cfg | Add-Member -MemberType NoteProperty -Name 'private_hosts' -Value @($origHosts + @($entry)) -Force
            $cfg | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configFile
            return @{
                ConfigFile    = $configFile
                OriginalHosts = $origHosts
            }
        }
    } catch {}
    return $null
}

function Disable-ScoopGitHubAuthForCheckver {
    param($State)
    if ($null -eq $State -or -not (Test-Path -LiteralPath $State.ConfigFile)) { return }
    try {
        $cfg = Get-Content -LiteralPath $State.ConfigFile -Raw | ConvertFrom-Json
        if ($null -ne $State.OriginalHosts) {
            $cfg.private_hosts = $State.OriginalHosts
        } else {
            $cfg.PSObject.Properties.Remove('private_hosts')
        }
        $cfg | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $State.ConfigFile
    } catch {}
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
    return [System.IO.Path]::Combine($root, $owner, $repo, (ConvertTo-ManifestCachePathPart $Version), $fileName)
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
    $licenseData = Invoke-GitHubRateLimitedRestMethod -Uri "https://api.github.com/repos/$Repository/license" -Headers $Headers -RateLimitState $RateLimitState
    $license = $licenseData.license.spdx_id
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

    $matchedUrls = @(
        if ($Latest) {
            $ReleaseInfo.assets.browser_download_url | Where-Object { $_ -match $Regex }
        } else {
            $ReleaseInfo | ForEach-Object { $_.assets.browser_download_url } | Where-Object { $_ -match $Regex }
        }
    )

    if ($matchedUrls.Count -gt 1) {
        throw "Ambiguous asset match: multiple URLs matched regex '$Regex': $($matchedUrls -join ', ')"
    }

    if ($matchedUrls.Count -eq 0) {
        return $null
    }

    return $matchedUrls[0]
}

function Get-NerdFontsCatalog {
    $headers = New-GitHubHeaders
    Write-Host 'Fetching release data for Nerd Fonts...'
    $rateLimitState = @{ LastApiCall = $null; ApiCallInterval = 0 }
    $fonts = (Invoke-GitHubRateLimitedRestMethod -Uri 'https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/heads/master/bin/scripts/lib/fonts.json' -Headers $headers -RateLimitState $rateLimitState).fonts
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
        [string]$CacheDirectory
    )

    $cacheKey = $DownloadUrl.ToLower()
    if ($Cache.ContainsKey($cacheKey)) {
        return $Cache[$cacheKey]
    }

    $outfile = Get-ManifestArtifactPath -DownloadUrl $DownloadUrl -Version $Version -CacheDirectory $CacheDirectory
    if (-not (Test-Path $outfile)) {
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

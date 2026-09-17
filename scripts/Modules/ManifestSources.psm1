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

$script:LastApiCall = $null
$script:ApiCallInterval = 500
$script:NerdFontsCatalog = $null

function Invoke-GitHubRateLimitedRestMethod {
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [Parameter(Mandatory)]
        [hashtable]$Headers,
        [Parameter()]
        [hashtable]$RateLimitState
    )

    if ($RateLimitState) {
        if ($RateLimitState.LastApiCall) {
            $elapsed = (Get-Date) - $RateLimitState.LastApiCall
            if ($elapsed.TotalMilliseconds -lt $RateLimitState.ApiCallInterval) {
                Start-Sleep -Milliseconds ($RateLimitState.ApiCallInterval - $elapsed.TotalMilliseconds)
            }
        }
        $RateLimitState.LastApiCall = Get-Date
    } else {
        if ($script:LastApiCall) {
            $elapsed = (Get-Date) - $script:LastApiCall
            if ($elapsed.TotalMilliseconds -lt $script:ApiCallInterval) {
                Start-Sleep -Milliseconds ($script:ApiCallInterval - $elapsed.TotalMilliseconds)
            }
        }
        $script:LastApiCall = Get-Date
    }

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
        [Parameter()]
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
        [Parameter()]
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

    if ($Latest) {
        $matchedUrls = @($ReleaseInfo.assets.browser_download_url | Where-Object { $_ -match $Regex })
        if ($matchedUrls.Count -gt 1) {
            throw "Ambiguous asset match: multiple URLs matched regex '$Regex': $($matchedUrls -join ', ')"
        }
        if ($matchedUrls.Count -eq 0) {
            return $null
        }
        return $matchedUrls[0]
    }

    foreach ($release in $ReleaseInfo) {
        $matchedUrls = @($release.assets.browser_download_url | Where-Object { $_ -match $Regex })
        if ($matchedUrls.Count -gt 1) {
            $tag = if ($release.tag_name) { "in release '$($release.tag_name)' " } else { '' }
            throw "Ambiguous asset match: multiple URLs ${tag}matched regex '$Regex': $($matchedUrls -join ', ')"
        }
        if ($matchedUrls.Count -eq 1) {
            return $matchedUrls[0]
        }
    }

    return $null
}

function Get-NerdFontsCatalog {
    param(
        [Parameter()]
        [switch]$Force,
        [Parameter()]
        [string]$CacheDirectory
    )

    if (-not $Force -and $null -ne $script:NerdFontsCatalog) {
        return , $script:NerdFontsCatalog
    }

    $cacheRoot = if ($CacheDirectory) {
        $CacheDirectory
    } else {
        Join-Path $env:TEMP 'scoop-fonts'
    }
    $cacheFile = Join-Path $cacheRoot 'nerdfonts-catalog.json'

    if (-not $Force -and (Test-Path -LiteralPath $cacheFile)) {
        $item = Get-Item -LiteralPath $cacheFile
        $age = (Get-Date) - $item.LastWriteTime
        if ($age.TotalHours -lt 24) {
            try {
                $cachedData = Get-Content -LiteralPath $cacheFile -Raw | ConvertFrom-Json
                if ($cachedData -and $cachedData.fonts -and $cachedData.fonts.Count -gt 0) {
                    $script:NerdFontsCatalog = @($cachedData.fonts)
                    return , $script:NerdFontsCatalog
                }
            } catch {
                Write-Warning "Failed to read cached Nerd Fonts catalog: $($_.Exception.Message)"
            }
        }
    }

    $headers = New-GitHubHeaders
    Write-Host 'Fetching release data for Nerd Fonts...'
    $fonts = @()
    try {
        $response = Invoke-GitHubRateLimitedRestMethod -Uri 'https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/heads/master/bin/scripts/lib/fonts.json' -Headers $headers
        if ($response -and $response.fonts) {
            $fonts = @($response.fonts)
            $script:NerdFontsCatalog = $fonts
            try {
                if (-not (Test-Path -LiteralPath $cacheRoot)) {
                    New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
                }
                $response | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $cacheFile -Force
            } catch {
                Write-Warning "Failed to save Nerd Fonts catalog cache: $($_.Exception.Message)"
            }
        }
    } catch {
        Write-Warning "Nerd Fonts: Failed to fetch release data from GitHub: $($_.Exception.Message)"
    }

    if ($fonts.Count -eq 0) {
        Write-Warning 'Nerd Fonts: Failed to fetch release data from GitHub.'
    }
    return , $fonts
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

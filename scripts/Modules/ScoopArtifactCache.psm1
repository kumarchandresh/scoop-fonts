function Get-ScoopCacheDirectory {
    param(
        [Parameter()]
        [string]$CacheDirectory
    )

    if ($CacheDirectory) {
        return $CacheDirectory
    }
    if ($env:SCOOP) {
        return Join-Path $env:SCOOP 'cache'
    }
    return Join-Path (Join-Path $HOME 'scoop') 'cache'
}

function Get-ScoopArtifactCachePath {
    param(
        [Parameter(Mandatory)]
        [string]$App,
        [Parameter(Mandatory)]
        [string]$Version,
        [Parameter(Mandatory)]
        [string]$DownloadUrl,
        [Parameter()]
        [string]$CacheDirectory
    )

    $urlBytes = [System.Text.Encoding]::UTF8.GetBytes($DownloadUrl)
    $urlStream = [System.IO.MemoryStream]::new($urlBytes)
    try {
        $urlHash = (Get-FileHash -Algorithm SHA256 -InputStream $urlStream).Hash.ToLower().Substring(0, 7)
    } finally {
        $urlStream.Dispose()
    }
    $extension = [System.IO.Path]::GetExtension(([uri]$DownloadUrl).AbsolutePath)
    return Join-Path (Get-ScoopCacheDirectory $CacheDirectory) "$App#$Version#$urlHash$extension"
}

function Test-ArtifactHash {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$ExpectedHash
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }
    return ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -eq $ExpectedHash)
}

function Initialize-ScoopArtifactCache {
    param(
        [Parameter(Mandatory)]
        [string]$App,
        [Parameter(Mandatory)]
        [string]$Version,
        [Parameter(Mandatory)]
        [string]$DownloadUrl,
        [Parameter(Mandatory)]
        [string]$ExpectedHash,
        [Parameter()]
        [string]$ArtifactCacheDirectory,
        [Parameter()]
        [string]$ScoopCacheDirectory
    )

    $artifactPath = Get-ManifestArtifactPath -DownloadUrl $DownloadUrl -Version $Version -CacheDirectory $ArtifactCacheDirectory
    if (-not (Test-ArtifactHash -Path $artifactPath -ExpectedHash $ExpectedHash.ToLower())) {
        throw "Verified artifact is missing or has an unexpected hash: $artifactPath"
    }

    $scoopPath = Get-ScoopArtifactCachePath -App $App -Version $Version -DownloadUrl $DownloadUrl -CacheDirectory $ScoopCacheDirectory
    New-Item -ItemType Directory -Force -Path (Split-Path $scoopPath) | Out-Null
    $partial = "$scoopPath.download"
    try {
        Copy-Item -LiteralPath $artifactPath -Destination $partial -Force
        Move-Item -LiteralPath $partial -Destination $scoopPath -Force
    } finally {
        Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-ArtifactHash -Path $scoopPath -ExpectedHash $ExpectedHash.ToLower())) {
        throw "Scoop cache seeding verification failed: $scoopPath"
    }
    return $scoopPath
}

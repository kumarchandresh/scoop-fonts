param(
    [Parameter()]
    [string]$BucketDirectory = (Join-Path $PSScriptRoot '..\bucket' -Resolve),
    [Parameter()]
    [string]$TempDirectory = $env:TEMP,
    [Parameter()]
    [switch]$RemoveSource
)

Set-StrictMode -Version 1
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules\ManifestSources.psm1' -Resolve) -Force

$entries = @{}
foreach ($file in Get-ChildItem $BucketDirectory -Filter '*.json') {
    $manifest = Get-Content $file.FullName -Raw | ConvertFrom-Json
    if (-not $manifest.url -or -not $manifest.version -or -not $manifest.hash) {
        continue
    }

    $uri = [uri]$manifest.url
    $name = [uri]::UnescapeDataString(($uri.AbsolutePath.Trim('/') -split '/')[-1])
    $cleanVersion = "$($manifest.version)" -replace '[^\w.-]', ''
    $source = Join-Path $TempDirectory "v$cleanVersion-$name"
    if (-not $entries.ContainsKey($source)) {
        $entries[$source] = @()
    }
    $entries[$source] += [PSCustomObject]@{
        Manifest = $file.Name
        Url      = $manifest.url
        Version  = [string]$manifest.version
        Hash     = ([string]$manifest.hash).ToLower()
    }
}

foreach ($entry in $entries.GetEnumerator()) {
    $source = $entry.Key
    $manifests = @($entry.Value)
    if (-not (Test-Path $source)) {
        continue
    }

    $hash = (Get-FileHash $source -Algorithm SHA256).Hash.ToLower()
    $expectedHashes = @($manifests.Hash | Sort-Object -Unique)
    if ($expectedHashes.Count -ne 1 -or $hash -ne $expectedHashes[0]) {
        Write-Warning "Skipping cache entry with hash mismatch or conflict: $source"
        continue
    }

    $destinations = @($manifests | ForEach-Object {
            Get-ManifestArtifactPath -DownloadUrl $_.Url -Version $_.Version
        } | Sort-Object -Unique)
    foreach ($destination in $destinations) {
        New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Force
        $destinationHash = (Get-FileHash $destination -Algorithm SHA256).Hash.ToLower()
        if ($destinationHash -ne $hash) {
            throw "Migration verification failed: $destination"
        }
        Write-Host "migrated: $source -> $destination"
    }

    if ($RemoveSource) {
        Remove-Item -LiteralPath $source -Force
        Write-Host "removed: $source"
    }
}

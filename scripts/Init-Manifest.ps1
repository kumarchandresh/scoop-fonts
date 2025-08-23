param (
    [Parameter(Position = 0)]
    [string[]]$Fonts, # regexes
    [Parameter()]
    [switch]$Force,
    [Parameter()]
    [switch]$NoNerdFont,
    [Parameter()]
    [switch]$NoCheckVer,
    [Parameter()]
    [switch]$Clean
)

Set-StrictMode -Version 1

$allFonts = [ordered]@{}

Import-Module -Force "$PSScriptRoot\Modules\NerdFonts.psm1"
(Get-NerdFonts).GetEnumerator() | ForEach-Object { $allFonts[$_.Key] = $_.Value }

Import-Module -Force "$PSScriptRoot\Modules\Iosevka.psm1"
(Get-IosevkaFonts).GetEnumerator() | ForEach-Object { $allFonts[$_.Key] = $_.Value }

Get-ChildItem "$PSScriptRoot\..\bucket" -Filter '*.json' | ForEach-Object {
    if (-not $allFonts.Contains($_.BaseName)) {
        if ($Clean) {
            Write-Host "unmanaged manifest deprecated: $($_.BaseName)" -ForegroundColor Yellow
            Copy-Item -Path $_.FullName -Destination "$PSScriptRoot\deprecated\$($_.BaseName).json"
        } else {
            Write-Host "unmanaged manifest detected: $($_.BaseName)" -ForegroundColor DarkGray
        }
    }
}

$installerContent = Get-Content "$PSScriptRoot\installer.ps1"
$installer = @()
foreach ($line in $installerContent) {
    if ([string]::IsNullOrEmpty($line)) {
        continue
    }
    if ($line -match '^\s*#') {
        continue
    }
    $installer += $line
}

$uninstallerContent = Get-Content "$PSScriptRoot\uninstaller.ps1"
$uninstaller = @()
foreach ($line in $uninstallerContent) {
    if ([string]::IsNullOrEmpty($line)) {
        continue
    }
    if ($line -match '^\s*#') {
        continue
    }
    $uninstaller += $line
}

$cache = @{}
$hashes = @{}
$releases = @{}

$lastApiCall = $null
$apiCallInterval = 500 # milliseconds

function Invoke-RateLimitedRestMethod {
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [Parameter(Mandatory)]
        [hashtable]$Headers
    )

    if ($script:lastApiCall) {
        $elapsed = (Get-Date) - $script:lastApiCall
        if ($elapsed.TotalMilliseconds -lt $script:apiCallInterval) {
            Start-Sleep -Milliseconds ($script:apiCallInterval - $elapsed.TotalMilliseconds)
        }
    }

    $script:lastApiCall = Get-Date
    return Invoke-RestMethod -Uri $Uri -Headers $Headers
}

$formatjson = "$PSScriptRoot\..\bin\formatjson.ps1"

foreach ($fontEntry in $allFonts.GetEnumerator()) {
    $var = $fontEntry.Value
    $var.Name = $fontEntry.Key


    if (-not $var.ContainsKey('Filter')) {
        $var.Filter = '.*'
    }

    if ($Fonts.Count -ne 0 -and $Fonts.Where({ $var.Name -match $_ }).Count -eq 0) {
        continue
    }

    if ($NoNerdFont -and $var.Name -match 'NerdFont(Mono|Propo)?') {
        continue
    }

    $file = "$PSScriptRoot\..\bucket\$($var.Name).json"
    if (-not (Test-Path $file) -or $Force) {

        Write-Host ''
        Write-Host "manifest: $($var.Name).json" -ForegroundColor Green
        Write-Host "homepage: https://github.com/$($var.Repo)"

        $headers = @{
            "User-Agent" = "PowerShell"
            "Accept"     = "application/vnd.github.v3+json"
        }
        if ($env:GITHUB_TOKEN) {
            $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
        }

        $originRepo = if ( $null -eq $var.Origin ) { $var.Repo } else { $var.Origin }
        $cacheKey = $originRepo.ToLower()

        if ($cache.ContainsKey($cacheKey)) {
            $repo = $cache[$cacheKey].Repo
            $license = $cache[$cacheKey].License
        } else {
            $repo = Invoke-RateLimitedRestMethod -Uri "https://api.github.com/repos/$($originRepo)" -Headers $headers
            $license = Invoke-RateLimitedRestMethod -Uri "https://api.github.com/repos/$($originRepo)/license" -Headers $headers |
            Select-Object @{ Name = "License"; Expression = { $_.license.spdx_id } } |
            Select-Object -ExpandProperty License
            if ('NOASSERTION' -eq $license) {
                $license = $var.License
            }
            $cache[$cacheKey] = @{Repo = $repo; License = $license }
        }

        if ($null -eq $repo) {
            Write-Host "Failed to retrieve repository info for $($var.Repo)" -ForegroundColor Red
            continue
        }

        $description = if ($null -ne $var.Desc) { $var.Desc } else { $repo.description }
        Write-Host "description: $description"

        if ($null -eq $license) {
            Write-Host "Failed to retrieve license info for repository $($var.Repo)" -ForegroundColor Red
            continue
        }
        Write-Host "license: $license"

        $releaseUrl = "https://api.github.com/repos/$($var.Repo)/releases"
        $urlKey = $releaseUrl.ToLower()

        if ($releases.ContainsKey($urlKey)) {
            $releaseInfo = $releases[$urlKey]
        } else {
            $releaseInfo = Invoke-RateLimitedRestMethod -Uri $releaseUrl -Headers $headers

            if ($null -eq $releaseInfo) {
                Write-Host "Failed to retrieve release info for repository $($var.Repo)" -ForegroundColor Red
                continue
            }
            $releases[$urlKey] = $releaseInfo
        }

        $downloadUrl = $releaseInfo | ForEach-Object { $_.assets.browser_download_url } | Where-Object { $_ -match $var.Regex } | Select-Object -First 1

        if ($null -eq $downloadUrl) {
            Write-Host "Failed to find download url matching regex '$($var.Regex)' in repository $($var.Repo)" -ForegroundColor Red
            continue
        }
        Write-Host "url: $downloadUrl"

        $regex = [regex]::new($var.Regex)
        $match = $regex.Match($downloadUrl)

        # Handle multiple capture groups for complex versioning schemes
        if ($match.Success -and $match.Groups.Count -gt 1) {
            if ($match.Groups.Count -gt 2) {
                # Multiple capture groups - create composite version from all available groups
                if ($null -ne $var.Version) {
                    $version = $var.Version
                    for ($i = 1; $i -le $match.Groups.Count - 1; $i++) {
                        $version = $version -replace [regex]::Escape('${' + $match.Groups[$i].Name + '}'), $match.Groups[$i].Value
                    }
                } else {
                    $versionParts = @()
                    for ($i = 1; $i -le $match.Groups.Count - 1; $i++) {
                        $versionParts += $match.Groups[$i].Value
                    }
                    $version = $versionParts -join '.'
                }
            } else {
                # Single capture group - use it as version
                $version = $match.Groups[1].Value
            }
        } else {
            $version = $null
        }

        if ($null -eq $version) {
            Write-Host "Failed to retrieve version info for $($var.Repo)" -ForegroundColor Red
            continue
        }
        Write-Host "version: $version"

        # Generate autoupdate URL with appropriate variable substitutions
        if ($match.Groups.Count -gt 2) {
            # Multiple capture groups - replace each group with $match1, $match2, etc.
            $versionUrl = $downloadUrl
            for ($i = 1; $i -le $match.Groups.Count - 1; $i++) {
                $groupValue = $match.Groups[$i].Value
                $versionUrl = $versionUrl -replace [regex]::Escape($groupValue), "`$match$i"
            }
        } else {
            $underscoreVersion = $version -replace [regex]::Escape('.'), '_'
            $dashVersion = $version -replace [regex]::Escape('.'), '-'
            $cleanVersion = $version -replace [regex]::Escape('.'), ''
            # Single capture group - use standard version variables
            $versionUrl = $downloadUrl -replace [regex]::Escape($version), '$version'
            $versionUrl = $versionUrl -replace [regex]::Escape($underscoreVersion), '$underscoreVersion'
            $versionUrl = $versionUrl -replace [regex]::Escape($dashVersion), '$dashVersion'
            $versionUrl = $versionUrl -replace [regex]::Escape($cleanVersion), '$cleanVersion'
        }

        $cacheKey = $downloadUrl.toLower()
        if ($hashes.ContainsKey($cacheKey)) {
            $hash = $hashes[$cacheKey]
        } else {
            $name = $downloadUrl -split '/' | Select-Object -Last 1
            $cleanVer = "$version" -replace '[^\w.-]', ''
            $outfile = Join-Path ${env:TEMP} "v$cleanVer-$name"
            if (-not (Test-Path $outfile)) {
                Invoke-WebRequest -Uri $downloadUrl -Headers $headers -OutFile $outfile
            } else {
            }
            if (-not (Test-Path $outfile)) {
                Write-Host "Failed to download file from $downloadUrl" -ForegroundColor Red
                continue
            }
            $hash = (Get-FileHash $outfile -Algorithm SHA256).Hash.ToLower()
            $hashes[$cacheKey] = $hash
        }

        if ($null -eq $hash) {
            Write-Host "Failed to retrieve hash for $($var.Repo)" -ForegroundColor Red
            continue
        }
        Write-Host "hash: $hash"

        $manifest = [ordered]@{
            "version"     = $version
            "description" = $description
            "homepage"    = "https://github.com/$($var.Repo)"
            "license"     = $license
            "url"         = $downloadUrl
            "hash"        = $hash
            "extract_dir" = $var.Dir
            "installer"   = @{
                "script" = @('$filter = ' + "'$($var.Filter)'")
            }
            "uninstaller" = @{
                "script" = @('$filter = ' + "'$($var.Filter)'")
            }
            "checkver"    = [ordered]@{
                "url"      = $releaseUrl
                "jsonpath" = '$[*].assets[*].browser_download_url'
                "regex"    = $var.Regex
            }
            "autoupdate"  = [ordered]@{
                "url" = $versionUrl
            }
        }

        # Add replace directive for fonts with multiple capture groups to generate composite version
        if ($match.Groups.Count -gt 2) {
            if ($null -ne $var.Version) {
                $manifest.checkver["replace"] = $var.Version
            } else {
                $replacePattern = @()
                for ($i = 1; $i -le $match.Groups.Count - 1; $i++) {
                    $replacePattern += "`${$i}"
                }
                $manifest.checkver["replace"] = $replacePattern -join '.'
            }
        }

        foreach ($line in $installer) {
            $manifest.installer.script += $line
        }

        foreach ($line in $uninstaller) {
            $manifest.uninstaller.script += $line
        }

        $cleanManifest = [ordered]@{}
        $manifest.GetEnumerator() | Where-Object { $null -ne $_.Value } | ForEach-Object {
            $cleanManifest[$_.Key] = $_.Value
        }
        # $cleanManifest | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 -Path $file
        ConvertTo-Json $cleanManifest | Out-File -Encoding utf8 -FilePath $file

        $app = [System.IO.Path]::GetFileNameWithoutExtension($file)

        & "$formatjson" $app
    }


    if (-not $NoCheckVer) {
        & "$PSScriptRoot\..\bin\checkver.ps1" $file -u
    }

}

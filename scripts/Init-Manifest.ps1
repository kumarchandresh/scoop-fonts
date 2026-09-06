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

$ROOT_DIR = Join-Path $PSScriptRoot ".." -Resolve

Import-Module -Force "$PSScriptRoot\Modules\ManifestDeclarations.psm1"
Import-Module -Force "$PSScriptRoot\Modules\ManifestInventory.psm1"
Import-Module -Force "$PSScriptRoot\Modules\ManifestSources.psm1"
$allFonts = Get-AllFontDeclarations

Test-ManifestInventory -Declarations $allFonts -BucketDir "$ROOT_DIR\bucket" -DeprecatedDir "$ROOT_DIR\deprecated" -Clean:$Clean

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

$rateLimitState = @{ LastApiCall = $null; ApiCallInterval = 500 }

$formatjson = "$PSScriptRoot\..\bin\formatjson.ps1"

foreach ($fontEntry in $allFonts.GetEnumerator()) {
    $var = $fontEntry.Value
    $var.Name = $fontEntry.Key


    if (-not $var.ContainsKey('Filter')) {
        Write-Error "missing filter: $($var.Name)"
        continue
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

        $headers = New-GitHubHeaders

        $originRepo = if ( $null -eq $var.Origin ) { $var.Repo } else { $var.Origin }
        $metadata = Get-GitHubRepositoryMetadata -Repository $originRepo -Headers $headers -Cache $cache -RateLimitState $rateLimitState -FallbackLicense $var.License
        $repo = $metadata.Repo
        $license = $metadata.License
        if ($var.ContainsKey('License')) {
            $license = $var.License
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

        $useLatest = $var.ContainsKey('Latest') -and $var.Latest
        $release = Get-GitHubReleaseData -Repository $var.Repo -Latest $useLatest -Headers $headers -Cache $releases -RateLimitState $rateLimitState
        if ($null -eq $release) {
            Write-Host "Failed to retrieve release info for repository $($var.Repo)" -ForegroundColor Red
            continue
        }
        $releaseInfo = $release.Info
        $releaseUrl = $release.Url
        $jsonPath = $release.JsonPath

        $downloadUrl = Find-GitHubDownloadUrl -ReleaseInfo $releaseInfo -Latest $useLatest -Regex $var.Regex

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

        $hash = Get-ManifestArtifactHash -DownloadUrl $downloadUrl -Version $version -Headers $headers -Cache $hashes
        if ($null -eq $hash) {
            Write-Host "Failed to download file from $downloadUrl" -ForegroundColor Red
            continue
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
                "jsonpath" = $jsonPath
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

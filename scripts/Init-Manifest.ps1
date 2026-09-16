param (
    [Parameter(Position = 0)]
    [string[]]$Fonts, # regexes
    [Parameter()]
    [string[]]$Module,
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

Import-Module -Force "$PSScriptRoot\Modules\ManifestSources.psm1"
Import-Module -Force "$PSScriptRoot\Modules\ManifestDeclarations.psm1"
Import-Module -Force "$PSScriptRoot\Modules\ManifestInventory.psm1"
Import-Module -Force "$PSScriptRoot\Modules\ManifestRenderer.psm1"

$allFonts = Get-AllFontDeclarations -Force:$Force

Test-ManifestInventory -Declarations $allFonts -BucketDir "$ROOT_DIR\bucket" -DeprecatedDir "$ROOT_DIR\deprecated" -Clean:$Clean

$installerLines = @(Get-Content "$PSScriptRoot\installer.ps1" | Where-Object { $_ -and $_ -notmatch '^\s*#' })
$uninstallerLines = @(Get-Content "$PSScriptRoot\uninstaller.ps1" | Where-Object { $_ -and $_ -notmatch '^\s*#' })

$cache = @{}
$hashes = @{}
$releases = @{}

$formatjson = "$PSScriptRoot\..\bin\formatjson.ps1"

$failedManifests = [System.Collections.Generic.List[PSCustomObject]]::new()

function Add-ManifestFailure {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$Stage,
        [Parameter(Mandatory)]
        [string]$Reason
    )
    $failedManifests.Add([PSCustomObject]@{
            Name   = $Name
            Stage  = $Stage
            Reason = $Reason
        })
    Write-Host "Failed [$Stage] for $($Name): $Reason" -ForegroundColor Red
}

Show-GitHubRateLimit

$scoopAuth = if (-not $NoCheckVer) { Enable-ScoopGitHubAuthForCheckver }
try {
    foreach ($fontEntry in $allFonts.GetEnumerator()) {
        $var = $fontEntry.Value
        $var.Name = $fontEntry.Key

        if ($Module -and $Module.Count -ne 0 -and $Module.Where({ $var.ContainsKey('Module') -and ($var.Module -match "^$([regex]::Escape($_))$" -or $var.Module -match $_) }).Count -eq 0) {
            continue
        }

        if ($Fonts.Count -ne 0 -and $Fonts.Where({ $var.Name -match $_ -or ($var.ContainsKey('Module') -and $var.Module -match "^$([regex]::Escape($_))$") }).Count -eq 0) {
            continue
        }

        if (-not $var.ContainsKey('Filter')) {
            Add-ManifestFailure -Name $var.Name -Stage 'Declaration' -Reason 'Missing Filter property'
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
            $metadata = Get-GitHubRepositoryMetadata -Repository $originRepo -Headers $headers -Cache $cache -FallbackLicense $var.License
            $repo = $metadata.Repo
            $license = $metadata.License
            if ($var.ContainsKey('License')) {
                $license = $var.License
            }

            if ($null -eq $repo) {
                Add-ManifestFailure -Name $var.Name -Stage 'Repository' -Reason "Failed to retrieve repository info for $($var.Repo)"
                continue
            }

            $description = if ($null -ne $var.Desc) { $var.Desc } else { $repo.description }
            if ([string]::IsNullOrWhiteSpace($description)) {
                Add-ManifestFailure -Name $var.Name -Stage 'Description' -Reason "Failed to retrieve description for repository $($var.Repo). Please specify 'Desc' in the font module."
                continue
            }
            Write-Host "description: $description"

            if ($null -eq $license) {
                Add-ManifestFailure -Name $var.Name -Stage 'License' -Reason "Failed to retrieve license info for repository $($var.Repo)"
                continue
            }
            Write-Host "license: $license"

            $useLatest = $var.ContainsKey('Latest') -and $var.Latest
            $release = Get-GitHubReleaseData -Repository $var.Repo -Latest $useLatest -Headers $headers -Cache $releases
            if ($null -eq $release) {
                Add-ManifestFailure -Name $var.Name -Stage 'Release' -Reason "Failed to retrieve release info for repository $($var.Repo)"
                continue
            }
            $releaseInfo = $release.Info
            $releaseUrl = $release.Url
            $jsonPath = $release.JsonPath

            try {
                $downloadUrl = Find-GitHubDownloadUrl -ReleaseInfo $releaseInfo -Latest $useLatest -Regex $var.Regex
            } catch {
                Add-ManifestFailure -Name $var.Name -Stage 'Asset Resolution' -Reason $_.Exception.Message
                continue
            }

            if ($null -eq $downloadUrl) {
                Add-ManifestFailure -Name $var.Name -Stage 'Asset Resolution' -Reason "Failed to find download url matching regex '$($var.Regex)' in repository $($var.Repo)"
                continue
            }
            Write-Host "url: $downloadUrl"

            $versionInfo = Get-ManifestVersionInfo -Regex $var.Regex -DownloadUrl $downloadUrl -VersionTemplate $var.Version
            if ($null -eq $versionInfo) {
                Add-ManifestFailure -Name $var.Name -Stage 'Version' -Reason "Failed to retrieve version info for $($var.Repo)"
                continue
            }
            $version = $versionInfo.Version
            Write-Host "version: $version"

            $hash = Get-ManifestArtifactHash -DownloadUrl $downloadUrl -Version $version -Headers $headers -Cache $hashes
            if ($null -eq $hash) {
                Add-ManifestFailure -Name $var.Name -Stage 'Download' -Reason "Failed to download file or compute hash from $downloadUrl"
                continue
            }
            Write-Host "hash: $hash"

            $manifestParams = @{
                Declaration      = $var
                VersionInfo      = $versionInfo
                Release          = $release
                Description      = $description
                License          = $license
                Hash             = $hash
                DownloadUrl      = $downloadUrl
                InstallerLines   = $installerLines
                UninstallerLines = $uninstallerLines
            }
            try {
                $manifest = New-ScoopManifest @manifestParams
            } catch {
                Add-ManifestFailure -Name $var.Name -Stage 'Manifest Rendering' -Reason $_.Exception.Message
                continue
            }

            ConvertTo-Json $manifest | Out-File -Encoding utf8 -FilePath $file

            $app = [System.IO.Path]::GetFileNameWithoutExtension($file)

            & "$formatjson" $app
        }

        if (-not $NoCheckVer) {
            & "$PSScriptRoot\..\bin\checkver.ps1" $file -u
        }
    }
} finally {
    Disable-ScoopGitHubAuthForCheckver $scoopAuth
}

Show-GitHubRateLimit

if ($failedManifests.Count -gt 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Manifest generation failed for $($failedManifests.Count) manifest(s):" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    foreach ($fail in $failedManifests) {
        Write-Host "  • [$($fail.Stage)] $($fail.Name): $($fail.Reason)" -ForegroundColor Yellow
    }
    Write-Host ""
    exit 1
}

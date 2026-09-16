function Get-ManifestVersionInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Regex,
        [Parameter(Mandatory)]
        [string]$DownloadUrl,
        [Parameter()]
        [string]$VersionTemplate
    )

    $match = [regex]::new($Regex).Match($DownloadUrl)
    if (-not $match.Success -or $match.Groups.Count -le 1) {
        return $null
    }

    if ($match.Groups.Count -gt 2) {
        if ($VersionTemplate) {
            $version = $VersionTemplate
            for ($i = 1; $i -lt $match.Groups.Count; $i++) {
                $version = $version -replace [regex]::Escape('${' + $match.Groups[$i].Name + '}'), $match.Groups[$i].Value
            }
            $replacePattern = $VersionTemplate
        } else {
            $parts = for ($i = 1; $i -lt $match.Groups.Count; $i++) {
                $match.Groups[$i].Value
            }
            $version = $parts -join '.'

            $replaceParts = for ($i = 1; $i -lt $match.Groups.Count; $i++) {
                "`${$i}"
            }
            $replacePattern = $replaceParts -join '.'
        }

        $versionUrl = $DownloadUrl
        for ($i = 1; $i -lt $match.Groups.Count; $i++) {
            $versionUrl = $versionUrl -replace [regex]::Escape($match.Groups[$i].Value), "`$match$i"
        }
    } else {
        $version = $match.Groups[1].Value
        $underscoreVersion = $version -replace [regex]::Escape('.'), '_'
        $dashVersion = $version -replace [regex]::Escape('.'), '-'
        $cleanVersion = $version -replace [regex]::Escape('.'), ''
        $versionUrl = $DownloadUrl -replace [regex]::Escape($version), '$version' `
            -replace [regex]::Escape($underscoreVersion), '$underscoreVersion' `
            -replace [regex]::Escape($dashVersion), '$dashVersion' `
            -replace [regex]::Escape($cleanVersion), '$cleanVersion'
        $replacePattern = $null
    }

    return [PSCustomObject]@{
        Version         = $version
        VersionUrl      = $versionUrl
        CheckverReplace = $replacePattern
    }
}

function New-ScoopManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Declaration,
        [Parameter(Mandatory)]
        $VersionInfo,
        [Parameter(Mandatory)]
        $Release,
        [Parameter(Mandatory)]
        [string]$Description,
        [Parameter(Mandatory)]
        [string]$License,
        [Parameter(Mandatory)]
        [string]$Hash,
        [Parameter(Mandatory)]
        [string]$DownloadUrl,
        [Parameter(Mandatory)]
        [string[]]$InstallerLines,
        [Parameter(Mandatory)]
        [string[]]$UninstallerLines
    )

    $manifest = [ordered]@{
        'version'     = $VersionInfo.Version
        'description' = $Description
        'homepage'    = "https://github.com/$($Declaration.Repo)"
        'license'     = $License
        'url'         = $DownloadUrl
        'hash'        = $Hash
    }

    if ($Declaration.Dir) {
        $manifest['extract_dir'] = $Declaration.Dir
    }

    $manifest['installer'] = @{
        'script' = @("`$filter = '$($Declaration.Filter)'") + $InstallerLines
    }
    $manifest['uninstaller'] = @{
        'script' = @("`$filter = '$($Declaration.Filter)'") + $UninstallerLines
    }

    $manifest['checkver'] = [ordered]@{
        'url'      = $Release.Url
        'jsonpath' = $Release.JsonPath
        'regex'    = $Declaration.Regex
    }
    if ($VersionInfo.CheckverReplace) {
        $manifest.checkver['replace'] = $VersionInfo.CheckverReplace
    }

    $manifest['autoupdate'] = [ordered]@{
        'url' = $VersionInfo.VersionUrl
    }

    return $manifest
}

function New-ScoopManifest {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Declaration,
        [Parameter(Mandatory)]
        [string]$Version,
        [Parameter(Mandatory)]
        [string]$Description,
        [Parameter(Mandatory)]
        [string]$License,
        [Parameter(Mandatory)]
        [string]$Hash,
        [Parameter(Mandatory)]
        [string]$DownloadUrl,
        [Parameter(Mandatory)]
        [string]$ReleaseUrl,
        [Parameter(Mandatory)]
        [string]$JsonPath,
        [Parameter(Mandatory)]
        [string]$VersionUrl,
        [Parameter(Mandatory)]
        [System.Text.RegularExpressions.Match]$Match,
        [Parameter(Mandatory)]
        [string[]]$InstallerLines,
        [Parameter(Mandatory)]
        [string[]]$UninstallerLines
    )

    $manifest = [ordered]@{
        "version"     = $Version
        "description" = $Description
        "homepage"    = "https://github.com/$($Declaration.Repo)"
        "license"     = $License
        "url"         = $DownloadUrl
        "hash"        = $Hash
        "extract_dir" = $Declaration.Dir
        "installer"   = @{
            "script" = @("`$filter = '$($Declaration.Filter)'")
        }
        "uninstaller" = @{
            "script" = @("`$filter = '$($Declaration.Filter)'")
        }
        "checkver"    = [ordered]@{
            "url"      = $ReleaseUrl
            "jsonpath" = $JsonPath
            "regex"    = $Declaration.Regex
        }
        "autoupdate"  = [ordered]@{
            "url" = $VersionUrl
        }
    }

    if ($Match.Groups.Count -gt 2) {
        if ($null -ne $Declaration.Version) {
            $manifest.checkver["replace"] = $Declaration.Version
        } else {
            $replacePattern = @()
            for ($i = 1; $i -le $Match.Groups.Count - 1; $i++) {
                $replacePattern += "`${$i}"
            }
            $manifest.checkver["replace"] = $replacePattern -join '.'
        }
    }

    $manifest.installer.script += $InstallerLines
    $manifest.uninstaller.script += $UninstallerLines

    return $manifest
}

if (!$env:SCOOP_HOME) { $env:SCOOP_HOME = Convert-Path (scoop prefix scoop) }
$checkver = "$env:SCOOP_HOME/bin/checkver.ps1"
$dir = "$PSScriptRoot/../bucket" # checks the parent dir

$configHome = $env:XDG_CONFIG_HOME, "$([System.Environment]::GetFolderPath('UserProfile'))\.config" | Where-Object { $_ } | Select-Object -First 1
$configFile = Join-Path $configHome 'scoop\config.json'
$cfg = if (Test-Path -LiteralPath $configFile) {
    try { Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json } catch { $null }
} else { $null }

$token = $env:SCOOP_GH_TOKEN, ($cfg.gh_token), $env:GH_TOKEN, $env:GITHUB_TOKEN |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Select-Object -First 1

if ($token -and $cfg) {
    try {
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
            try {
                & $checkver -Dir $dir @Args
            } finally {
                $cfg = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
                if ($null -ne $origHosts) {
                    $cfg.private_hosts = $origHosts
                } else {
                    $cfg.PSObject.Properties.Remove('private_hosts')
                }
                $cfg | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configFile
            }
            exit $LASTEXITCODE
        }
    } catch {}
}

& $checkver -Dir $dir @Args

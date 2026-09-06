param(
    [Parameter(Position = 0)]
    [string]$Module,
    [Parameter()]
    [switch]$All,
    [Parameter()]
    [string]$Filter
)

Set-StrictMode -Version 1
$ErrorActionPreference = 'Stop'

$fontsDir = Join-Path $PSScriptRoot 'Fonts'
$modules = @(Get-ChildItem -LiteralPath $fontsDir -Filter '*.psm1' | Sort-Object Name)

if ($Module) {
    $targetName = $Module -replace '\.psm1$', ''
    $matched = @($modules | Where-Object { $_.BaseName -like "*$targetName*" })
    if ($matched.Count -eq 0) {
        $available = ($modules | ForEach-Object { $_.BaseName }) -join ', '
        Write-Error "Font module '$Module' not found. Available modules: $available" -ErrorAction Stop
    }
    $modules = $matched
} elseif (-not $All) {
    Write-Host "Available Font Modules:" -ForegroundColor Cyan
    foreach ($m in $modules) {
        Write-Host "  - $($m.BaseName)"
    }
    Write-Host "`nUsage: .\scripts\Inspect-FontResources.ps1 <ModuleName> [-Filter <Regex>]" -ForegroundColor DarkGray
    Write-Host "       .\scripts\Inspect-FontResources.ps1 -All" -ForegroundColor DarkGray
    return
}

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($m in $modules) {
    Import-Module -Force $m.FullName
    $fnName = "Get-$($m.BaseName)Resources"
    if (-not (Get-Command -Name $fnName -ErrorAction SilentlyContinue)) {
        Write-Warning "No declaration function found in $($m.Name)"
        continue
    }

    $declarations = & $fnName
    foreach ($entry in $declarations.GetEnumerator()) {
        $name = $entry.Key
        if ($Filter -and ($name -notmatch $Filter)) {
            continue
        }
        $val = $entry.Value
        $results.Add([PSCustomObject]@{
            Module = $m.BaseName
            Font   = $name
            Repo   = $val.Repo
            Regex  = $val.Regex
            Filter = $val.Filter
            Dir    = $val.Dir
        })
    }
}

if ($results.Count -gt 0) {
    Write-Host "Found $($results.Count) font resource declaration(s):`n" -ForegroundColor Green
    $results | Format-Table -Property Font, Repo, Regex, Filter, Dir -AutoSize
} else {
    Write-Host "No font resource declarations matched criteria." -ForegroundColor Yellow
}

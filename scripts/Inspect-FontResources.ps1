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

Import-Module -Force "$PSScriptRoot\Modules\ManifestDeclarations.psm1"

$fontsDir = Join-Path $PSScriptRoot 'Fonts'

if (-not $Module -and -not $All) {
    $modules = @(Get-ChildItem -LiteralPath $fontsDir -Filter '*.psm1' | Sort-Object Name)
    Write-Host "Available Font Modules:" -ForegroundColor Cyan
    foreach ($m in $modules) {
        Write-Host "  - $($m.BaseName)"
    }
    Write-Host "`nUsage: .\scripts\Inspect-FontResources.ps1 <ModuleName> [-Filter <Regex>]" -ForegroundColor DarkGray
    Write-Host "       .\scripts\Inspect-FontResources.ps1 -All" -ForegroundColor DarkGray
    return
}

$declarations = Get-AllFontDeclarations -FontsDirectory $fontsDir -ModuleFilter $Module

if ($Module -and $declarations.Count -eq 0) {
    $available = (Get-ChildItem -LiteralPath $fontsDir -Filter '*.psm1' | ForEach-Object { $_.BaseName }) -join ', '
    Write-Error "Font module '$Module' not found or has no declarations. Available modules: $available" -ErrorAction Stop
}

$results = [System.Collections.Generic.List[PSCustomObject]]::new()
foreach ($entry in $declarations.GetEnumerator()) {
    if ($Filter -and ($entry.Key -notmatch $Filter)) {
        continue
    }
    $val = $entry.Value
    $results.Add([PSCustomObject]@{
            Module = $val.Module
            Font   = $entry.Key
            Repo   = $val.Repo
            Regex  = $val.Regex
            Filter = $val.Filter
            Dir    = $val.Dir
        })
}

if ($results.Count -gt 0) {
    Write-Host "Found $($results.Count) font resource declaration(s):`n" -ForegroundColor Green
    $results | Format-Table -Property Font, Repo, Regex, Filter, Dir -AutoSize
} else {
    Write-Host "No font resource declarations matched criteria." -ForegroundColor Yellow
}


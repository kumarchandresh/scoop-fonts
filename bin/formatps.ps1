<#
.SYNOPSIS
    Formats PowerShell files (.ps1, .psm1, .psd1) in the repository using PSScriptAnalyzer.

.DESCRIPTION
    Invokes PSScriptAnalyzer's Invoke-Formatter using the repository's PSScriptAnalyzerSettings.psd1.
    Supports targeting specific paths, running in dry-run check mode (-Check), and recursive formatting.

.PARAMETER Path
    One or more file or directory paths to format. If not specified, defaults to all PowerShell files in the repository.

.PARAMETER Check
    Dry-run mode. Checks if files are properly formatted without modifying them.
    Exits with code 1 if any files require formatting (useful for CI/pre-commit).

.EXAMPLE
    .\bin\formatps.ps1
    Formats all PowerShell scripts in the repository.

.EXAMPLE
    .\bin\formatps.ps1 -Check
    Verifies that all PowerShell scripts are properly formatted without modifying them.

.EXAMPLE
    .\bin\formatps.ps1 -Path .\scripts\Init-Manifest.ps1
    Formats a specific script.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Path,
    [switch]$Check
)

$repoRoot = (Resolve-Path "$PSScriptRoot/..").Path

# Ensure PSScriptAnalyzer is available
if (-not (Get-Module -Name PSScriptAnalyzer)) {
    Import-Module PSScriptAnalyzer -ErrorAction SilentlyContinue
}

if (-not (Get-Command -Name Invoke-Formatter -ErrorAction SilentlyContinue)) {
    Write-Error "PSScriptAnalyzer module is required to format PowerShell scripts.`nInstall it by running: Install-PSResource PSScriptAnalyzer -TrustRepository -Scope CurrentUser"
    exit 1
}

# Resolve settings file
$settingsPath = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'
if (-not (Test-Path -LiteralPath $settingsPath)) {
    $settingsPath = 'CodeFormattingOTBS'
}

# Collect target files
$targetFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
$extensions = @('.ps1', '.psm1', '.psd1')

if ($Path -and $Path.Count -gt 0) {
    foreach ($p in $Path) {
        $resolved = Resolve-Path -LiteralPath $p -ErrorAction SilentlyContinue
        if (-not $resolved) {
            Write-Warning "Path not found: $p"
            continue
        }
        foreach ($r in $resolved) {
            $itemPath = $r.Path
            if (Test-Path -LiteralPath $itemPath -PathType Leaf) {
                $ext = [System.IO.Path]::GetExtension($itemPath)
                if ($extensions -contains $ext) {
                    $targetFiles.Add([System.IO.FileInfo]::new($itemPath))
                }
            } elseif (Test-Path -LiteralPath $itemPath -PathType Container) {
                Get-ChildItem -LiteralPath $itemPath -Recurse -File |
                    Where-Object { $extensions -contains $_.Extension -and $_.FullName -notmatch '[\\/](\.git|deprecated)[\\/]' } |
                    ForEach-Object { $targetFiles.Add($_) }
            }
        }
    }
} else {
    Get-ChildItem -LiteralPath $repoRoot -Recurse -File |
        Where-Object { $extensions -contains $_.Extension -and $_.FullName -notmatch '[\\/](\.git|deprecated)[\\/]' } |
        ForEach-Object { $targetFiles.Add($_) }
}

if ($targetFiles.Count -eq 0) {
    Write-Host "No PowerShell files found to check." -ForegroundColor Yellow
    exit 0
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$needsFormatting = [System.Collections.Generic.List[string]]::new()
$formattedFiles = [System.Collections.Generic.List[string]]::new()

foreach ($file in $targetFiles) {
    $relPath = [System.IO.Path]::GetRelativePath($repoRoot, $file.FullName)
    $content = [System.IO.File]::ReadAllText($file.FullName)

    $formatted = Invoke-Formatter -ScriptDefinition $content -Settings $settingsPath

    # Ensure single trailing newline if original or formatted content is non-empty
    if ($formatted.Length -gt 0 -and -not $formatted.EndsWith("`n")) {
        $formatted += [System.Environment]::NewLine
    }

    if ($content -ne $formatted) {
        if ($Check) {
            $needsFormatting.Add($relPath)
            Write-Host "Needs formatting : $relPath" -ForegroundColor Yellow
        } else {
            [System.IO.File]::WriteAllText($file.FullName, $formatted, $utf8NoBom)
            $formattedFiles.Add($relPath)
            Write-Host "Formatted        : $relPath" -ForegroundColor Green
        }
    } else {
        Write-Verbose "Clean            : $relPath"
    }
}

Write-Host ""
if ($Check) {
    if ($needsFormatting.Count -gt 0) {
        Write-Host "$($needsFormatting.Count) file(s) need formatting out of $($targetFiles.Count) checked." -ForegroundColor Red
        Write-Host "Run '.\bin\formatps.ps1' to format all scripts." -ForegroundColor DarkGray
        exit 1
    } else {
        Write-Host "All $($targetFiles.Count) PowerShell file(s) are correctly formatted." -ForegroundColor Green
        exit 0
    }
} else {
    if ($formattedFiles.Count -gt 0) {
        Write-Host "Successfully formatted $($formattedFiles.Count) file(s) out of $($targetFiles.Count)." -ForegroundColor Green
    } else {
        Write-Host "All $($targetFiles.Count) PowerShell file(s) are already properly formatted." -ForegroundColor Green
    }
    exit 0
}

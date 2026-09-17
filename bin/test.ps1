#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'BuildHelpers'; ModuleVersion = '2.0.1' }
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.2.0' }

# Prevent BuildHelpers .NET pipe deadlock on large diffs in CI
if ($env:CI -eq $true) {
    function global:Get-GitChangedFile {
        [cmdletbinding()]
        param(
            $Path = $PWD.Path,
            $Commit,
            $LeftRevision,
            $RightRevision,
            $RangeNotation = '...',
            $RawRevisionString,
            $Include,
            $Exclude,
            [switch]$Resolve
        )
        $resolvedPath = (Resolve-Path $Path).Path
        $gitRoot = (git -C $resolvedPath rev-parse --show-toplevel 2>$null)
        if (-not $gitRoot) { $gitRoot = $resolvedPath }

        $normalizedGitRoot = $gitRoot.TrimEnd('\', '/')
        $relPath = if ($resolvedPath.StartsWith($normalizedGitRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $resolvedPath.Substring($normalizedGitRoot.Length).TrimStart('\', '/').Replace('\', '/')
        } else {
            ''
        }
        $pathFilter = if ($relPath -and $relPath -ne '.') { @('--', $relPath) } else { @() }

        $rev = if ($Commit) {
            "$Commit^..$Commit"
        } elseif ($LeftRevision -and $RightRevision) {
            "$LeftRevision$RangeNotation$RightRevision"
        } elseif ($RawRevisionString) {
            $RawRevisionString
        } else {
            'HEAD^..HEAD'
        }

        # Query git directly with --no-pager to prevent .NET pipe buffer deadlock
        $files = @(git -C $gitRoot --no-pager diff --name-only --diff-filter=d $rev @pathFilter 2>$null)
        if ($LASTEXITCODE -ne 0) {
            # Fallback if commit parent is not in shallow clone
            $files = @(git -C $gitRoot --no-pager diff --name-only --diff-filter=d HEAD @pathFilter 2>$null)
        }

        if ($Include) {
            $matched = @()
            foreach ($f in $files) {
                foreach ($inc in $Include) {
                    if ($f -like $inc -or (Split-Path $f -Leaf) -like $inc -or "$relPath/$f" -like $inc) {
                        $matched += $f
                        break
                    }
                }
            }
            $files = $matched
        }

        $targetPrefix = $resolvedPath.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
        foreach ($f in $files) {
            $fullPath = [System.IO.Path]::GetFullPath((Join-Path $gitRoot $f))
            if ((Test-Path -LiteralPath $fullPath) -and ($fullPath -eq $resolvedPath -or $fullPath.StartsWith($targetPrefix, [System.StringComparison]::OrdinalIgnoreCase))) {
                $fullPath
            }
        }
    }
}

$pesterConfig = New-PesterConfiguration -Hashtable @{
    Run    = @{
        Path     = "$PSScriptRoot/.."
        PassThru = $true
    }
    Output = @{
        Verbosity = 'Detailed'
    }
}
$result = Invoke-Pester -Configuration $pesterConfig
exit $result.FailedCount

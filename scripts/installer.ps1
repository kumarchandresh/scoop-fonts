if (([Environment]::OSVersion.Version -lt [version]'10.0.17763') -and (-not $global)) {
    Write-Error "`nWindows prior to Windows 10 Version 1809 does not allow installation of fonts at the user level. Please install it globally." -ErrorAction Stop
}

Add-Type -AssemblyName PresentationCore, WindowsBase

$fontDir = if ($global) { "${env:WINDIR}\Fonts" } else { "${env:LOCALAPPDATA}\Microsoft\Windows\Fonts" }
$regDrive = if ($global) { 'HKLM:' } else { 'HKCU:' }
$registry = [PSCustomObject]@{
    Path  = "$regDrive\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts";
    Name  = $null;
    Value = $null;
}

if (-not (Test-Path -LiteralPath $fontDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
}

$baseDir = (Get-Item -LiteralPath $dir).FullName.TrimEnd('\', '/')
function Get-RelativePath($file) {
    $file.FullName.Substring($baseDir.Length).TrimStart('\', '/')
}

Get-ChildItem $dir -Recurse -File | ForEach-Object { Get-RelativePath $_ } | Write-Output
$files = Get-ChildItem $dir -Recurse -File | Where-Object {
    $_.Name -match '\.(ttf|otf|ttc|otc)$' -and ((Get-RelativePath $_) -match $filter)
}
if ($files.Count -eq 0) {
    Write-Error 'Failed to find fonts to install. Please recheck the filter.' -ErrorAction Stop
}

$extra = Get-ChildItem $dir -Recurse -File | Where-Object {
    $_.Name -match '\.(ttf|otf|ttc|otc|woff2?|eot|svgz?|s?css)$' -and ((Get-RelativePath $_) -notmatch $filter)
}
foreach ($file in $extra) {
    Remove-Item -Force -LiteralPath $file.FullName -ErrorAction SilentlyContinue
}

$fonts = foreach ($file in $files) {
    $fileUri = [uri]::new($file.FullName)
    $glyphTypeface = $null
    $registry.Name = $null
    $registry.Value = $null
    try {
        $glyphTypeface = [System.Windows.Media.GlyphTypeface]::new($fileUri)
        if ($null -ne $glyphTypeface) {
            $culture = [System.Globalization.CultureInfo]::CurrentCulture
            $fontFamilyName = $null
            if (($null -ne $glyphTypeface.FamilyNames) -and ($glyphTypeface.FamilyNames.Count -ne 0)) {
                if ($glyphTypeface.FamilyNames.ContainsKey($culture.LCID)) {
                    $fontFamilyName = $glyphTypeface.FamilyNames[$culture.LCID]
                } elseif ($glyphTypeface.FamilyNames.ContainsKey(0x0409)) {
                    $fontFamilyName = $glyphTypeface.FamilyNames[0x0409] # en-US
                }
            }
            $fontFaceName = $null
            if (($null -ne $glyphTypeface.FaceNames) -and ($glyphTypeface.FaceNames.Count -ne 0)) {
                if ($glyphTypeface.FaceNames.ContainsKey($culture.LCID)) {
                    $fontFaceName = $glyphTypeface.FaceNames[$culture.LCID]
                } elseif ($glyphTypeface.FaceNames.ContainsKey(0x0409)) {
                    $fontFaceName = $glyphTypeface.FaceNames[0x0409] # en-US
                }
            }
            if (($null -ne $fontFamilyName) -and ($null -ne $fontFaceName)) {
                $fontFamilyName = $fontFamilyName.Trim()
                $fontFaceName = $fontFaceName.Trim()
                $registry.Name = "$fontFamilyName $fontFaceName (TrueType)"
            }
        }
    } catch {
        Write-Warning "Failed to retrieve font metadata from $($file.Name): $($_.Exception.Message)"
    } finally {
        # Force garbage collection to ensure any remaining handles are released
        $glyphTypeface = $null
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
    if ([string]::IsNullOrWhiteSpace($registry.Name)) {
        Write-Warning "Could not determine font family name from metadata; using filename instead."
        $registry.Name = $file.Name
    }
    $result = [PSCustomObject]@{
        File     = $file
        Registry = $registry.Name
        Success  = $false
    }
    $fontPath = "$fontDir\$($file.Name)"
    $registry.Value = if ($global) { $file.Name } else { $fontPath }
    if (Test-Path -LiteralPath $fontPath) {
        # Force garbage collection to release any .NET handles on font files
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()

        try {
            Remove-Item -LiteralPath $fontPath -Force -ErrorAction SilentlyContinue
            # Give Windows a moment to release the file handle
            Start-Sleep -Milliseconds 100
        } catch {
            Write-Error "Failed to remove existing font file $($file.Name): $($_.Exception.Message)"
            continue
        }
    }
    try {
        Copy-Item -Force -LiteralPath $file.FullName -Destination $fontDir

        $existingKey = Get-ItemProperty -Path $registry.Path -Name $registry.Name -ErrorAction SilentlyContinue
        if ($null -eq $existingKey) {
            New-ItemProperty -Force -Path $registry.Path -Name $registry.Name -Value $registry.Value -PropertyType String -ErrorAction Stop | Out-Null
        } else {
            Set-ItemProperty -Force -Path $registry.Path -Name $registry.Name -Value $registry.Value -ErrorAction Stop | Out-Null
        }
        $result.Success = $true
    } catch {
        Write-Error "Failed to install font $($file.Name): $($_.Exception.Message)"
    }
    $result
}
if ($fonts.Count -gt 0) {
    $fonts | Select-Object @{ Name = 'Font'; Expression = { $_.File.Name } }, Registry, Success | Format-Table -AutoSize
}

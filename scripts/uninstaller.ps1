Add-Type -AssemblyName PresentationCore, WindowsBase

$fontDir = if ($global) { "${env:WINDIR}\Fonts" } else { "${env:LOCALAPPDATA}\Microsoft\Windows\Fonts" }
$regDrive = if ($global) { 'HKLM:' } else { 'HKCU:' }
$registry = [PSCustomObject]@{
    Path = "$regDrive\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts";
    Name = $null;
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
    Write-Error 'Failed to find fonts to uninstall. Please recheck the filter.' -ErrorAction Stop
}

$fonts = foreach ($file in $files) {
    $fileUri = [uri]::new($file.FullName)
    $glyphTypeface = $null
    $registry.Name = $null
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
    if (Test-Path -LiteralPath $fontPath) {
        # Force garbage collection to release any .NET handles on font files
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()

        try {
            Remove-Item -LiteralPath $fontPath -Force
            # Give Windows a moment to release the file handle
            Start-Sleep -Milliseconds 100
        } catch {
            Write-Error "Failed to remove existing font file $($file.Name): $($_.Exception.Message)"
            continue
        }
    }
    try {
        Remove-ItemProperty -Path $registry.Path -Name $registry.Name -ErrorAction Stop
        $result.Success = $true
    } catch {
        Write-Error "Failed to uninstall font $($file.Name): $($_.Exception.Message)"
    }
    $result
}
if ($fonts.Count -gt 0) {
    $fonts | Select-Object @{ Name = 'Font'; Expression = { $_.File.Name } }, Registry, Success | Format-Table -AutoSize
}

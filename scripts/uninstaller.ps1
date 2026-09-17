Add-Type -AssemblyName PresentationCore, WindowsBase

$fontDir = if ($global) { "${env:WINDIR}\Fonts" } else { "${env:LOCALAPPDATA}\Microsoft\Windows\Fonts" }
$regDrive = if ($global) { 'HKLM:' } else { 'HKCU:' }
$regPath = "$regDrive\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

$baseDir = (Get-Item -LiteralPath $dir).FullName.TrimEnd('\', '/')
function Get-RelativePath($file) {
    $file.FullName.Substring($baseDir.Length).TrimStart('\', '/')
}

$allItems = @(Get-ChildItem -LiteralPath $dir -Recurse -File)
$allItems | ForEach-Object { Get-RelativePath $_ } | Write-Output

$files = @($allItems | Where-Object { $_.Name -match '\.(ttf|otf|ttc|otc)$' -and ((Get-RelativePath $_) -match $filter) })
if ($files.Count -eq 0) {
    Write-Error 'Failed to find fonts to uninstall. Please recheck the filter.' -ErrorAction Stop
}

function Get-LocalizedName($dict, [int]$lcid) {
    if ($dict -and $dict.Count -gt 0) {
        if ($dict.ContainsKey($lcid)) {
            return $dict[$lcid].Trim()
        }
        if ($dict.ContainsKey(0x0409)) {
            return $dict[0x0409].Trim()
        }
    }
    return $null
}

function Get-FontRegistryName($file) {
    $fileUri = [uri]::new($file.FullName)
    $glyphTypeface = $null
    try {
        $glyphTypeface = [System.Windows.Media.GlyphTypeface]::new($fileUri)
        if ($glyphTypeface) {
            $lcid = [System.Globalization.CultureInfo]::CurrentCulture.LCID
            $family = Get-LocalizedName $glyphTypeface.FamilyNames $lcid
            $face = Get-LocalizedName $glyphTypeface.FaceNames $lcid
            if ($family -and $face) {
                return "$family $face (TrueType)"
            }
        }
    } catch {
        Write-Warning "Failed to retrieve font metadata from $($file.Name): $($_.Exception.Message)"
    } finally {
        $glyphTypeface = $null
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
    Write-Warning "Could not determine font family name from metadata; using filename instead."
    return $file.Name
}

$fonts = foreach ($file in $files) {
    $regName = Get-FontRegistryName $file
    $result = [PSCustomObject]@{
        File     = $file
        Registry = $regName
        Success  = $false
    }
    $fontPath = "$fontDir\$($file.Name)"

    if (Test-Path -LiteralPath $fontPath) {
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        try {
            Remove-Item -LiteralPath $fontPath -Force
            Start-Sleep -Milliseconds 100
        } catch {
            Write-Error "Failed to remove existing font file $($file.Name): $($_.Exception.Message)"
            continue
        }
    }
    try {
        Remove-ItemProperty -Path $regPath -Name $regName -ErrorAction Stop
        $result.Success = $true
    } catch {
        Write-Error "Failed to uninstall font $($file.Name): $($_.Exception.Message)"
    }
    $result
}

if ($fonts.Count -gt 0) {
    $fonts | Select-Object @{ Name = 'Font'; Expression = { $_.File.Name } }, Registry, Success | Format-Table -AutoSize
}

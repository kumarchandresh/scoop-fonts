function Test-ManifestInventory {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Declarations,
        [Parameter(Mandatory)]
        [string]$BucketDir,
        [Parameter(Mandatory)]
        [string]$DeprecatedDir,
        [Parameter()]
        [switch]$Clean
    )

    Get-ChildItem $BucketDir -Filter '*.json' | ForEach-Object {
        if (-not $Declarations.Contains($_.BaseName)) {
            if ($Clean) {
                Write-Host "unmanaged manifest deprecated: $($_.BaseName)" -ForegroundColor Yellow
                Copy-Item -Path $_.FullName -Destination (Join-Path $DeprecatedDir "$($_.BaseName).json") -Force
                Remove-Item -LiteralPath $_.FullName -Force
            } else {
                Write-Host "unmanaged manifest detected: $($_.BaseName)" -ForegroundColor DarkGray
            }
        }
    }
}

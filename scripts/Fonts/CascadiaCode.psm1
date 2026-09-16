function Get-CascadiaCodeResources {
    $manifests = [ordered]@{}
    $variants = @(
        'CascadiaCode'
        'CascadiaMono'
        'CascadiaCodeNF'
        'CascadiaMonoNF'
        'CascadiaCodePL'
        'CascadiaMonoPL'
    )
    $formats = @(
        @{ Suffix = ''; Dir = 'ttf\static'; Ext = 'ttf' }
        @{ Suffix = '-OTF'; Dir = 'otf\static'; Ext = 'otf' }
    )

    foreach ($fmt in $formats) {
        foreach ($variant in $variants) {
            $name = "$variant$($fmt.Suffix)"
            $manifests[$name] = @{
                Repo    = 'microsoft/cascadia-code'
                Regex   = '/v?([\d.]+)/.*\.zip'
                Filter  = "$variant-.*.$($fmt.Ext)$"
                License = 'OFL-1.1-RFN'
                Dir     = $fmt.Dir
            }
        }
    }

    return $manifests
}

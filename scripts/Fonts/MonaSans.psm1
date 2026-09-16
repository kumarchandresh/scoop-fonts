function Get-MonaSansResources {
    $manifests = [ordered]@{}
    $styles = @(
        ''
        'Condensed'
        'Display'
        'DisplayCondensed'
        'DisplayExpanded'
        'DisplaySemiCondensed'
        'DisplaySemiExpanded'
        'Expanded'
        'Mono'
        'MonoCondensed'
        'MonoExpanded'
        'MonoSemiCondensed'
        'MonoSemiExpanded'
        'SemiCondensed'
        'SemiExpanded'
    )
    $formats = @(
        @{ Suffix = ''; Dir = 'fonts\static\ttf'; Ext = 'ttf' }
        @{ Suffix = '-OTF'; Dir = 'fonts\static\otf'; Ext = 'otf' }
    )

    foreach ($fmt in $formats) {
        foreach ($style in $styles) {
            $name = "MonaSans$style$($fmt.Suffix)"
            $manifests[$name] = @{
                Repo   = 'github/mona-sans'
                Regex  = '/mona-sans-static-v?([\d.]+)\.zip'
                Dir    = $fmt.Dir
                Filter = "MonaSans$style-.*.$($fmt.Ext)$"
                Latest = $true
            }
        }
    }

    return $manifests
}

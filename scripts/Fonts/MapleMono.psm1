function Get-MapleMonoResources {
    $manifests = [ordered]@{}
    $fontFamilies = @(
        'MapleMono'
        'MapleMonoNL'
        'MapleMonoNormal'
        'MapleMonoNormalNL'
    )
    $packages = @(
        'CN-unhinted'
        'CN'
        'NF-CN-unhinted'
        'NF-CN'
        'NF-unhinted'
        'NF'
        'OTF'
        'TTF-AutoHint'
        'TTF'
        'Variable'
    )

    foreach ($fontFamily in $fontFamilies) {
        foreach ($package in $packages) {
            $fileName = "$fontFamily-$package"
            $fontName = ($fileName -replace '-TTF$', '-unhinted') -replace '-TTF-AutoHint', ''
            $manifests[$fontName] = @{
                Repo   = 'subframe7536/maple-font'
                Regex  = "/v?([\d.]+)/${fileName}\.zip"
                Filter = "\.[ot]tf$"
                Desc   = 'Maple Mono is an open source monospace font focused on smoothing your coding flow.'
            }
        }
    }

    return $manifests
}


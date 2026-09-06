function Get-MapleMonoFonts {
    $manifests = [ordered]@{}
    $fontFamilies = @('MapleMono', 'MapleMonoNL', 'MapleMonoNormal', 'MapleMonoNormalNL')
    $packages = @('CN-unhinted', 'CN', 'NF-CN-unhinted', 'NF-CN', 'NF-unhinted', 'NF', 'OTF', 'TTF-AutoHint', 'TTF', 'Variable')
    foreach ($fontFamily in $fontFamilies) {
        foreach ($package in $packages) {
            $fileName = "$fontFamily-$package"
            $fontName = ($fileName -replace '-TTF$', '-unhinted') -replace '-TTF-AutoHint', ''
            $manifests[$fontName] = @{
                Name   = $fontName
                Repo   = 'subframe7536/maple-font'
                Regex  = "/v?([\d.]+)/${fileName}\.zip"
                Filter = "\.[ot]tf$"
                Desc   = 'Maple Mono is an open source monospace font focused on smoothing your coding flow.'
            }
        }
    }

    # $manifests.GetEnumerator() | ForEach-Object {
    #     [PSCustomObject]@{
    #         Name   = $_.Key
    #         Repo   = $_.Value.Repo
    #         Regex  = $_.Value.Regex
    #         Filter = $_.Value.Filter
    #         Desc   = $_.Value.Desc
    #     }
    # }
    # exit 0

    return $manifests
}

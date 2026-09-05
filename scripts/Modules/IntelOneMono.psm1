function Get-IntelOneMonoFonts {
    $manifests = [ordered]@{
        'IntelOneMono'     = @{Repo = 'intel/intel-one-mono'; Regex = '/V?([\d.]+)+/ttf.zip'; Filter = "\.[ot]tf$"; Dir = 'ttf' }
        'IntelOneMono-OTF' = @{Repo = 'intel/intel-one-mono'; Regex = '/V?([\d.]+)+/otf.zip'; Filter = "\.[ot]tf$"; Dir = 'otf' }
    }
    return $manifests
}

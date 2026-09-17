function Get-IntelOneMonoResources {
    $manifests = [ordered]@{
        'IntelOneMono'     = @{ Repo = 'intel/intel-one-mono'; Regex = '/V?([\d.]+)+/ttf.zip'; Filter = "\.[ot]tf$"; Latest = $true; Dir = 'ttf' }
        'IntelOneMono-OTF' = @{ Repo = 'intel/intel-one-mono'; Regex = '/V?([\d.]+)+/otf.zip'; Filter = "\.[ot]tf$"; Latest = $true; Dir = 'otf' }
    }
    return $manifests
}

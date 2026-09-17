function Get-0xTypeResources {
    $manifests = [ordered]@{
        '0xProto'          = @{ Repo = '0xType/0xProto'; Regex = '/v?([\d.]+)/[^/]+\.zip'; Filter = "^[^\\]+\.ttf$"; Latest = $true; Dir = 'fonts' }
        '0xProto-OTF'      = @{ Repo = '0xType/0xProto'; Regex = '/v?([\d.]+)/[^/]+\.zip'; Filter = "^[^\\]+\.otf$"; Latest = $true; Dir = 'fonts' }
        '0xProtoNL'        = @{ Repo = '0xType/0xProto'; Regex = '/v?([\d.]+)/[^/]+\.zip'; Filter = '^[^\\]+\.ttf$'; Latest = $true; Dir = 'fonts\No-Ligatures' }
        '0xProtoNL-OTF'    = @{ Repo = '0xType/0xProto'; Regex = '/v?([\d.]+)/[^/]+\.zip'; Filter = '^[^\\]+\.otf$'; Latest = $true; Dir = 'fonts\No-Ligatures' }
        'ZxProto'          = @{ Repo = '0xType/0xProto'; Regex = '/v?([\d.]+)/[^/]+\.zip'; Filter = '^[^\\]+\.ttf$'; Latest = $true; Dir = 'fonts\ZxProto' }
        'ZxProto-OTF'      = @{ Repo = '0xType/0xProto'; Regex = '/v?([\d.]+)/[^/]+\.zip'; Filter = '^[^\\]+\.otf$'; Latest = $true; Dir = 'fonts\ZxProto' }
        'ZxGamut'          = @{ Repo = '0xType/Gamut'  ; Regex = '/v?([\d.]+)/[^/]+\.zip'; Filter = '^[^\\]+\.ttf$'; Latest = $true; Dir = 'static' }
        'ZxGamut-OTF'      = @{ Repo = '0xType/Gamut'  ; Regex = '/v?([\d.]+)/[^/]+\.zip'; Filter = '^[^\\]+\.otf$'; Latest = $true; Dir = 'static' }
        'ZxGamut-Variable' = @{ Repo = '0xType/Gamut'  ; Regex = '/v?([\d.]+)/[^/]+\.zip'; Filter = '^[^\\]+\.ttf$'; Latest = $true; Dir = 'variable' }
    }
    return $manifests
}

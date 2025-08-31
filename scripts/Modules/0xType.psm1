function Get-0xTypeFonts {
    $manifests = [ordered]@{
        '0xProto'          = @{Repo = '0xType/0xProto'; Regex = '/v?([\d.]+)/.*\.zip'; Filter = "^0xProto-\w+\.ttf$" }
        '0xProto-OTF'      = @{Repo = '0xType/0xProto'; Regex = '/v?([\d.]+)/.*\.zip'; Filter = "^0xProto-\w+\.otf$" }
        '0xProtoNL'        = @{Repo = '0xType/0xProto'; Regex = '/v?([\d.]+)/.*\.zip'; Filter = '\.ttf$'; Dir = 'No-Ligatures' }
        '0xProtoNL-OTF'    = @{Repo = '0xType/0xProto'; Regex = '/v?([\d.]+)/.*\.zip'; Filter = '\.otf$'; Dir = 'No-Ligatures' }
        'ZxProto'          = @{Repo = '0xType/0xProto'; Regex = '/v?([\d.]+)/.*\.zip'; Filter = '\.ttf' ; Dir = 'ZxProto' }
        'ZxProto-OTF'      = @{Repo = '0xType/0xProto'; Regex = '/v?([\d.]+)/.*\.zip'; Filter = '\.otf' ; Dir = 'ZxProto' }
        'ZxGamut'          = @{Repo = '0xType/Gamut'  ; Regex = '/v?([\d.]+)/.*\.zip'; Filter = 'ZxGamut-.*\.ttf$'; Dir = 'static' }
        'ZxGamut-OTF'      = @{Repo = '0xType/Gamut'  ; Regex = '/v?([\d.]+)/.*\.zip'; Filter = 'ZxGamut-.*\.otf$'; Dir = 'static' }
        'ZxGamut-Variable' = @{Repo = '0xType/Gamut'  ; Regex = '/v?([\d.]+)/.*\.zip'; Filter = '\.ttf$'; Dir = 'variable' }
    }
    return $manifests
}

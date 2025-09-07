function Get-CascadiaCodeFonts {
    $manifests = [ordered]@{
        'CascadiaCode'       = @{Repo = 'microsoft/cascadia-code'; Regex = '/v?([\d.]+)/.*\.zip'; Filter = "CascadiaCode-.*.ttf$"  ; License = 'OFL-1.1-RFN'; Dir = 'ttf\static' }
        'CascadiaMono'       = @{Repo = 'microsoft/cascadia-code'; Regex = '/v?([\d.]+)/.*\.zip'; Filter = "CascadiaMono-.*.ttf$"  ; License = 'OFL-1.1-RFN'; Dir = 'ttf\static' }
        'CascadiaCodeNF'     = @{Repo = 'microsoft/cascadia-code'; Regex = '/v?([\d.]+)/.*\.zip'; Filter = "CascadiaCodeNF-.*.ttf$"; License = 'OFL-1.1-RFN'; Dir = 'ttf\static' }
        'CascadiaMonoNF'     = @{Repo = 'microsoft/cascadia-code'; Regex = '/v?([\d.]+)/.*\.zip'; Filter = "CascadiaMonoNF-.*.ttf$"; License = 'OFL-1.1-RFN'; Dir = 'ttf\static' }
        'CascadiaCodePL'     = @{Repo = 'microsoft/cascadia-code'; Regex = '/v?([\d.]+)/.*\.zip'; Filter = "CascadiaCodePL-.*.ttf$"; License = 'OFL-1.1-RFN'; Dir = 'ttf\static' }
        'CascadiaMonoPL'     = @{Repo = 'microsoft/cascadia-code'; Regex = '/v?([\d.]+)/.*\.zip'; Filter = "CascadiaMonoPL-.*.ttf$"; License = 'OFL-1.1-RFN'; Dir = 'ttf\static' }
        'CascadiaCode-OTF'   = @{Repo = 'microsoft/cascadia-code'; Regex = '/v?([\d.]+)/.*\.zip'; Filter = "CascadiaCode-.*.otf$"  ; License = 'OFL-1.1-RFN'; Dir = 'otf\static' }
        'CascadiaMono-OTF'   = @{Repo = 'microsoft/cascadia-code'; Regex = '/v?([\d.]+)/.*\.zip'; Filter = "CascadiaMono-.*.otf$"  ; License = 'OFL-1.1-RFN'; Dir = 'otf\static' }
        'CascadiaCodeNF-OTF' = @{Repo = 'microsoft/cascadia-code'; Regex = '/v?([\d.]+)/.*\.zip'; Filter = "CascadiaCodeNF-.*.otf$"; License = 'OFL-1.1-RFN'; Dir = 'otf\static' }
        'CascadiaMonoNF-OTF' = @{Repo = 'microsoft/cascadia-code'; Regex = '/v?([\d.]+)/.*\.zip'; Filter = "CascadiaMonoNF-.*.otf$"; License = 'OFL-1.1-RFN'; Dir = 'otf\static' }
        'CascadiaCodePL-OTF' = @{Repo = 'microsoft/cascadia-code'; Regex = '/v?([\d.]+)/.*\.zip'; Filter = "CascadiaCodePL-.*.otf$"; License = 'OFL-1.1-RFN'; Dir = 'otf\static' }
        'CascadiaMonoPL-OTF' = @{Repo = 'microsoft/cascadia-code'; Regex = '/v?([\d.]+)/.*\.zip'; Filter = "CascadiaMonoPL-.*.otf$"; License = 'OFL-1.1-RFN'; Dir = 'otf\static' }
    }
    return $manifests
}

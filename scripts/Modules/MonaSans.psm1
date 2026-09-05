function Get-MonaSansFonts {
    $manifests = [ordered]@{
        'MonaSans'                         = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\ttf'; Filter = "MonaSans-.*.ttf$" }
        'MonaSansCondensed'                = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\ttf'; Filter = "MonaSansCondensed-.*.ttf$" }
        'MonaSansDisplay'                  = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\ttf'; Filter = "MonaSansDisplay-.*.ttf$" }
        'MonaSansDisplayCondensed'         = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\ttf'; Filter = "MonaSansDisplayCondensed-.*.ttf$" }
        'MonaSansDisplayExpanded'          = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\ttf'; Filter = "MonaSansDisplayExpanded-.*.ttf$" }
        'MonaSansDisplaySemiCondensed'     = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\ttf'; Filter = "MonaSansDisplaySemiCondensed-.*.ttf$" }
        'MonaSansDisplaySemiExpanded'      = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\ttf'; Filter = "MonaSansDisplaySemiExpanded-.*.ttf$" }
        'MonaSansExpanded'                 = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\ttf'; Filter = "MonaSansExpanded-.*.ttf$" }
        'MonaSansMono'                     = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\ttf'; Filter = "MonaSansMono-.*.ttf$" }
        'MonaSansMonoCondensed'            = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\ttf'; Filter = "MonaSansMonoCondensed-.*.ttf$" }
        'MonaSansMonoExpanded'             = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\ttf'; Filter = "MonaSansMonoExpanded-.*.ttf$" }
        'MonaSansMonoSemiCondensed'        = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\ttf'; Filter = "MonaSansMonoSemiCondensed-.*.ttf$" }
        'MonaSansMonoSemiExpanded'         = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\ttf'; Filter = "MonaSansMonoSemiExpanded-.*.ttf$" }
        'MonaSansSemiCondensed'            = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\ttf'; Filter = "MonaSansSemiCondensed-.*.ttf$" }
        'MonaSansSemiExpanded'             = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\ttf'; Filter = "MonaSansSemiExpanded-.*.ttf$" }

        'MonaSans-OTF'                     = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\otf'; Filter = "MonaSans-.*.otf$" }
        'MonaSansCondensed-OTF'            = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\otf'; Filter = "MonaSansCondensed-.*.otf$" }
        'MonaSansDisplay-OTF'              = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\otf'; Filter = "MonaSansDisplay-.*.otf$" }
        'MonaSansDisplayCondensed-OTF'     = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\otf'; Filter = "MonaSansDisplayCondensed-.*.otf$" }
        'MonaSansDisplayExpanded-OTF'      = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\otf'; Filter = "MonaSansDisplayExpanded-.*.otf$" }
        'MonaSansDisplaySemiCondensed-OTF' = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\otf'; Filter = "MonaSansDisplaySemiCondensed-.*.otf$" }
        'MonaSansDisplaySemiExpanded-OTF'  = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\otf'; Filter = "MonaSansDisplaySemiExpanded-.*.otf$" }
        'MonaSansExpanded-OTF'             = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\otf'; Filter = "MonaSansExpanded-.*.otf$" }
        'MonaSansMono-OTF'                 = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\otf'; Filter = "MonaSansMono-.*.otf$" }
        'MonaSansMonoCondensed-OTF'        = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\otf'; Filter = "MonaSansMonoCondensed-.*.otf$" }
        'MonaSansMonoExpanded-OTF'         = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\otf'; Filter = "MonaSansMonoExpanded-.*.otf$" }
        'MonaSansMonoSemiCondensed-OTF'    = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\otf'; Filter = "MonaSansMonoSemiCondensed-.*.otf$" }
        'MonaSansMonoSemiExpanded-OTF'     = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\otf'; Filter = "MonaSansMonoSemiExpanded-.*.otf$" }
        'MonaSansSemiCondensed-OTF'        = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\otf'; Filter = "MonaSansSemiCondensed-.*.otf$" }
        'MonaSansSemiExpanded-OTF'         = @{Repo = 'github/mona-sans'; Regex = '/mona-sans-static-v?([\d.]+)+.zip'; Dir = 'fonts\static\otf'; Filter = "MonaSansSemiExpanded-.*.otf$" }
    }
    return $manifests
}

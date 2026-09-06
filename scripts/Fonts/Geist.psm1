function Get-GeistFonts {
    $manifests = [ordered]@{
        'Geist'               = @{Repo = 'vercel/geist-font'; Regex = '/geist-font-v?([\d.]+)+.zip'; Filter = "\.[ot]tf$"; Dir = 'geist-font/Geist/ttf' }
        'GeistMono'           = @{Repo = 'vercel/geist-font'; Regex = '/geist-font-v?([\d.]+)+.zip'; Filter = "\.[ot]tf$"; Dir = 'geist-font/GeistMono/ttf' }
        'GeistPixel'          = @{Repo = 'vercel/geist-font'; Regex = '/geist-font-v?([\d.]+)+.zip'; Filter = "\.[ot]tf$"; Dir = 'geist-font/GeistPixel/ttf' }

        'Geist-OTF'           = @{Repo = 'vercel/geist-font'; Regex = '/geist-font-v?([\d.]+)+.zip'; Filter = "\.[ot]tf$"; Dir = 'geist-font/Geist/otf' }
        'GeistMono-OTF'       = @{Repo = 'vercel/geist-font'; Regex = '/geist-font-v?([\d.]+)+.zip'; Filter = "\.[ot]tf$"; Dir = 'geist-font/GeistMono/otf' }
        'GeistPixel-OTF'      = @{Repo = 'vercel/geist-font'; Regex = '/geist-font-v?([\d.]+)+.zip'; Filter = "\.[ot]tf$"; Dir = 'geist-font/GeistPixel/otf' }

        'Geist-Variable'      = @{Repo = 'vercel/geist-font'; Regex = '/geist-font-v?([\d.]+)+.zip'; Filter = "\.[ot]tf$"; Dir = 'geist-font/Geist/variable' }
        'GeistMono-Variable'  = @{Repo = 'vercel/geist-font'; Regex = '/geist-font-v?([\d.]+)+.zip'; Filter = "\.[ot]tf$"; Dir = 'geist-font/GeistMono/variable' }
        'GeistPixel-Variable' = @{Repo = 'vercel/geist-font'; Regex = '/geist-font-v?([\d.]+)+.zip'; Filter = "\.[ot]tf$"; Dir = 'geist-font/GeistPixel/variable' }
    }
    return $manifests
}

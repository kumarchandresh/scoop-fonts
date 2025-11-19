function Get-IBMPlexFonts {
    Write-Host 'Fetching release data for IBM Plex...'
    $urls = (Invoke-WebRequest 'https://api.github.com/repos/IBM/plex/releases').Content | ConvertFrom-Json | ForEach-Object { $_.assets.browser_download_url } | Where-Object { $_ -match '\.zip$' }
    if ($urls.Count -eq 0) {
        Write-Warning 'IBM Plex: Failed to fetch release data from GitHub API.'
    }
    $plexFonts = @(
        @{ fontName = 'IBMPlexMono'; fileName = 'ibm-plex-mono'; dir = 'ibm-plex-mono\fonts\complete\ttf'; filter = 'IBMPlexMono-.*\.ttf$' },
        @{ fontName = 'IBMPlexMono-OTF'; fileName = 'ibm-plex-mono'; dir = 'ibm-plex-mono\fonts\complete\otf'; filter = 'IBMPlexMono-.*\.otf$' },
        @{ fontName = 'IBMPlexMath'; fileName = 'ibm-plex-math'; dir = 'ibm-plex-math\fonts\complete\ttf'; filter = 'IBMPlexMath-.*\.ttf$' },
        @{ fontName = 'IBMPlexMath-OTF'; fileName = 'ibm-plex-math'; dir = 'ibm-plex-math\fonts\complete\otf'; filter = 'IBMPlexMath-.*\.otf$' },
        @{ fontName = 'IBMPlexSerif'; fileName = 'ibm-plex-serif'; dir = 'ibm-plex-serif\fonts\complete\ttf'; filter = 'IBMPlexSerif-.*\.ttf$' },
        @{ fontName = 'IBMPlexSerif-OTF'; fileName = 'ibm-plex-serif'; dir = 'ibm-plex-serif\fonts\complete\otf'; filter = 'IBMPlexSerif-.*\.otf$' },
        @{ fontName = 'IBMPlexSans'; fileName = 'ibm-plex-sans'; dir = 'ibm-plex-sans\fonts\complete\ttf'; filter = 'IBMPlexSans-.*\.ttf$' },
        @{ fontName = 'IBMPlexSans-OTF'; fileName = 'ibm-plex-sans'; dir = 'ibm-plex-sans\fonts\complete\otf'; filter = 'IBMPlexSans-.*\.otf$' },
        @{ fontName = 'IBMPlexSans-Variable'; fileName = 'plex-sans-variable'; dir = 'fonts\variable\ttf'; filter = 'IBM Plex Sans Var-.*\.ttf$' },
        @{ fontName = 'IBMPlexSansCondensed'; fileName = 'ibm-plex-sans-condensed'; dir = 'ibm-plex-sans-condensed\fonts\complete\ttf'; filter = 'IBMPlexSansCondensed-.*\.ttf$' },
        @{ fontName = 'IBMPlexSansCondensed-OTF'; fileName = 'ibm-plex-sans-condensed'; dir = 'ibm-plex-sans-condensed\fonts\complete\otf'; filter = 'IBMPlexSansCondensed-.*\.otf$' },
        @{ fontName = 'IBMPlexSansJP'; fileName = 'ibm-plex-sans-jp'; dir = 'ibm-plex-sans-jp\fonts\complete\ttf\hinted'; filter = 'IBMPlexSansJP-.*\.ttf$' },
        @{ fontName = 'IBMPlexSansJP-OTF'; fileName = 'ibm-plex-sans-jp'; dir = 'ibm-plex-sans-jp\fonts\complete\otf\hinted'; filter = 'IBMPlexSansJP-.*\.otf$' },
        @{ fontName = 'IBMPlexSansJP-Unhinted'; fileName = 'ibm-plex-sans-jp'; dir = 'ibm-plex-sans-jp\fonts\complete\ttf\unhinted'; filter = 'IBMPlexSansJP-.*\.ttf$' },
        @{ fontName = 'IBMPlexSansJP-Unhinted-OTF'; fileName = 'ibm-plex-sans-jp'; dir = 'ibm-plex-sans-jp\fonts\complete\otf\unhinted'; filter = 'IBMPlexSansJP-.*\.otf$' },
        @{ fontName = 'IBMPlexSansKR'; fileName = 'ibm-plex-sans-kr'; dir = 'ibm-plex-sans-kr\fonts\complete\ttf\hinted'; filter = 'IBMPlexSansKR-.*\.ttf$' },
        @{ fontName = 'IBMPlexSansKR-OTF'; fileName = 'ibm-plex-sans-kr'; dir = 'ibm-plex-sans-kr\fonts\complete\otf\hinted'; filter = 'IBMPlexSansKR-.*\.otf$' },
        @{ fontName = 'IBMPlexSansKR-Unhinted'; fileName = 'ibm-plex-sans-kr'; dir = 'ibm-plex-sans-kr\fonts\complete\ttf\unhinted'; filter = 'IBMPlexSansKR-.*\.ttf$' },
        @{ fontName = 'IBMPlexSansKR-Unhinted-OTF'; fileName = 'ibm-plex-sans-kr'; dir = 'ibm-plex-sans-kr\fonts\complete\otf\unhinted'; filter = 'IBMPlexSansKR-.*\.otf$' },
        @{ fontName = 'IBMPlexSansSC'; fileName = 'ibm-plex-sans-sc'; dir = 'ibm-plex-sans-sc\fonts\complete\ttf\hinted'; filter = 'IBMPlexSansSC-.*\.ttf$' },
        @{ fontName = 'IBMPlexSansSC-OTF'; fileName = 'ibm-plex-sans-sc'; dir = 'ibm-plex-sans-sc\fonts\complete\otf\hinted'; filter = 'IBMPlexSansSC-.*\.otf$' },
        @{ fontName = 'IBMPlexSansSC-Unhinted'; fileName = 'ibm-plex-sans-sc'; dir = 'ibm-plex-sans-sc\fonts\complete\ttf\unhinted'; filter = 'IBMPlexSansSC-.*\.ttf$' },
        @{ fontName = 'IBMPlexSansSC-Unhinted-OTF'; fileName = 'ibm-plex-sans-sc'; dir = 'ibm-plex-sans-sc\fonts\complete\otf\unhinted'; filter = 'IBMPlexSansSC-.*\.otf$' },
        @{ fontName = 'IBMPlexSansTC'; fileName = 'ibm-plex-sans-tc'; dir = 'ibm-plex-sans-tc\fonts\complete\ttf\hinted'; filter = 'IBMPlexSansTC-.*\.ttf$' },
        @{ fontName = 'IBMPlexSansTC-OTF'; fileName = 'ibm-plex-sans-tc'; dir = 'ibm-plex-sans-tc\fonts\complete\otf\hinted'; filter = 'IBMPlexSansTC-.*\.otf$' },
        @{ fontName = 'IBMPlexSansTC-Unhinted'; fileName = 'ibm-plex-sans-tc'; dir = 'ibm-plex-sans-tc\fonts\complete\ttf\unhinted'; filter = 'IBMPlexSansTC-.*\.ttf$' },
        @{ fontName = 'IBMPlexSansTC-Unhinted-OTF'; fileName = 'ibm-plex-sans-tc'; dir = 'ibm-plex-sans-tc\fonts\complete\otf\unhinted'; filter = 'IBMPlexSansTC-.*\.otf$' },
        @{ fontName = 'IBMPlexSansArabic'; fileName = 'ibm-plex-sans-arabic'; dir = 'ibm-plex-sans-arabic\fonts\complete\ttf'; filter = 'IBMPlexSansArabic-.*\.ttf$' },
        @{ fontName = 'IBMPlexSansArabic-OTF'; fileName = 'ibm-plex-sans-arabic'; dir = 'ibm-plex-sans-arabic\fonts\complete\otf'; filter = 'IBMPlexSansArabic-.*\.otf$' },
        @{ fontName = 'IBMPlexSansDevanagari'; fileName = 'ibm-plex-sans-devanagari'; dir = 'ibm-plex-sans-devanagari\fonts\complete\ttf'; filter = 'IBMPlexSansDevanagari-.*\.ttf$' },
        @{ fontName = 'IBMPlexSansDevanagari-OTF'; fileName = 'ibm-plex-sans-devanagari'; dir = 'ibm-plex-sans-devanagari\fonts\complete\otf'; filter = 'IBMPlexSansDevanagari-.*\.otf$' },
        @{ fontName = 'IBMPlexSansHebrew'; fileName = 'ibm-plex-sans-hebrew'; dir = 'ibm-plex-sans-hebrew\fonts\complete\ttf'; filter = 'IBMPlexSansHebrew-.*\.ttf$' },
        @{ fontName = 'IBMPlexSansHebrew-OTF'; fileName = 'ibm-plex-sans-hebrew'; dir = 'ibm-plex-sans-hebrew\fonts\complete\otf'; filter = 'IBMPlexSansHebrew-.*\.otf$' },
        @{ fontName = 'IBMPlexSansThai'; fileName = 'ibm-plex-sans-thai'; dir = 'ibm-plex-sans-thai\fonts\complete\ttf'; filter = 'IBMPlexSansThai-.*\.ttf$' }
        @{ fontName = 'IBMPlexSansThai-OTF'; fileName = 'ibm-plex-sans-thai'; dir = 'ibm-plex-sans-thai\fonts\complete\otf'; filter = 'IBMPlexSansThai-.*\.otf$' }
        @{ fontName = 'IBMPlexSansThaiLooped'; fileName = 'ibm-plex-sans-thai-looped'; dir = 'ibm-plex-sans-thai-looped\fonts\complete\ttf'; filter = 'IBMPlexSansThaiLooped-.*\.ttf$' }
        @{ fontName = 'IBMPlexSansThaiLooped-OTF'; fileName = 'ibm-plex-sans-thai-looped'; dir = 'ibm-plex-sans-thai-looped\fonts\complete\otf'; filter = 'IBMPlexSansThaiLooped-.*\.otf$' }
    )
    $manifests = [ordered]@{}
    foreach ($font in $plexFonts) {
        $fontRegex = "%40([\d.]+)/$($font.fileName)\.zip"
        foreach ($url in ($urls | Where-Object { $_ -match $fontRegex })) {
            $manifests[$font.fontName] = @{
                Name   = $font.fontName
                Repo   = 'IBM/plex'
                Regex  = $fontRegex
                Filter = $font.filter
                Dir    = $font.dir
            }
            break; # latest at top, no need to continue
        }
    }

    # $manifests.GetEnumerator() | ForEach-Object {
    #     [PSCustomObject]@{
    #         Name   = $_.Value.Name
    #         Repo   = $_.Value.Repo
    #         Regex  = $_.Value.Regex
    #         Filter = $_.Value.Filter
    #     }
    # }
    # exit 0

    return $manifests
}


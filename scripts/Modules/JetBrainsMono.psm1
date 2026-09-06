function Get-JetBrainsMonoFonts {
    $manifests = [ordered]@{
        'JetBrainsMono'    = @{Repo = 'JetBrains/JetBrainsMono'; Regex = '/v?([\d.]+)/JetBrainsMono-[\d.]+\.zip'; Filter = 'JetBrainsMono-.*\.ttf$'; Dir = 'fonts/ttf' }
        'JetBrainsMono-NL' = @{Repo = 'JetBrains/JetBrainsMono'; Regex = '/v?([\d.]+)/JetBrainsMono-[\d.]+\.zip'; Filter = 'JetBrainsMonoNL-.*\.ttf$'; Dir = 'fonts/ttf' }
    }
    return $manifests
}

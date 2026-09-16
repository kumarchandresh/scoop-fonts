function Get-JetBrainsMonoResources {
    $manifests = [ordered]@{
        'JetBrainsMono'    = @{ Repo = 'JetBrains/JetBrainsMono'; Regex = '/v?([\d.]+)/JetBrainsMono-[\d.]+\.zip'; Filter = 'JetBrainsMono-.*\.ttf$'; Latest = $true; Dir = 'fonts/ttf' }
        'JetBrainsMono-NL' = @{ Repo = 'JetBrains/JetBrainsMono'; Regex = '/v?([\d.]+)/JetBrainsMono-[\d.]+\.zip'; Filter = 'JetBrainsMonoNL-.*\.ttf$'; Latest = $true; Dir = 'fonts/ttf' }
    }
    return $manifests
}

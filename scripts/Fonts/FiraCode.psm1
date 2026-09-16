function Get-FiraCodeResources {
    $manifests = [ordered]@{
        'FiraCode'          = @{ Repo = 'tonsky/FiraCode'; Regex = '/Fira_Code_?v?([\d.]+)+.zip'; Filter = "\.[ot]tf$"; Latest = $true; Dir = 'ttf' }
        'FiraCode-Variable' = @{ Repo = 'tonsky/FiraCode'; Regex = '/Fira_Code_?v?([\d.]+)+.zip'; Filter = "\.[ot]tf$"; Latest = $true; Dir = 'variable_ttf' }
    }
    return $manifests
}

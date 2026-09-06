function Get-FiraCodeFonts {
    $manifests = [ordered]@{
        'FiraCode'          = @{Repo = 'tonsky/FiraCode'; Regex = '/Fira_Code_?v?([\d.]+)+.zip'; Filter = "\.[ot]tf$"; Dir = 'ttf' }
        'FiraCode-Variable' = @{Repo = 'tonsky/FiraCode'; Regex = '/Fira_Code_?v?([\d.]+)+.zip'; Filter = "\.[ot]tf$"; Dir = 'variable_ttf' }
    }
    return $manifests
}

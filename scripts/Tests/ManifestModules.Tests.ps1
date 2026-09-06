$modulesDir = Join-Path $PSScriptRoot '..\Modules' -Resolve
Import-Module (Join-Path $modulesDir 'ManifestSources.psm1') -Force
Import-Module (Join-Path $modulesDir 'ManifestRenderer.psm1') -Force
Import-Module (Join-Path $modulesDir 'ManifestInventory.psm1') -Force
Import-Module (Join-Path $modulesDir 'IBMPlex.psm1') -Force
Import-Module (Join-Path $modulesDir 'Iosevka.psm1') -Force
Import-Module (Join-Path $modulesDir 'MapleMono.psm1') -Force
Import-Module (Join-Path $modulesDir 'Monaspace.psm1') -Force

Describe 'Manifest source helpers' {
    It 'selects matching assets for latest and release-list responses' {
        $release = [pscustomobject]@{
            assets = @(
                [pscustomobject]@{ browser_download_url = 'https://example.test/other.zip' }
                [pscustomobject]@{ browser_download_url = 'https://example.test/font-1.2.zip' }
            )
        }

        Find-GitHubDownloadUrl -ReleaseInfo $release -Latest $true -Regex 'font-[\d.]+\.zip' | Should Be 'https://example.test/font-1.2.zip'
        Find-GitHubDownloadUrl -ReleaseInfo @($release) -Latest $false -Regex 'font-[\d.]+\.zip' | Should Be 'https://example.test/font-1.2.zip'
    }

    It 'uses the existing artifact hash cache without network access' {
        $cache = @{ 'https://example.test/font.zip' = 'abc123' }
        Get-ManifestArtifactHash -DownloadUrl 'https://example.test/font.zip' -Version '1.2' -Headers @{} -Cache $cache | Should Be 'abc123'
    }
}

Describe 'Manifest renderer' {
    It 'preserves the generated manifest contract' {
        $declaration = @{ Repo = 'example/repo'; Filter = 'Font-.*\.ttf$'; Regex = '/v?([\d.]+)/font-[\d.]+\.zip'; Dir = 'fonts' }
        $match = [regex]::new($declaration.Regex).Match('/v1.2/font-1.2.zip')
        $manifest = New-ScoopManifest -Declaration $declaration -Version '1.2' -Description 'Example' -License 'OFL-1.1' -Hash ('a' * 64) -DownloadUrl 'https://example.test/font-1.2.zip' -ReleaseUrl 'https://api.github.com/repos/example/repo/releases' -JsonPath '$[*].assets[*].browser_download_url' -VersionUrl 'https://example.test/font-$version.zip' -Match $match -InstallerLines @('install-line') -UninstallerLines @('uninstall-line')
        @($manifest.Keys) -join ',' | Should Be 'version,description,homepage,license,url,hash,extract_dir,installer,uninstaller,checkver,autoupdate'
        $manifest.installer.script.Count | Should Be 2
        $manifest.uninstaller.script.Count | Should Be 2
    }
}

Describe 'Manifest inventory' {
    It 'reports and cleans unmanaged manifests' {
        $root = Join-Path $env:TEMP ('manifest-test-' + [guid]::NewGuid())
        $bucket = Join-Path $root 'bucket'
        $deprecated = Join-Path $root 'deprecated'
        New-Item -ItemType Directory -Path $bucket,$deprecated | Out-Null
        Set-Content -Path (Join-Path $bucket 'Unmanaged.json') -Value '{}'
        try {
            Test-ManifestInventory -Declarations ([ordered]@{ Managed = @{} }) -BucketDir $bucket -DeprecatedDir $deprecated -Clean
            Test-Path (Join-Path $deprecated 'Unmanaged.json') | Should Be $true
        } finally {
            Remove-Item -Recurse -Force $root
        }
    }
}

Describe 'Static source declarations' {
    It 'preserves the current migrated descriptor counts' {
        (Get-IBMPlexFonts).Count | Should Be 37
        (Get-IosevkaFonts).Count | Should Be 316
        (Get-MapleMonoFonts).Count | Should Be 40
        (Get-MonaspaceFonts).Count | Should Be 24
    }
}

Describe 'Generated bucket manifests' {
    It 'contains structurally valid Scoop manifests' {
        $bucketDir = Join-Path $PSScriptRoot '..\..\bucket' -Resolve
        $files = @(Get-ChildItem $bucketDir -Filter '*.json')
        $files.Count | Should BeGreaterThan 0
        foreach ($file in $files) {
            $manifest = Get-Content $file.FullName -Raw | ConvertFrom-Json
            foreach ($property in @('version', 'homepage', 'license', 'url', 'hash', 'installer', 'uninstaller', 'checkver', 'autoupdate')) {
                (@($manifest.PSObject.Properties.Name) -contains $property) | Should Be $true
            }
            if ($null -ne $manifest.description) {
                $manifest.description | Should Not BeNullOrEmpty
            }
            $manifest.url | Should Match '^https?://'
            $manifest.hash | Should Match '^[0-9a-f]{64}$'
            $manifest.checkver.regex | Should Not BeNullOrEmpty
            $manifest.autoupdate.url | Should Not BeNullOrEmpty
            @($manifest.installer.script).Count | Should BeGreaterThan 1
            @($manifest.uninstaller.script).Count | Should BeGreaterThan 1
        }
    }
}

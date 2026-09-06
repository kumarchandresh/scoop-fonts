$modulesDir = Join-Path $PSScriptRoot '..\Modules' -Resolve
$fontsDir = Join-Path $PSScriptRoot '..\Fonts' -Resolve
Import-Module (Join-Path $modulesDir 'ManifestSources.psm1') -Force
Import-Module (Join-Path $modulesDir 'ManifestRenderer.psm1') -Force
Import-Module (Join-Path $modulesDir 'ManifestInventory.psm1') -Force
Import-Module (Join-Path $modulesDir 'ScoopArtifactCache.psm1') -Force
Import-Module (Join-Path $modulesDir 'ManifestDeclarations.psm1') -Force
Import-Module (Join-Path $fontsDir 'NerdFonts.psm1') -Force
Import-Module (Join-Path $fontsDir 'JetBrainsMono.psm1') -Force
Import-Module (Join-Path $fontsDir 'CascadiaCode.psm1') -Force

Describe 'Manifest source helpers' {
    It 'selects matching assets for latest and release-list responses' {
        $release = [PSCustomObject]@{
            assets = @(
                [PSCustomObject]@{ browser_download_url = 'https://example.test/other.zip' }
                [PSCustomObject]@{ browser_download_url = 'https://example.test/font-1.2.zip' }
            )
        }

        Find-GitHubDownloadUrl -ReleaseInfo $release -Latest $true -Regex 'font-[\d.]+\.zip' | Should -Be 'https://example.test/font-1.2.zip'
        Find-GitHubDownloadUrl -ReleaseInfo @($release) -Latest $false -Regex 'font-[\d.]+\.zip' | Should -Be 'https://example.test/font-1.2.zip'
    }

    It 'returns null when no asset matches regex' {
        $release = [PSCustomObject]@{
            assets = @(
                [PSCustomObject]@{ browser_download_url = 'https://example.test/other.zip' }
            )
        }
        Find-GitHubDownloadUrl -ReleaseInfo $release -Latest $true -Regex 'notfound-.*\.zip' | Should -BeNullOrEmpty
        Find-GitHubDownloadUrl -ReleaseInfo @($release) -Latest $false -Regex 'notfound-.*\.zip' | Should -BeNullOrEmpty
    }

    It 'uses the existing artifact hash cache without network access' {
        $cache = @{ 'https://example.test/font.zip' = 'abc123' }
        Get-ManifestArtifactHash -DownloadUrl 'https://example.test/font.zip' -Version '1.2' -Headers @{} -Cache $cache | Should -Be 'abc123'
    }

    It 'uses existing local artifact file without network requests' {
        $root = Join-Path $env:TEMP ('source-helper-test-' + [guid]::NewGuid())
        try {
            $localPath = Get-ManifestArtifactPath -DownloadUrl 'https://unreachable.invalid/font.zip' -Version '1.0' -CacheDirectory $root
            New-Item -ItemType Directory -Force -Path (Split-Path $localPath) | Out-Null
            Set-Content -Path $localPath -Value 'font-content'
            $expectedHash = (Get-FileHash $localPath -Algorithm SHA256).Hash.ToLower()
            $hash = Get-ManifestArtifactHash -DownloadUrl 'https://unreachable.invalid/font.zip' -Version '1.0' -Headers @{} -Cache @{} -CacheDirectory $root
            $hash | Should -Be $expectedHash
        } finally {
            Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
        }
    }

    It 'throws when multiple assets match regex' {
        $release = [PSCustomObject]@{
            assets = @(
                [PSCustomObject]@{ browser_download_url = 'https://example.test/font-1.2.zip' }
                [PSCustomObject]@{ browser_download_url = 'https://example.test/font-1.2-extra.zip' }
            )
        }
        { Find-GitHubDownloadUrl -ReleaseInfo $release -Latest $true -Regex 'font-1\.2.*\.zip' } | Should -Throw '*Ambiguous asset match*'
        { Find-GitHubDownloadUrl -ReleaseInfo @($release) -Latest $false -Regex 'font-1\.2.*\.zip' } | Should -Throw '*Ambiguous asset match*'
    }
}

Describe 'Manifest renderer' {
    It 'preserves the generated manifest contract' {
        $declaration = @{ Repo = 'example/repo'; Filter = 'Font-.*\.ttf$'; Regex = '/v?([\d.]+)/font-[\d.]+\.zip'; Dir = 'fonts' }
        $match = [regex]::new($declaration.Regex).Match('/v1.2/font-1.2.zip')
        $manifest = New-ScoopManifest -Declaration $declaration -Version '1.2' -Description 'Example' -License 'OFL-1.1' -Hash ('a' * 64) -DownloadUrl 'https://example.test/font-1.2.zip' -ReleaseUrl 'https://api.github.com/repos/example/repo/releases' -JsonPath '$[*].assets[*].browser_download_url' -VersionUrl 'https://example.test/font-$version.zip' -Match $match -InstallerLines @('install-line') -UninstallerLines @('uninstall-line')
        @($manifest.Keys) -join ',' | Should -Be 'version,description,homepage,license,url,hash,extract_dir,installer,uninstaller,checkver,autoupdate'
        $manifest.installer.script.Count | Should -Be 2
        $manifest.uninstaller.script.Count | Should -Be 2
    }

    It 'generates composite checkver replace pattern for multiple capture groups without explicit Version' {
        $declaration = @{ Repo = 'example/repo'; Filter = '\.ttf$'; Regex = '/v?([\d.]+)-build(\d+)/font\.zip'; Dir = 'fonts' }
        $match = [regex]::new($declaration.Regex).Match('/v1.2-build34/font.zip')
        $manifest = New-ScoopManifest -Declaration $declaration -Version '1.2.34' -Description 'Example' -License 'MIT' -Hash ('a' * 64) -DownloadUrl 'https://example.test/font.zip' -ReleaseUrl 'https://api.github.com' -JsonPath '$.url' -VersionUrl 'https://example.test/font.zip' -Match $match -InstallerLines @('i') -UninstallerLines @('u')
        $manifest.checkver.replace | Should -Be '${1}.${2}'
    }

    It 'uses explicit declaration Version template when multiple capture groups are present' {
        $declaration = @{ Repo = 'example/repo'; Filter = '\.ttf$'; Regex = '/v?([\d.]+)-build(\d+)/font\.zip'; Version = '${1}_b${2}'; Dir = 'fonts' }
        $match = [regex]::new($declaration.Regex).Match('/v1.2-build34/font.zip')
        $manifest = New-ScoopManifest -Declaration $declaration -Version '1.2_b34' -Description 'Example' -License 'MIT' -Hash ('a' * 64) -DownloadUrl 'https://example.test/font.zip' -ReleaseUrl 'https://api.github.com' -JsonPath '$.url' -VersionUrl 'https://example.test/font.zip' -Match $match -InstallerLines @('i') -UninstallerLines @('u')
        $manifest.checkver.replace | Should -Be '${1}_b${2}'
    }
}

Describe 'Manifest inventory' {
    It 'reports and cleans unmanaged manifests' {
        $root = Join-Path $env:TEMP ('manifest-test-' + [guid]::NewGuid())
        $bucket = Join-Path $root 'bucket'
        $deprecated = Join-Path $root 'deprecated'
        New-Item -ItemType Directory -Path $bucket, $deprecated | Out-Null
        Set-Content -Path (Join-Path $bucket 'Unmanaged.json') -Value '{}'
        try {
            Test-ManifestInventory -Declarations ([ordered]@{ Managed = @{} }) -BucketDir $bucket -DeprecatedDir $deprecated -Clean
            Test-Path (Join-Path $deprecated 'Unmanaged.json') | Should -Be $true
        } finally {
            Remove-Item -Recurse -Force $root
        }
    }
}

Describe 'Scoop artifact cache' {
    It 'materializes a verified artifact using Scoop cache naming' {
        $root = Join-Path $env:TEMP ('scoop-cache-test-' + [guid]::NewGuid())
        $url = 'https://github.com/example/fonts/releases/download/v1.2/font-1.2.zip'
        try {
            $artifact = Get-ManifestArtifactPath -DownloadUrl $url -Version '1.2' -CacheDirectory $root
            New-Item -ItemType Directory -Force -Path (Split-Path $artifact) | Out-Null
            Set-Content -Path $artifact -Value 'artifact'
            $hash = (Get-FileHash $artifact -Algorithm SHA256).Hash.ToLower()
            $scoopPath = Initialize-ScoopArtifactCache -App 'ExampleFont' -Version '1.2' -DownloadUrl $url -ExpectedHash $hash -ArtifactCacheDirectory $root -ScoopCacheDirectory (Join-Path $root 'scoop')
            Test-Path $scoopPath | Should -Be $true
            (Get-FileHash $scoopPath -Algorithm SHA256).Hash.ToLower() | Should -Be $hash
        } finally {
            Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
        }
    }

    It 'shares one canonical artifact path for multiple manifests and materializes distinct Scoop cache paths' {
        $root = Join-Path $env:TEMP ('scoop-cache-share-' + [guid]::NewGuid())
        $url = 'https://github.com/microsoft/cascadia-code/releases/download/v2407.24/CascadiaCode-2407.24.zip'
        $v = '2407.24'
        try {
            $path1 = Get-ManifestArtifactPath -DownloadUrl $url -Version $v -CacheDirectory $root
            $path2 = Get-ManifestArtifactPath -DownloadUrl $url -Version $v -CacheDirectory $root
            $path1 | Should -Be $path2

            $scoopPath1 = Get-ScoopArtifactCachePath -App 'CascadiaCode' -Version $v -DownloadUrl $url -CacheDirectory "$root\scoop"
            $scoopPath2 = Get-ScoopArtifactCachePath -App 'CascadiaCodeNF' -Version $v -DownloadUrl $url -CacheDirectory "$root\scoop"
            $scoopPath1 | Should -Not -Be $scoopPath2
            $scoopPath1 | Should -Match 'CascadiaCode#2407\.24#'
            $scoopPath2 | Should -Match 'CascadiaCodeNF#2407\.24#'

            New-Item -ItemType Directory -Force -Path (Split-Path $path1) | Out-Null
            Set-Content -Path $path1 -Value 'cascadia-bytes'
            $hash = (Get-FileHash $path1 -Algorithm SHA256).Hash.ToLower()

            $seeded1 = Initialize-ScoopArtifactCache -App 'CascadiaCode' -Version $v -DownloadUrl $url -ExpectedHash $hash -ArtifactCacheDirectory $root -ScoopCacheDirectory "$root\scoop"
            $seeded2 = Initialize-ScoopArtifactCache -App 'CascadiaCodeNF' -Version $v -DownloadUrl $url -ExpectedHash $hash -ArtifactCacheDirectory $root -ScoopCacheDirectory "$root\scoop"

            Test-Path $seeded1 | Should -Be $true
            Test-Path $seeded2 | Should -Be $true
            $seeded1 | Should -Not -Be $seeded2
            (Get-FileHash $seeded1 -Algorithm SHA256).Hash.ToLower() | Should -Be $hash
            (Get-FileHash $seeded2 -Algorithm SHA256).Hash.ToLower() | Should -Be $hash
        } finally {
            Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
        }
    }

    It 'Test-ArtifactHash returns false for missing or hash-mismatched files' {
        $root = Join-Path $env:TEMP ('hash-test-' + [guid]::NewGuid())
        try {
            New-Item -ItemType Directory -Force -Path $root | Out-Null
            Test-ArtifactHash -Path (Join-Path $root 'missing.zip') -ExpectedHash ('a' * 64) | Should -Be $false

            $corruptFile = Join-Path $root 'corrupt.zip'
            Set-Content -Path $corruptFile -Value 'corrupt'
            Test-ArtifactHash -Path $corruptFile -ExpectedHash ('a' * 64) | Should -Be $false
        } finally {
            Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
        }
    }

    It 'Initialize-ScoopArtifactCache throws on missing artifact or hash mismatch' {
        $root = Join-Path $env:TEMP ('seed-fail-test-' + [guid]::NewGuid())
        try {
            { Initialize-ScoopArtifactCache -App 'TestApp' -Version '1.0' -DownloadUrl 'https://example.test/missing.zip' -ExpectedHash ('a' * 64) -ArtifactCacheDirectory $root -ScoopCacheDirectory "$root\scoop" } | Should -Throw '*Verified artifact is missing or has an unexpected hash*'

            $badPath = Get-ManifestArtifactPath -DownloadUrl 'https://example.test/bad.zip' -Version '1.0' -CacheDirectory $root
            New-Item -ItemType Directory -Force -Path (Split-Path $badPath) | Out-Null
            Set-Content -Path $badPath -Value 'bad-data'
            { Initialize-ScoopArtifactCache -App 'TestApp' -Version '1.0' -DownloadUrl 'https://example.test/bad.zip' -ExpectedHash ('a' * 64) -ArtifactCacheDirectory $root -ScoopCacheDirectory "$root\scoop" } | Should -Throw '*Verified artifact is missing or has an unexpected hash*'
        } finally {
            Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Nerd Fonts catalog mapping' {
    It 'maps special-case and standard font families correctly from catalog entries' {
        $fixture = @(
            @{ folderName = 'Arimo'; patchedName = 'Arimo'; licenseId = 'Apache-2.0'; description = 'Arimo NF' },
            @{ folderName = 'NerdFontsSymbolsOnly'; patchedName = 'NerdFontsSymbolsOnly'; licenseId = 'MIT'; description = 'Symbols NF' },
            @{ folderName = 'Hack'; patchedName = 'Hack'; licenseId = 'MIT'; description = 'Hack NF' }
        )

        $fonts = Get-NerdFonts -Catalog $fixture

        # Arimo has only '' and 'Propo' (no Mono)
        ($fonts.Contains('ArimoNerdFont')) | Should -Be $true
        ($fonts.Contains('ArimoNerdFontPropo')) | Should -Be $true
        ($fonts.Contains('ArimoNerdFontMono')) | Should -Be $false

        # SymbolsOnly has only '' and 'Mono' (no Propo)
        ($fonts.Contains('NerdFontsSymbolsOnlyNerdFont')) | Should -Be $true
        ($fonts.Contains('NerdFontsSymbolsOnlyNerdFontMono')) | Should -Be $true
        ($fonts.Contains('NerdFontsSymbolsOnlyNerdFontPropo')) | Should -Be $false

        # Standard font Hack has '', 'Mono', and 'Propo'
        ($fonts.Contains('HackNerdFont')) | Should -Be $true
        ($fonts.Contains('HackNerdFontMono')) | Should -Be $true
        ($fonts.Contains('HackNerdFontPropo')) | Should -Be $true
    }
}

Get-ChildItem -LiteralPath $fontsDir -Filter '*.psm1' | ForEach-Object { Import-Module $_.FullName -Force }

Describe 'Static source declarations' {
    It 'preserves the current migrated descriptor counts' {
        (Get-IBMPlexFonts).Count | Should -Be 37
        (Get-IosevkaFonts).Count | Should -Be 316
        (Get-MapleMonoFonts).Count | Should -Be 40
        (Get-MonaspaceFonts).Count | Should -Be 24
    }

    It 'ensures all 484 static declarations map to an existing bucket manifest' {
        $fontsDir = Join-Path $PSScriptRoot '..\Fonts' -Resolve
        $fontModules = @(Get-ChildItem -LiteralPath $fontsDir -Filter '*.psm1' | Where-Object { $_.BaseName -ne 'NerdFonts' } | Sort-Object Name)
        $bucketDir = Join-Path $PSScriptRoot '..\..\bucket' -Resolve
        $total = 0
        foreach ($m in $fontModules) {
            $fn = "Get-$($m.BaseName)Fonts"
            if (-not (Get-Command -Name $fn -ErrorAction SilentlyContinue)) {
                $fn = "Get-$($m.BaseName)"
            }
            $decls = & $fn
            $total += $decls.Count
            foreach ($k in $decls.Keys) {
                Test-Path (Join-Path $bucketDir "$k.json") | Should -Be $true
            }
        }
        $total | Should -Be 484
    }
}

Describe 'Golden manifest equivalence' {
    It 'reconstructs JetBrainsMono manifest matching golden bucket file semantically' {
        $decl = (Get-JetBrainsMonoFonts)['JetBrainsMono']
        $version = '2.304'
        $description = 'JetBrains Mono – the free and open-source typeface for developers'
        $license = 'OFL-1.1'
        $hash = '6f6376c6ed2960ea8a963cd7387ec9d76e3f629125bc33d1fdcd7eb7012f7bbf'
        $downloadUrl = 'https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip'
        $releaseUrl = 'https://api.github.com/repos/JetBrains/JetBrainsMono/releases'
        $jsonPath = '$[*].assets[*].browser_download_url'
        $versionUrl = 'https://github.com/JetBrains/JetBrainsMono/releases/download/v$version/JetBrainsMono-$version.zip'
        $match = [regex]::new($decl.Regex).Match($downloadUrl)

        $installerContent = @(Get-Content (Join-Path $PSScriptRoot '..\installer.ps1') | Where-Object { $_ -and $_ -notmatch '^\s*#' })
        $uninstallerContent = @(Get-Content (Join-Path $PSScriptRoot '..\uninstaller.ps1') | Where-Object { $_ -and $_ -notmatch '^\s*#' })

        $rendered = New-ScoopManifest -Declaration $decl -Version $version -Description $description -License $license -Hash $hash -DownloadUrl $downloadUrl -ReleaseUrl $releaseUrl -JsonPath $jsonPath -VersionUrl $versionUrl -Match $match -InstallerLines $installerContent -UninstallerLines $uninstallerContent

        $golden = Get-Content (Join-Path $PSScriptRoot '..\..\bucket\JetBrainsMono.json') -Raw | ConvertFrom-Json

        $rendered.version | Should -Be $golden.version
        $rendered.description | Should -Be $golden.description
        $rendered.homepage | Should -Be $golden.homepage
        $rendered.license | Should -Be $golden.license
        $rendered.url | Should -Be $golden.url
        $rendered.hash | Should -Be $golden.hash
        $rendered.extract_dir | Should -Be $golden.extract_dir
        $rendered.checkver.url | Should -Be $golden.checkver.url
        $rendered.checkver.regex | Should -Be $golden.checkver.regex
        $rendered.autoupdate.url | Should -Be $golden.autoupdate.url
        $rendered.installer.script.Count | Should -Be $golden.installer.script.Count
        $rendered.uninstaller.script.Count | Should -Be $golden.uninstaller.script.Count
    }

    It 'reconstructs CascadiaCode manifest matching golden bucket file semantically' {
        $decl = (Get-CascadiaCodeFonts)['CascadiaCode']
        $version = '2407.24'
        $description = 'This is a fun, new coding font that comes bundled with Windows Terminal, and is now the default font in Visual Studio as well.'
        $license = 'OFL-1.1-RFN'
        $hash = 'e67a68ee3386db63f48b9054bd196ea752bc6a4ebb4df35adce6733da50c8474'
        $downloadUrl = 'https://github.com/microsoft/cascadia-code/releases/download/v2407.24/CascadiaCode-2407.24.zip'
        $releaseUrl = 'https://api.github.com/repos/microsoft/cascadia-code/releases'
        $jsonPath = '$[*].assets[*].browser_download_url'
        $versionUrl = 'https://github.com/microsoft/cascadia-code/releases/download/v$version/CascadiaCode-$version.zip'
        $match = [regex]::new($decl.Regex).Match($downloadUrl)

        $installerContent = @(Get-Content (Join-Path $PSScriptRoot '..\installer.ps1') | Where-Object { $_ -and $_ -notmatch '^\s*#' })
        $uninstallerContent = @(Get-Content (Join-Path $PSScriptRoot '..\uninstaller.ps1') | Where-Object { $_ -and $_ -notmatch '^\s*#' })

        $rendered = New-ScoopManifest -Declaration $decl -Version $version -Description $description -License $license -Hash $hash -DownloadUrl $downloadUrl -ReleaseUrl $releaseUrl -JsonPath $jsonPath -VersionUrl $versionUrl -Match $match -InstallerLines $installerContent -UninstallerLines $uninstallerContent

        $golden = Get-Content (Join-Path $PSScriptRoot '..\..\bucket\CascadiaCode.json') -Raw | ConvertFrom-Json

        $rendered.version | Should -Be $golden.version
        $rendered.homepage | Should -Be $golden.homepage
        $rendered.license | Should -Be $golden.license
        $rendered.url | Should -Be $golden.url
        $rendered.hash | Should -Be $golden.hash
        $rendered.extract_dir | Should -Be $golden.extract_dir
        $rendered.checkver.url | Should -Be $golden.checkver.url
        $rendered.checkver.regex | Should -Be $golden.checkver.regex
        $rendered.autoupdate.url | Should -Be $golden.autoupdate.url
        $rendered.installer.script.Count | Should -Be $golden.installer.script.Count
        $rendered.uninstaller.script.Count | Should -Be $golden.uninstaller.script.Count
    }
}

Describe 'Generated bucket manifests' {
    It 'contains structurally valid Scoop manifests' {
        $bucketDir = Join-Path $PSScriptRoot '..\..\bucket' -Resolve
        $files = @(Get-ChildItem $bucketDir -Filter '*.json')
        $files.Count | Should -BeGreaterThan 0
        foreach ($file in $files) {
            $manifest = Get-Content $file.FullName -Raw | ConvertFrom-Json
            foreach ($property in @('version', 'homepage', 'license', 'url', 'hash', 'installer', 'uninstaller', 'checkver', 'autoupdate')) {
                (@($manifest.PSObject.Properties.Name) -contains $property) | Should -Be $true
            }
            if ($null -ne $manifest.description) {
                $manifest.description | Should -Not -BeNullOrEmpty
            }
            $manifest.url | Should -Match '^https?://'
            $manifest.hash | Should -Match '^[0-9a-f]{64}$'
            $manifest.checkver.regex | Should -Not -BeNullOrEmpty
            $manifest.autoupdate.url | Should -Not -BeNullOrEmpty
            @($manifest.installer.script).Count | Should -BeGreaterThan 1
            @($manifest.uninstaller.script).Count | Should -BeGreaterThan 1
        }
    }
}

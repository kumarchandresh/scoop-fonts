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
    It 'resolves version info for single capture group' {
        $info = Get-ManifestVersionInfo -Regex '/v?([\d.]+)/font-[\d.]+\.zip' -DownloadUrl 'https://example.test/v1.2.3/font-1.2.3.zip'
        $info.Version | Should -Be '1.2.3'
        $info.VersionUrl | Should -Be 'https://example.test/v$version/font-$version.zip'
        $info.CheckverReplace | Should -BeNullOrEmpty
    }

    It 'generates composite version and replace pattern for multiple capture groups without explicit Version' {
        $info = Get-ManifestVersionInfo -Regex '/v?([\d.]+)-build(\d+)/font\.zip' -DownloadUrl 'https://example.test/v1.2-build34/font.zip'
        $info.Version | Should -Be '1.2.34'
        $info.VersionUrl | Should -Be 'https://example.test/v$match1-build$match2/font.zip'
        $info.CheckverReplace | Should -Be '${1}.${2}'
    }

    It 'uses explicit declaration Version template when multiple capture groups are present' {
        $info = Get-ManifestVersionInfo -Regex '/v?([\d.]+)-build(\d+)/font\.zip' -DownloadUrl 'https://example.test/v1.2-build34/font.zip' -VersionTemplate '${1}_b${2}'
        $info.Version | Should -Be '1.2_b34'
        $info.VersionUrl | Should -Be 'https://example.test/v$match1-build$match2/font.zip'
        $info.CheckverReplace | Should -Be '${1}_b${2}'
    }

    It 'returns null when download url does not match regex' {
        $info = Get-ManifestVersionInfo -Regex '/v?([\d.]+)/font\.zip' -DownloadUrl 'https://example.test/other-file.zip'
        $info | Should -BeNullOrEmpty
    }

    It 'preserves the generated manifest contract' {
        $declaration = @{ Repo = 'example/repo'; Filter = 'Font-.*\.ttf$'; Regex = '/v?([\d.]+)/font-[\d.]+\.zip'; Dir = 'fonts' }
        $versionInfo = [PSCustomObject]@{
            Version         = '1.2'
            VersionUrl      = 'https://example.test/font-$version.zip'
            CheckverReplace = $null
        }
        $release = @{
            Url      = 'https://api.github.com/repos/example/repo/releases'
            JsonPath = '$[*].assets[*].browser_download_url'
        }
        $manifestParams = @{
            Declaration      = $declaration
            VersionInfo      = $versionInfo
            Release          = $release
            Description      = 'Example'
            License          = 'OFL-1.1'
            Hash             = ('a' * 64)
            DownloadUrl      = 'https://example.test/font-1.2.zip'
            InstallerLines   = @('install-line')
            UninstallerLines = @('uninstall-line')
        }
        $manifest = New-ScoopManifest @manifestParams
        @($manifest.Keys) -join ',' | Should -Be 'version,description,homepage,license,url,hash,extract_dir,installer,uninstaller,checkver,autoupdate'
        $manifest.installer.script.Count | Should -Be 2
        $manifest.uninstaller.script.Count | Should -Be 2
        $manifest.checkver.Contains('replace') | Should -Be $false
    }

    It 'includes checkver replace when CheckverReplace is present' {
        $declaration = @{ Repo = 'example/repo'; Filter = 'Font-.*\.ttf$'; Regex = '/v?([\d.]+)-build(\d+)/font\.zip' }
        $versionInfo = [PSCustomObject]@{
            Version         = '1.2.34'
            VersionUrl      = 'https://example.test/font-$match1-build$match2.zip'
            CheckverReplace = '${1}.${2}'
        }
        $release = @{
            Url      = 'https://api.github.com/repos/example/repo/releases'
            JsonPath = '$.url'
        }
        $manifestParams = @{
            Declaration      = $declaration
            VersionInfo      = $versionInfo
            Release          = $release
            Description      = 'Example'
            License          = 'MIT'
            Hash             = ('a' * 64)
            DownloadUrl      = 'https://example.test/font.zip'
            InstallerLines   = @('i')
            UninstallerLines = @('u')
        }
        $manifest = New-ScoopManifest @manifestParams
        $manifest.checkver.replace | Should -Be '${1}.${2}'
        $manifest.Contains('extract_dir') | Should -Be $false
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
            Test-Path (Join-Path $bucket 'Unmanaged.json') | Should -Be $false
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

        $fonts = Get-NerdFontsResources -Catalog $fixture

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

    It 'uses cached catalog from disk when available and fresh' {
        $tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempDir | Out-Null
        try {
            $cachedPayload = @{
                fonts = @(
                    @{ folderName = 'TestFont'; patchedName = 'TestFont'; licenseId = 'OFL-1.1'; description = 'Test Font' }
                )
            }
            $cacheFile = Join-Path $tempDir 'nerdfonts-catalog.json'
            $cachedPayload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $cacheFile

            $catalog = Get-NerdFontsCatalog -CacheDirectory $tempDir
            $catalog.Count | Should -Be 1
            $catalog[0].folderName | Should -Be 'TestFont'
        } finally {
            Remove-Item -Recurse -Force -LiteralPath $tempDir -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Manifest declaration discovery' {
    It 'filters declarations by module name and annotates module' {
        $decls = Get-AllFontDeclarations -ModuleFilter 'CascadiaCode'
        $decls.Count | Should -Be 12
        ($decls.Contains('CascadiaCode')) | Should -Be $true
        ($decls.Contains('0xProto')) | Should -Be $false
        $decls['CascadiaCode'].Module | Should -Be 'CascadiaCode'
    }
}

Get-ChildItem -LiteralPath $fontsDir -Filter '*.psm1' | ForEach-Object { Import-Module $_.FullName -Force }

Describe 'Static source declarations' {
    It 'preserves the current migrated descriptor counts' {
        (Get-IBMPlexResources).Count | Should -Be 37
        (Get-IosevkaResources).Count | Should -Be 316
        (Get-MapleMonoResources).Count | Should -Be 40
        (Get-MonaspaceResources).Count | Should -Be 24
    }

    It 'ensures all 484 static declarations map to an existing bucket manifest' {
        $fontsDir = Join-Path $PSScriptRoot '..\Fonts' -Resolve
        $fontModules = @(Get-ChildItem -LiteralPath $fontsDir -Filter '*.psm1' | Where-Object { $_.BaseName -ne 'NerdFonts' } | Sort-Object Name)
        $bucketDir = Join-Path $PSScriptRoot '..\..\bucket' -Resolve
        $total = 0
        foreach ($m in $fontModules) {
            $fn = "Get-$($m.BaseName)Resources"
            $decls = & $fn
            $total += $decls.Count
            foreach ($k in $decls.Keys) {
                Test-Path (Join-Path $bucketDir "$k.json") | Should -Be $true
            }
        }
        $total | Should -Be 484
    }
}


Describe 'Installer template script contract' {
    It 'throws terminating error when filter matches zero files in target directory' {
        $emptyTempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $emptyTempDir | Out-Null

        try {
            $installerScript = Get-Content (Join-Path $PSScriptRoot '..\installer.ps1') -Raw
            $action = {
                $dir = $emptyTempDir
                $filter = '^NonExistentFont.*\.ttf$'
                $global = $false
                . ([ScriptBlock]::Create($installerScript))
            }

            $action | Should -Throw '*Failed to find fonts to install. Please recheck the filter.*'
        } finally {
            Remove-Item -Recurse -Force -LiteralPath $emptyTempDir -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Generated bucket manifests' {
    It 'contains structurally valid Scoop manifests' {
        $bucketDir = Join-Path $PSScriptRoot '..\..\bucket' -Resolve
        $files = @(Get-ChildItem $bucketDir -Filter '*.json')
        $files.Count | Should -BeGreaterThan 0

        $requiredProperties = @('version', 'homepage', 'license', 'url', 'hash', 'installer', 'uninstaller', 'checkver', 'autoupdate')
        $failures = [System.Collections.Generic.List[string]]::new()

        foreach ($file in $files) {
            $manifest = [System.IO.File]::ReadAllText($file.FullName) | ConvertFrom-Json
            foreach ($property in $requiredProperties) {
                if ($null -eq $manifest.$property) {
                    $failures.Add("$($file.Name): missing property '$property'")
                }
            }
            if ($null -ne $manifest.description -and [string]::IsNullOrEmpty($manifest.description)) {
                $failures.Add("$($file.Name): description is empty")
            }
            if ($manifest.url -notmatch '^https?://') {
                $failures.Add("$($file.Name): invalid url '$($manifest.url)'")
            }
            if ($manifest.hash -notmatch '^[0-9a-f]{64}$') {
                $failures.Add("$($file.Name): invalid hash '$($manifest.hash)'")
            }
            if ([string]::IsNullOrEmpty($manifest.checkver.regex)) {
                $failures.Add("$($file.Name): missing checkver.regex")
            }
            if ([string]::IsNullOrEmpty($manifest.autoupdate.url)) {
                $failures.Add("$($file.Name): missing autoupdate.url")
            }
            if (@($manifest.installer.script).Count -le 1) {
                $failures.Add("$($file.Name): installer script has <= 1 line")
            }
            if (@($manifest.uninstaller.script).Count -le 1) {
                $failures.Add("$($file.Name): uninstaller script has <= 1 line")
            }
        }

        ($failures -join "`n") | Should -BeNullOrEmpty
    }
}

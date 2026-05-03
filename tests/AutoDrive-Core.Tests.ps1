BeforeAll {
    . $PSScriptRoot/../src/AutoDrive-Core.ps1
}

Describe 'Get-FarmingSimulatorModsPath' {
    It 'Should return a valid path' {
        $result = Get-FarmingSimulatorModsPath
        $result | Should -Not -BeNullOrEmpty
        $result | Should -Match 'FarmingSimulator'
        $result | Should -Match 'mods'
    }

    It 'Should return string type' {
        $result = Get-FarmingSimulatorModsPath
        $result | Should -BeOfType [string]
    }
}

Describe 'Invoke-GitHubAPICall' {
    Context 'When API call succeeds' {
        BeforeAll {
            $mockResponse = @{
                tag_name      = 'v1.5.0'
                published_at  = '2024-01-15T10:30:00Z'
                prerelease    = $false
                assets        = @(
                    @{ name = 'FS25_AutoDrive-1.5.0.zip'; browser_download_url = 'https://github.com/releases/download/v1.5.0/FS25_AutoDrive-1.5.0.zip' }
                )
            }
        }

        BeforeEach {
            Mock Invoke-RestMethod {
                return $mockResponse
            }
        }

        It 'Should call Invoke-RestMethod with correct parameters' {
            $result = Invoke-GitHubAPICall -Uri 'https://api.github.com/repos/Stephan-S/FS25_AutoDrive/releases/latest'
            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Uri -eq 'https://api.github.com/repos/Stephan-S/FS25_AutoDrive/releases/latest'
            } -Exactly 1
        }

        It 'Should return the API response' {
            $result = Invoke-GitHubAPICall -Uri 'https://api.github.com/repos/Stephan-S/FS25_AutoDrive/releases/latest'
            $result.tag_name | Should -Be 'v1.5.0'
        }

        It 'Should include correct headers in request' {
            $result = Invoke-GitHubAPICall -Uri 'https://api.github.com/repos/Stephan-S/FS25_AutoDrive/releases/latest'
            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Headers['User-Agent'] -eq 'FS25-AutoDrive-Script' -and
                $Headers['Accept'] -eq 'application/vnd.github+json'
            }
        }
    }

    Context 'When API returns rate limit error' {
        BeforeEach {
            Mock Invoke-RestMethod {
                throw [System.Net.Http.HttpRequestException]::new('403 Forbidden')
            }
        }

        It 'Should throw GitHubRateLimitExceeded error' {
            { Invoke-GitHubAPICall -Uri 'https://api.github.com/test' } | Should -Throw
        }
    }

    Context 'When API call fails' {
        BeforeEach {
            Mock Invoke-RestMethod {
                throw [System.Exception]::new('Connection failed')
            }
        }

        It 'Should throw terminating error' {
            { Invoke-GitHubAPICall -Uri 'https://api.github.com/test' } | Should -Throw
        }
    }

    Context 'When Uri parameter is empty' {
        It 'Should throw validation error' {
            { Invoke-GitHubAPICall -Uri '' } | Should -Throw
        }
    }

    Context 'When Uri parameter is null' {
        It 'Should throw validation error' {
            { Invoke-GitHubAPICall -Uri $null } | Should -Throw
        }
    }
}

Describe 'Get-LatestAutodriveVersion' {
    Context 'When latest version is retrieved successfully' {
        BeforeAll {
            $mockRelease = @{
                tag_name      = '1.5.0'
                published_at  = '2024-01-15T10:30:00Z'
                prerelease    = $false
                assets        = @(
                    @{ name = 'FS25_AutoDrive-1.5.0.zip'; browser_download_url = 'https://github.com/releases/download/v1.5.0/FS25_AutoDrive-1.5.0.zip' }
                )
            }
        }

        BeforeEach {
            Mock Invoke-GitHubAPICall {
                return $mockRelease
            }
        }

        It 'Should return version information object' {
            $result = Get-LatestAutodriveVersion
            $result | Should -Not -BeNullOrEmpty
            $result.Version | Should -Be '1.5.0'
        }

        It 'Should have correct properties' {
            $result = Get-LatestAutodriveVersion
            $result.Version | Should -Not -BeNullOrEmpty
            $result.ReleaseDate | Should -Not -BeNullOrEmpty
            $result.DownloadUrl | Should -Not -BeNullOrEmpty
            $result.IsPreRelease | Should -Not -BeNullOrEmpty
        }

        It 'Should parse version correctly' {
            $result = Get-LatestAutodriveVersion
            $result.Version | Should -BeOfType [System.Version]
        }

        It 'Should set IsPreRelease property' {
            $result = Get-LatestAutodriveVersion
            $result.IsPreRelease | Should -Be $false
        }
    }

    Context 'When API call fails' {
        BeforeEach {
            Mock Invoke-GitHubAPICall {
                throw [System.Exception]::new('API Error')
            }
        }

        It 'Should return null' {
            $result = Get-LatestAutodriveVersion
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Get-LocalAutodriveVersion' {
    Context 'When mods directory does not exist' {
        BeforeEach {
            Mock Get-FarmingSimulatorModsPath {
                return '/tmp/NonExistent/Mods'
            }
            Mock Test-Path { return $false }
        }

        It 'Should return not installed object' {
            $result = Get-LocalAutodriveVersion
            $result.IsInstalled | Should -Be $false
            $result.Version | Should -BeNullOrEmpty
        }
    }

    Context 'When AutoDrive is installed at standard path' {
        BeforeAll {
            $testModPath = '/tmp/mods/FS25_AutoDrive'
            $testModDescPath = '/tmp/mods/FS25_AutoDrive/modDesc.xml'
            $mockXml = @'
<?xml version="1.0" encoding="utf-8"?>
<modDesc descVersion="72">
    <version>1.5.0</version>
    <title>
        <en>AutoDrive</en>
    </title>
</modDesc>
'@
        }

        BeforeEach {
            Mock Get-FarmingSimulatorModsPath {
                return '/tmp/mods'
            }
            Mock Test-Path {
                if ($Path -eq '/tmp/mods') {
                    return $true
                }
                if ($Path -eq $testModDescPath) {
                    return $true
                }
                return $false
            }
            Mock Get-Content {
                if ($Path -eq $testModDescPath) {
                    return $mockXml
                }
            }
        }

        It 'Should return installed status' {
            $result = Get-LocalAutodriveVersion
            $result.IsInstalled | Should -Be $true
        }

        It 'Should return version from modDesc.xml' {
            $result = Get-LocalAutodriveVersion
            $result.Version | Should -Be '1.5.0'
        }

        It 'Should return mod path' {
            $result = Get-LocalAutodriveVersion
            $result.ModPath | Should -Be $testModPath
        }

        It 'Should return modDesc path' {
            $result = Get-LocalAutodriveVersion
            $result.ModDescPath | Should -Be $testModDescPath
        }
    }

    Context 'When AutoDrive is installed at non-standard path' {
        BeforeAll {
            $modsPath = '/tmp/mods'
            $customModPath = '/tmp/mods/CustomAutodriveFolder'
            $customModDescPath = '/tmp/mods/CustomAutodriveFolder/modDesc.xml'
            $mockXml = @'
<?xml version="1.0" encoding="utf-8"?>
<modDesc descVersion="72">
    <version>1.4.5</version>
    <title>
        <en>AutoDrive Custom</en>
    </title>
</modDesc>
'@
            $mockFileInfo = New-Object PSObject -Property @{
                FullName = $customModDescPath
            }
        }

        BeforeEach {
            Mock Get-FarmingSimulatorModsPath {
                return $modsPath
            }
            Mock Test-Path {
                if ($Path -eq $modsPath) {
                    return $true
                }
                if ($Path -like '*FS25_AutoDrive*modDesc.xml') {
                    return $false
                }
                return $false
            }
            Mock Get-ChildItem {
                if ($Filter -eq 'modDesc.xml') {
                    return @($mockFileInfo)
                }
                return @()
            }
            Mock Select-Xml {
                return @{ Node = @{ InnerText = 'AutoDrive Custom' } }
            }
            Mock Get-Content {
                if ($Path -eq $customModDescPath) {
                    return $mockXml
                }
            }
            Mock Split-Path {
                return $customModPath
            }
        }

        It 'Should search for modDesc.xml recursively' {
            $result = Get-LocalAutodriveVersion
            Should -Invoke Get-ChildItem -ParameterFilter {
                $Filter -eq 'modDesc.xml' -and $Recurse -eq $true
            }
        }

        It 'Should return installed status' {
            $result = Get-LocalAutodriveVersion
            $result.IsInstalled | Should -Be $true
        }
    }

    Context 'When reading modDesc.xml fails' {
        BeforeAll {
            $testModPath = '/tmp/mods/FS25_AutoDrive'
            $testModDescPath = '/tmp/mods/FS25_AutoDrive/modDesc.xml'
        }

        BeforeEach {
            Mock Get-FarmingSimulatorModsPath {
                return '/tmp/mods'
            }
            Mock Test-Path {
                if ($Path -eq '/tmp/mods') {
                    return $true
                }
                if ($Path -eq $testModDescPath) {
                    return $true
                }
                return $false
            }
            Mock Get-Content {
                throw [System.IO.IOException]::new('File read error')
            }
        }

        It 'Should return null' {
            $result = Get-LocalAutodriveVersion
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Compare-AutodriveVersions' {
    Context 'When update is available' {
        BeforeAll {
            $mockLatest = [PSCustomObject]@{
                Version      = [System.Version]'1.5.0'
                ReleaseDate  = [datetime]'2024-01-15'
                DownloadUrl  = 'https://github.com/releases/download/v1.5.0/FS25_AutoDrive-1.5.0.zip'
                IsPreRelease = $false
            }
            $mockLocal = [PSCustomObject]@{
                IsInstalled = $true
                Version     = [System.Version]'1.4.5'
                ModPath     = '/tmp/mods/FS25_AutoDrive'
                ModDescPath = '/tmp/mods/FS25_AutoDrive/modDesc.xml'
            }
        }

        BeforeEach {
            Mock Get-LatestAutodriveVersion {
                return $mockLatest
            }
            Mock Get-LocalAutodriveVersion {
                return $mockLocal
            }
            Mock Write-Host
        }

        It 'Should indicate update is available' {
            $result = Compare-AutodriveVersions
            $result.UpdateAvailable | Should -Be $true
        }

        It 'Should return both versions' {
            $result = Compare-AutodriveVersions
            $result.LocalVersion | Should -Be '1.4.5'
            $result.LatestVersion | Should -Be '1.5.0'
        }

        It 'Should set IsInstalled to true' {
            $result = Compare-AutodriveVersions
            $result.IsInstalled | Should -Be $true
        }
    }

    Context 'When already up to date' {
        BeforeAll {
            $mockLatest = [PSCustomObject]@{
                Version      = [System.Version]'1.5.0'
                ReleaseDate  = [datetime]'2024-01-15'
                DownloadUrl  = 'https://github.com/releases/download/v1.5.0/FS25_AutoDrive-1.5.0.zip'
                IsPreRelease = $false
            }
            $mockLocal = [PSCustomObject]@{
                IsInstalled = $true
                Version     = [System.Version]'1.5.0'
                ModPath     = '/tmp/mods/FS25_AutoDrive'
                ModDescPath = '/tmp/mods/FS25_AutoDrive/modDesc.xml'
            }
        }

        BeforeEach {
            Mock Get-LatestAutodriveVersion {
                return $mockLatest
            }
            Mock Get-LocalAutodriveVersion {
                return $mockLocal
            }
            Mock Write-Host
        }

        It 'Should indicate no update available' {
            $result = Compare-AutodriveVersions
            $result.UpdateAvailable | Should -Be $false
        }
    }

    Context 'When mod is not installed' {
        BeforeAll {
            $mockLatest = [PSCustomObject]@{
                Version      = [System.Version]'1.5.0'
                ReleaseDate  = [datetime]'2024-01-15'
                DownloadUrl  = 'https://github.com/releases/download/v1.5.0/FS25_AutoDrive-1.5.0.zip'
                IsPreRelease = $false
            }
            $mockLocal = [PSCustomObject]@{
                IsInstalled = $false
                Version     = $null
                ModPath     = $null
                ModDescPath = $null
            }
        }

        BeforeEach {
            Mock Get-LatestAutodriveVersion {
                return $mockLatest
            }
            Mock Get-LocalAutodriveVersion {
                return $mockLocal
            }
            Mock Write-Host
        }

        It 'Should indicate not installed' {
            $result = Compare-AutodriveVersions
            $result.IsInstalled | Should -Be $false
        }

        It 'Should set LocalVersion to Not installed' {
            $result = Compare-AutodriveVersions
            $result.LocalVersion | Should -Be 'Not installed'
        }

        It 'Should indicate no update available' {
            $result = Compare-AutodriveVersions
            $result.UpdateAvailable | Should -Be $false
        }
    }

    Context 'When latest version cannot be retrieved' {
        BeforeEach {
            Mock Get-LatestAutodriveVersion {
                return $null
            }
            Mock Get-LocalAutodriveVersion {
                return [PSCustomObject]@{
                    IsInstalled = $true
                    Version     = [System.Version]'1.4.5'
                    ModPath     = '/tmp/mods/FS25_AutoDrive'
                    ModDescPath = '/tmp/mods/FS25_AutoDrive/modDesc.xml'
                }
            }
            Mock Write-Host
            Mock Write-Error
        }

        It 'Should return null' {
            $result = Compare-AutodriveVersions
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Install-AutodriveModVersion' {
    Context 'When mod is not installed' {
        BeforeAll {
            $mockComparison = [PSCustomObject]@{
                LocalVersion    = 'Not installed'
                LatestVersion   = [System.Version]'1.5.0'
                UpdateAvailable = $false
                IsInstalled     = $false
            }
        }

        BeforeEach {
            Mock Compare-AutodriveVersions {
                return $mockComparison
            }
            Mock Write-Host
        }

        It 'Should return early when not installed' {
            Install-AutodriveModVersion
            Should -Invoke Compare-AutodriveVersions -Exactly 1
        }
    }

    Context 'When already up to date' {
        BeforeAll {
            $mockComparison = [PSCustomObject]@{
                LocalVersion    = [System.Version]'1.5.0'
                LatestVersion   = [System.Version]'1.5.0'
                UpdateAvailable = $false
                IsInstalled     = $true
            }
        }

        BeforeEach {
            Mock Compare-AutodriveVersions {
                return $mockComparison
            }
            Mock Write-Host
        }

        It 'Should indicate already up to date' {
            Install-AutodriveModVersion
            Should -Invoke Compare-AutodriveVersions -Exactly 1
        }
    }

    Context 'When comparison fails' {
        BeforeEach {
            Mock Compare-AutodriveVersions {
                return $null
            }
            Mock Write-Host
        }

        It 'Should exit gracefully on comparison failure' {
            Install-AutodriveModVersion
            Should -Invoke Compare-AutodriveVersions -Exactly 1
        }
    }
}

Describe 'Show-AutoDriveMenu' {
    Context 'When user selects quit immediately' {
        BeforeEach {
            Mock Read-Host {
                return 'Q'
            }
            Mock Write-Host
        }

        It 'Should exit the menu' {
            Show-AutoDriveMenu
            Should -Invoke Read-Host -Exactly 1
        }
    }

    Context 'When user checks local version' {
        BeforeEach {
            Mock Read-Host {
                if ($callCount -eq 1) {
                    $script:callCount = 2
                    return '1'
                }
                return 'Q'
            }
            Mock Write-Host
            Mock Get-LocalAutodriveVersion {
                return [PSCustomObject]@{
                    IsInstalled = $true
                    Version     = [System.Version]'1.4.5'
                    ModPath     = 'C:\Mods\FS25_AutoDrive'
                    ModDescPath = 'C:\Mods\FS25_AutoDrive\modDesc.xml'
                }
            }
            $script:callCount = 1
        }

        It 'Should display local version' {
            Show-AutoDriveMenu
            Should -Invoke Get-LocalAutodriveVersion
        }
    }

    Context 'When user checks latest version' {
        BeforeEach {
            Mock Read-Host {
                if ($callCount -eq 1) {
                    $script:callCount = 2
                    return '2'
                }
                return 'Q'
            }
            Mock Write-Host
            Mock Get-LatestAutodriveVersion {
                return [PSCustomObject]@{
                    Version      = [System.Version]'1.5.0'
                    ReleaseDate  = [datetime]'2024-01-15'
                    DownloadUrl  = 'https://github.com/releases/download/v1.5.0/FS25_AutoDrive-1.5.0.zip'
                    IsPreRelease = $false
                }
            }
            $script:callCount = 1
        }

        It 'Should display latest version' {
            Show-AutoDriveMenu
            Should -Invoke Get-LatestAutodriveVersion
        }
    }

    Context 'When user compares versions' {
        BeforeEach {
            Mock Read-Host {
                if ($callCount -eq 1) {
                    $script:callCount = 2
                    return '3'
                }
                return 'Q'
            }
            Mock Write-Host
            Mock Compare-AutodriveVersions {
                return [PSCustomObject]@{
                    LocalVersion    = [System.Version]'1.4.5'
                    LatestVersion   = [System.Version]'1.5.0'
                    UpdateAvailable = $true
                    IsInstalled     = $true
                }
            }
            $script:callCount = 1
        }

        It 'Should call Compare-AutodriveVersions' {
            Show-AutoDriveMenu
            Should -Invoke Compare-AutodriveVersions
        }
    }

    Context 'When user enters invalid option' {
        BeforeEach {
            Mock Read-Host {
                if ($callCount -eq 1) {
                    $script:callCount = 2
                    return 'INVALID'
                }
                return 'Q'
            }
            Mock Write-Host
            $script:callCount = 1
        }

        It 'Should display invalid option message' {
            Show-AutoDriveMenu
            Should -Invoke Write-Host -ParameterFilter {
                $Object -like '*Invalid option*'
            }
        }
    }
}

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
            Mock Get-LatestAutodriveVersion {
                return [PSCustomObject]@{
                    Version      = [System.Version]'1.5.0'
                    ReleaseDate  = [datetime]'2024-01-15'
                    DownloadUrl  = 'https://example.invalid/FS25_AutoDrive-1.5.0.zip'
                    IsPreRelease = $false
                }
            }
            Mock Get-LocalAutodriveVersion {
                return [PSCustomObject]@{
                    IsInstalled = $false
                    Version     = $null
                    ModPath     = $null
                    ModDescPath = $null
                }
            }
            Mock Get-FarmingSimulatorModsPath {
                return '/tmp/mods'
            }
            Mock Invoke-WebRequest
            Mock Test-Path { return $false }
            Mock Remove-Item
            Mock Move-Item
            Mock Write-Host
        }

        It 'Should return early when not installed' {
            Install-AutodriveModVersion -Confirm:$false
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
            Mock Get-LatestAutodriveVersion {
                return [PSCustomObject]@{
                    Version      = [System.Version]'1.5.0'
                    ReleaseDate  = [datetime]'2024-01-15'
                    DownloadUrl  = 'https://example.invalid/FS25_AutoDrive-1.5.0.zip'
                    IsPreRelease = $false
                }
            }
            Mock Get-LocalAutodriveVersion {
                return [PSCustomObject]@{
                    IsInstalled = $true
                    Version     = [System.Version]'1.5.0'
                    ModPath     = '/tmp/mods/FS25_AutoDrive.zip'
                    ModDescPath = '/tmp/mods/FS25_AutoDrive.zip::modDesc.xml'
                }
            }
            Mock Get-FarmingSimulatorModsPath {
                return '/tmp/mods'
            }
            Mock Invoke-WebRequest
            Mock Test-Path { return $false }
            Mock Remove-Item
            Mock Move-Item
            Mock Write-Host
        }

        It 'Should indicate already up to date' {
            Install-AutodriveModVersion -Confirm:$false
            Should -Invoke Compare-AutodriveVersions -Exactly 1
        }
    }

    Context 'When comparison fails' {
        BeforeEach {
            Mock Compare-AutodriveVersions {
                return $null
            }
            Mock Get-LatestAutodriveVersion
            Mock Get-LocalAutodriveVersion
            Mock Get-FarmingSimulatorModsPath
            Mock Invoke-WebRequest
            Mock Test-Path
            Mock Remove-Item
            Mock Move-Item
            Mock Write-Host
        }

        It 'Should exit gracefully on comparison failure' {
            Install-AutodriveModVersion -Confirm:$false
            Should -Invoke Compare-AutodriveVersions -Exactly 1
        }
    }
}

Describe 'Remove-AutodriveMod' {
    Context 'When mod is not installed' {
        BeforeEach {
            Mock Get-LocalAutodriveVersion {
                return [PSCustomObject]@{
                    IsInstalled = $false
                    Version     = $null
                    ModPath     = $null
                    ModDescPath = $null
                }
            }
            Mock Remove-Item
            Mock Write-Host
        }

        It 'Should indicate nothing to remove' {
            Remove-AutodriveMod -Confirm:$false
            Should -Invoke Get-LocalAutodriveVersion -Exactly 1
            Should -Invoke Remove-Item -Exactly 0
        }
    }

    Context 'When mod is installed' {
        BeforeEach {
            Mock Get-LocalAutodriveVersion {
                return [PSCustomObject]@{
                    IsInstalled = $true
                    Version     = [System.Version]'1.5.0'
                    ModPath     = '/tmp/mods/FS25_AutoDrive.zip'
                    ModDescPath = '/tmp/mods/FS25_AutoDrive.zip::modDesc.xml'
                }
            }
            Mock Remove-Item
            Mock Write-Host
        }

        It 'Should remove the local mod path' {
            Remove-AutodriveMod -Confirm:$false
            Should -Invoke Remove-Item -Exactly 1 -ParameterFilter {
                $Path -eq '/tmp/mods/FS25_AutoDrive.zip' -and $Recurse -and $Force
            }
        }
    }
}

Describe 'Show-AutoDriveMenu' {
    BeforeAll {
        $script:originalLegacyMenuEnv = $env:AUTODRIVE_USE_LEGACY_MENU
        $env:AUTODRIVE_USE_LEGACY_MENU = '1'
    }

    AfterAll {
        if ($null -eq $script:originalLegacyMenuEnv) {
            Remove-Item Env:AUTODRIVE_USE_LEGACY_MENU -ErrorAction SilentlyContinue
        }
        else {
            $env:AUTODRIVE_USE_LEGACY_MENU = $script:originalLegacyMenuEnv
        }
    }

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

    Context 'When user selects install latest version' {
        BeforeEach {
            Mock Read-Host {
                if ($callCount -eq 1) {
                    $script:callCount = 2
                    return '1'
                }
                return 'Q'
            }
            Mock Write-Host
            Mock Install-AutodriveModVersion
            $script:callCount = 1
        }

        It 'Should call Install-AutodriveModVersion' {
            Show-AutoDriveMenu
            Should -Invoke Install-AutodriveModVersion -Exactly 1
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

    Context 'When user selects remove local mod' {
        BeforeEach {
            Mock Read-Host {
                if ($callCount -eq 1) {
                    $script:callCount = 2
                    return '2'
                }
                return 'Q'
            }
            Mock Write-Host
            Mock Remove-AutodriveMod
            $script:callCount = 1
        }

        It 'Should call Remove-AutodriveMod' {
            Show-AutoDriveMenu
            Should -Invoke Remove-AutodriveMod -Exactly 1
        }
    }
}

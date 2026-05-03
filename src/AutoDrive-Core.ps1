#Requires -Version 5.1

<#
.SYNOPSIS
Gets the path to the Farming Simulator 2025 mods directory for the current operating system.

.DESCRIPTION
Determines the appropriate mods directory path based on the current operating system.
Supports Windows and macOS only.
Returns the full path to the Farming Simulator 2025 mods folder where AutoDrive and other mods are installed.

.OUTPUTS
System.String
The full path to the mods directory.

.EXAMPLE
$modsPath = Get-FarmingSimulatorModsPath
Write-Host "Mods are stored at: $modsPath"

.NOTES
Supported operating systems: Windows and macOS.
Throws error on unsupported platforms.
#>
function Get-FarmingSimulatorModsPath {
    [CmdletBinding()]
    param()

    process {
        if ($IsWindows -or $env:OS -eq 'Windows_NT') {
            Write-Verbose 'Detected Windows operating system'
            return Join-Path -Path $env:USERPROFILE -ChildPath 'Documents' -AdditionalChildPath 'My Games', 'FarmingSimulator2025', 'mods'
        }
        elseif ($IsMacOS) {
            Write-Verbose 'Detected macOS operating system'
            return [System.IO.Path]::Combine($HOME, 'Library', 'Application Support', 'FarmingSimulator2025', 'mods')
        }
        else {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.NotSupportedException]::new('This platform is not supported. Only Windows and macOS are supported.'),
                'UnsupportedPlatform',
                [System.Management.Automation.ErrorCategory]::NotImplemented,
                $null
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }
}

<#
.SYNOPSIS
Invokes a call to the GitHub API with proper error handling.

.DESCRIPTION
Calls the GitHub API at the specified URI with appropriate headers for authentication
and error handling. Handles rate limiting and connection errors gracefully.

.PARAMETER Uri
The GitHub API endpoint URI to call.

.OUTPUTS
System.Management.Automation.PSObject
The deserialized JSON response from the GitHub API.

.EXAMPLE
$release = Invoke-GitHubAPICall -Uri 'https://api.github.com/repos/Stephan-S/FS25_AutoDrive/releases/latest'

.NOTES
Throws terminating errors for API failures or rate limiting.
#>
function Invoke-GitHubAPICall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Uri
    )

    process {
        try {
            Write-Verbose "Calling GitHub API: $Uri"
            $headers = @{
                'User-Agent' = 'FS25-AutoDrive-Script'
                'Accept'     = 'application/vnd.github+json'
            }
            return Invoke-RestMethod -Uri $Uri -Headers $headers -ErrorAction Stop
        }
        catch [System.Net.Http.HttpRequestException] {
            if ($_.Exception.Response.StatusCode -eq 403) {
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new('GitHub API rate limit reached. Please wait a moment and try again.'),
                    'GitHubRateLimitExceeded',
                    [System.Management.Automation.ErrorCategory]::LimitsExceeded,
                    $Uri
                )
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            }
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("GitHub API error: $($_.Exception.Message)"),
                'GitHubAPIError',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $Uri
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
        catch {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Failed to reach GitHub API: $($_.Exception.Message)"),
                'GitHubAPIConnectionFailed',
                [System.Management.Automation.ErrorCategory]::ConnectionError,
                $Uri
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }
}

<#
.SYNOPSIS
Retrieves the latest AutoDrive release version information from GitHub.

.DESCRIPTION
Fetches the latest AutoDrive release details from the GitHub API, including version number,
release date, download URL, and pre-release status.

.OUTPUTS
System.Management.Automation.PSObject
An object with properties: Version, ReleaseDate, DownloadUrl, IsPreRelease.
Returns $null if the version cannot be retrieved.

.EXAMPLE
$latest = Get-LatestAutodriveVersion
Write-Host "Latest version: $($latest.Version)"

.NOTES
Returns $null on error instead of throwing to allow graceful degradation.
#>
function Get-LatestAutodriveVersion {
    [CmdletBinding()]
    param()

    process {
        try {
            Write-Verbose 'Fetching latest AutoDrive version from GitHub'
            $release = Invoke-GitHubAPICall -Uri 'https://api.github.com/repos/Stephan-S/FS25_AutoDrive/releases/latest'
            return [PSCustomObject]@{
                Version      = [System.Version]$release.tag_name
                ReleaseDate  = [datetime]$release.published_at
                DownloadUrl  = ($release.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1).browser_download_url
                IsPreRelease = $release.prerelease
            }
        }
        catch {
            Write-Error -ErrorRecord $_
            return $null
        }
    }
}

<#
.SYNOPSIS
Retrieves the locally installed AutoDrive mod version information.

.DESCRIPTION
Searches the Farming Simulator mods directory for the AutoDrive mod and extracts version
information from the modDesc.xml file. Returns installation status and version details.

.OUTPUTS
System.Management.Automation.PSObject
An object with properties: IsInstalled, Version, ModPath, ModDescPath.
Returns $null if the local version cannot be determined.

.EXAMPLE
$local = Get-LocalAutodriveVersion
if ($local.IsInstalled) {
    Write-Host "Installed version: $($local.Version)"
}

.NOTES
Returns $null on error instead of throwing to allow graceful degradation.
#>
function Get-LocalAutodriveVersion {
    [CmdletBinding()]
    param()

    process {
        try {
            Write-Verbose 'Checking for locally installed AutoDrive mod'
            $modsPath = Get-FarmingSimulatorModsPath
            if (-not (Test-Path -Path $modsPath)) {
                Write-Verbose "Mods path does not exist: $modsPath"
                return [PSCustomObject]@{
                    IsInstalled = $false
                    Version     = $null
                    ModPath     = $null
                    ModDescPath = $null
                }
            }

            $modDescPath = Join-Path -Path $modsPath -ChildPath 'FS25_AutoDrive' -AdditionalChildPath 'modDesc.xml'
            if (-not (Test-Path -Path $modDescPath)) {
                Write-Verbose 'Standard AutoDrive path not found, searching for modDesc.xml'
                $found = Get-ChildItem -Path $modsPath -Filter 'modDesc.xml' -Recurse -Depth 2 -ErrorAction SilentlyContinue |
                    Where-Object {
                        (Select-Xml -Path $_.FullName -XPath '/modDesc/title/en' -ErrorAction SilentlyContinue).Node.InnerText -match 'AutoDrive'
                    } |
                    Select-Object -First 1
                
                if ($found) {
                    $modDescPath = $found.FullName
                    Write-Verbose "Found AutoDrive mod at: $modDescPath"
                }
                else {
                    Write-Verbose 'No extracted AutoDrive mod found, searching zip archives'

                    try {
                        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
                    }
                    catch {
                        Write-Verbose 'System.IO.Compression.FileSystem assembly already loaded or unavailable'
                    }

                    $zipCandidates = Get-ChildItem -Path $modsPath -Filter '*.zip' -File -ErrorAction SilentlyContinue |
                        Sort-Object LastWriteTime -Descending

                    foreach ($zip in $zipCandidates) {
                        $archive = $null
                        $entry = $null
                        $reader = $null

                        try {
                            $archive = [System.IO.Compression.ZipFile]::OpenRead($zip.FullName)
                            $entry = $archive.Entries |
                                Where-Object { $_.FullName -match '(^|/)modDesc\.xml$' } |
                                Select-Object -First 1

                            if (-not $entry) {
                                continue
                            }

                            $reader = [System.IO.StreamReader]::new($entry.Open())
                            [xml]$zipXml = $reader.ReadToEnd()
                            $titleNode = $zipXml.SelectSingleNode('/modDesc/title/en')

                            if ($titleNode -and $titleNode.InnerText -match 'AutoDrive') {
                                $modVersion = [System.Version]$zipXml.modDesc.version
                                Write-Verbose "Found AutoDrive zip mod: $($zip.FullName)"
                                return [PSCustomObject]@{
                                    IsInstalled = $true
                                    Version     = $modVersion
                                    ModPath     = $zip.FullName
                                    ModDescPath = "$($zip.FullName)::${entry.FullName}"
                                }
                            }
                        }
                        catch {
                            Write-Verbose "Skipping unreadable zip '$($zip.FullName)': $($_.Exception.Message)"
                        }
                        finally {
                            if ($reader) { $reader.Dispose() }
                            if ($archive) { $archive.Dispose() }
                        }
                    }

                    Write-Verbose 'AutoDrive mod not found in extracted folders or zip archives'
                    return [PSCustomObject]@{
                        IsInstalled = $false
                        Version     = $null
                        ModPath     = $null
                        ModDescPath = $null
                    }
                }
            }

            [xml]$xml = Get-Content -Path $modDescPath -Raw -ErrorAction Stop
            $modVersion = [System.Version]$xml.modDesc.version
            $modPath = Split-Path -Path $modDescPath -Parent
            
            Write-Verbose "Found AutoDrive version: $modVersion at $modPath"
            return [PSCustomObject]@{
                IsInstalled = $true
                Version     = $modVersion
                ModPath     = $modPath
                ModDescPath = $modDescPath
            }
        }
        catch {
            Write-Error "Failed to read local mod: $_"
            return $null
        }
    }
}

<#
.SYNOPSIS
Compares the locally installed AutoDrive version with the latest available version.

.DESCRIPTION
Retrieves both the latest and local AutoDrive versions, then compares them to determine
if an update is available. Outputs a comparison object with version information and update status.

.OUTPUTS
System.Management.Automation.PSObject
An object with properties: LocalVersion, LatestVersion, UpdateAvailable, IsInstalled.
Returns $null if version information cannot be retrieved.

.EXAMPLE
$comparison = Compare-AutodriveVersions
if ($comparison.UpdateAvailable) {
    Write-Host "Update available: $($comparison.LocalVersion) -> $($comparison.LatestVersion)"
}

.NOTES
Returns $null on error instead of throwing to allow graceful degradation.
#>
function Compare-AutodriveVersions {
    [CmdletBinding()]
    param()

    process {
        Write-Verbose 'Starting version comparison'
        Write-Host "`nFetching versions..." -ForegroundColor Cyan
        
        $latest = Get-LatestAutodriveVersion
        $local = Get-LocalAutodriveVersion

        if (-not $latest) {
            Write-Error 'Could not retrieve latest version.'
            return $null
        }
        if (-not $local) {
            Write-Error 'Could not determine local version.'
            return $null
        }

        $updateAvailable = $local.IsInstalled -and ($local.Version -lt $latest.Version)

        Write-Verbose "Comparison complete. Update available: $updateAvailable"
        return [PSCustomObject]@{
            LocalVersion    = if ($local.IsInstalled) { $local.Version } else { 'Not installed' }
            LatestVersion   = $latest.Version
            UpdateAvailable = $updateAvailable
            IsInstalled     = $local.IsInstalled
        }
    }
}

<#
.SYNOPSIS
Installs the latest AutoDrive mod version from GitHub.

.DESCRIPTION
Downloads and installs the latest AutoDrive release zip from GitHub.
If AutoDrive is already installed, the existing version is backed up and replaced.
Includes rollback capability if installation fails.

.PARAMETER WhatIf
Shows what would happen if the install was performed without making changes.

.EXAMPLE
Install-AutodriveModVersion

.EXAMPLE
Install-AutodriveModVersion -WhatIf

.NOTES
Creates a timestamped backup before replacing an existing install. Requires internet connectivity.
#>
function Install-AutodriveModVersion {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param()

    process {
        Write-Verbose 'Starting AutoDrive mod install process'
        $comparison = Compare-AutodriveVersions
        if (-not $comparison) {
            Write-Verbose 'Version comparison failed'
            return
        }

        $latest = Get-LatestAutodriveVersion
        $local = Get-LocalAutodriveVersion
        $modsPath = Get-FarmingSimulatorModsPath
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $backupPath = Join-Path -Path $modsPath -ChildPath "FS25_AutoDrive_backup_$timestamp"
        $zipPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "FS25_AutoDrive_$($latest.Version).zip"
        $installZipPath = Join-Path -Path $modsPath -ChildPath 'FS25_AutoDrive.zip'

        if ($comparison.IsInstalled -and (Test-Path -Path $local.ModPath -PathType Leaf)) {
            $backupPath = "$backupPath.zip"
        }

        if ($PSCmdlet.ShouldProcess('AutoDrive', 'Install latest version')) {
            try {
                if ($comparison.IsInstalled) {
                    Write-Host "`n  Existing install detected: $($comparison.LocalVersion)" -ForegroundColor Yellow
                    Write-Host '  Backing up current mod...' -ForegroundColor Cyan
                    Copy-Item -Path $local.ModPath -Destination $backupPath -Recurse -Force -ErrorAction Stop
                    Write-Host "  Backup saved to: $backupPath" -ForegroundColor Gray

                    Write-Host '  Removing existing version...' -ForegroundColor Cyan
                    Remove-Item -Path $local.ModPath -Recurse -Force -ErrorAction Stop
                }
                else {
                    Write-Host "`n  No existing AutoDrive install found. Proceeding with fresh install..." -ForegroundColor Yellow
                }

                Write-Host "  Downloading v$($latest.Version)..." -ForegroundColor Cyan
                Invoke-WebRequest -Uri $latest.DownloadUrl -OutFile $zipPath -ErrorAction Stop

                Write-Host '  Installing new version as zip...' -ForegroundColor Cyan
                if (Test-Path -Path $installZipPath) {
                    Remove-Item -Path $installZipPath -Force -ErrorAction Stop
                }
                Move-Item -Path $zipPath -Destination $installZipPath -Force -ErrorAction Stop

                Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue

                Write-Host "`n  Successfully installed AutoDrive v$($latest.Version)!" -ForegroundColor Green
                Write-Verbose 'AutoDrive install completed successfully'
            }
            catch {
                Write-Error "Install failed: $_"
                if (Test-Path -Path $backupPath) {
                    Write-Host '  Restoring backup...' -ForegroundColor Yellow
                    if (Test-Path -Path $installZipPath) {
                        Remove-Item -Path $installZipPath -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    if (Test-Path -Path $local.ModPath) {
                        Remove-Item -Path $local.ModPath -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Copy-Item -Path $backupPath -Destination $local.ModPath -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host '  Backup restored.' -ForegroundColor Green
                }
            }
        }
    }
}

<#
.SYNOPSIS
Displays an interactive menu for managing the FS25 AutoDrive mod.

.DESCRIPTION
Shows a menu-driven interface that allows users to check local and latest versions,
compare versions, and install the latest AutoDrive release.

.EXAMPLE
Show-AutoDriveMenu

.NOTES
This function displays an interactive loop until the user selects Quit.
#>
function Show-AutoDriveMenu {
    [CmdletBinding()]
    param()

    process {
        do {
            Write-Host ''
            Write-Host '==============================' -ForegroundColor DarkCyan
            Write-Host '   FS25 AutoDrive Manager     ' -ForegroundColor Cyan
            Write-Host '==============================' -ForegroundColor DarkCyan
            Write-Host ' [1] Check local version'
            Write-Host ' [2] Check latest version'
            Write-Host ' [3] Compare local vs latest'
            Write-Host ' [4] Install latest version'
            Write-Host ' [5] Preview install (WhatIf)'
            Write-Host ' [Q] Quit'
            Write-Host '------------------------------' -ForegroundColor DarkCyan
            $choice = Read-Host ' Select an option'

            switch ($choice.Trim().ToUpper()) {
                '1' {
                    $v = Get-LocalAutodriveVersion
                    if ($v -and $v.IsInstalled) {
                        Write-Host "`n  Installed Version : $($v.Version)" -ForegroundColor Green
                        Write-Host "  Mod Path          : $($v.ModPath)" -ForegroundColor Gray
                    }
                    else {
                        Write-Host "`n  AutoDrive is not installed in your mods folder." -ForegroundColor Yellow
                        Write-Host "  Mods folder: $(Get-FarmingSimulatorModsPath)" -ForegroundColor Gray
                    }
                }
                '2' {
                    $v = Get-LatestAutodriveVersion
                    if ($v) {
                        Write-Host "`n  Latest Version : $($v.Version)" -ForegroundColor Green
                        Write-Host "  Released       : $($v.ReleaseDate.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
                        Write-Host "  Pre-release    : $($v.IsPreRelease)" -ForegroundColor Gray
                    }
                }
                '3' {
                    $c = Compare-AutodriveVersions
                    if ($c) {
                        Write-Host "`n  Local Version  : $($c.LocalVersion)" -ForegroundColor $(if ($c.IsInstalled) { 'White' } else { 'Yellow' })
                        Write-Host "  Latest Version : $($c.LatestVersion)" -ForegroundColor White
                        if ($c.UpdateAvailable) {
                            Write-Host "  Status         : Update available!" -ForegroundColor Yellow
                        }
                        else {
                            Write-Host "  Status         : Up to date" -ForegroundColor Green
                        }
                    }
                }
                '4' {
                    Install-AutodriveModVersion
                }
                '5' {
                    Install-AutodriveModVersion -WhatIf
                }
                'Q' { }
                default {
                    Write-Host "`n  Invalid option. Please try again." -ForegroundColor Red
                }
            }
        } while ($choice.Trim().ToUpper() -ne 'Q')

        Write-Host ''
    }
}

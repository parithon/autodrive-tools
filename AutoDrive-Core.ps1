#Requires -Version 5.1

function Get-FarmingSimulatorModsPath {
    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        return Join-Path $env:APPDATA 'Farming Simulator 25' 'mods'
    }
    elseif ($IsMacOS) {
        return [System.IO.Path]::Combine($HOME, 'Library', 'Application Support', 'Farming Simulator 25', 'mods')
    }
    elseif ($IsLinux) {
        $xdgData = $env:XDG_DATA_HOME
        if (-not $xdgData) { $xdgData = Join-Path $HOME '.local' 'share' }
        return Join-Path $xdgData 'FarmingSimulator25' 'mods'
    }
    else {
        throw 'Unsupported operating system.'
    }
}

function Invoke-GitHubAPICall {
    param([string]$Uri)
    try {
        $headers = @{ 'User-Agent' = 'FS25-AutoDrive-Script'; 'Accept' = 'application/vnd.github+json' }
        return Invoke-RestMethod -Uri $Uri -Headers $headers -ErrorAction Stop
    }
    catch [System.Net.WebException] {
        if ($_.Exception.Response.StatusCode -eq 403) {
            throw 'GitHub API rate limit reached. Please wait a moment and try again.'
        }
        throw "GitHub API error: $($_.Exception.Message)"
    }
    catch {
        throw "Failed to reach GitHub API: $($_.Exception.Message)"
    }
}

function Get-LatestAutodriveVersion {
    try {
        $release = Invoke-GitHubAPICall -Uri 'https://api.github.com/repos/Stephan-S/FS25_AutoDrive/releases/latest'
        return [PSCustomObject]@{
            Version      = [System.Version]$release.tag_name
            ReleaseDate  = [datetime]$release.published_at
            DownloadUrl  = ($release.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1).browser_download_url
            IsPreRelease = $release.prerelease
        }
    }
    catch {
        Write-Error $_
        return $null
    }
}

function Get-LocalAutodriveVersion {
    try {
        $modsPath = Get-FarmingSimulatorModsPath
        if (-not (Test-Path $modsPath)) {
            return [PSCustomObject]@{ IsInstalled = $false; Version = $null; ModPath = $null; ModDescPath = $null }
        }

        $modDescPath = Join-Path $modsPath 'FS25_AutoDrive' 'modDesc.xml'
        if (-not (Test-Path $modDescPath)) {
            $found = Get-ChildItem -Path $modsPath -Filter 'modDesc.xml' -Recurse -Depth 2 -ErrorAction SilentlyContinue |
                Where-Object { (Select-Xml -Path $_.FullName -XPath '/modDesc/title/en' -ErrorAction SilentlyContinue).Node.InnerText -match 'AutoDrive' } |
                Select-Object -First 1
            if ($found) { $modDescPath = $found.FullName }
            else {
                return [PSCustomObject]@{ IsInstalled = $false; Version = $null; ModPath = $null; ModDescPath = $null }
            }
        }

        [xml]$xml = Get-Content -Path $modDescPath -Raw -ErrorAction Stop
        return [PSCustomObject]@{
            IsInstalled = $true
            Version     = [System.Version]$xml.modDesc.version
            ModPath     = Split-Path $modDescPath -Parent
            ModDescPath = $modDescPath
        }
    }
    catch {
        Write-Error "Failed to read local mod: $_"
        return $null
    }
}

function Compare-AutodriveVersions {
    Write-Host "`nFetching versions..." -ForegroundColor Cyan
    $latest = Get-LatestAutodriveVersion
    $local  = Get-LocalAutodriveVersion

    if (-not $latest) { Write-Error 'Could not retrieve latest version.'; return $null }
    if (-not $local)  { Write-Error 'Could not determine local version.'; return $null }

    $updateAvailable = $local.IsInstalled -and ($local.Version -lt $latest.Version)

    return [PSCustomObject]@{
        LocalVersion    = if ($local.IsInstalled) { $local.Version } else { 'Not installed' }
        LatestVersion   = $latest.Version
        UpdateAvailable = $updateAvailable
        IsInstalled     = $local.IsInstalled
    }
}

function Update-AutodriveModVersion {
    $comparison = Compare-AutodriveVersions
    if (-not $comparison) { return }

    if (-not $comparison.IsInstalled) {
        Write-Host "`n  AutoDrive is not installed. Nothing to update." -ForegroundColor Yellow
        return
    }

    if (-not $comparison.UpdateAvailable) {
        Write-Host "`n  You already have the latest version ($($comparison.LocalVersion))." -ForegroundColor Green
        return
    }

    $latest     = Get-LatestAutodriveVersion
    $local      = Get-LocalAutodriveVersion
    $modsPath   = Get-FarmingSimulatorModsPath
    $timestamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupPath = Join-Path $modsPath "FS25_AutoDrive_backup_$timestamp"
    $zipPath    = Join-Path ([System.IO.Path]::GetTempPath()) "FS25_AutoDrive_$($latest.Version).zip"

    try {
        Write-Host "`n  Backing up current mod..." -ForegroundColor Cyan
        Copy-Item -Path $local.ModPath -Destination $backupPath -Recurse -Force
        Write-Host "  Backup saved to: $backupPath" -ForegroundColor Gray

        Write-Host "  Downloading v$($latest.Version)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $latest.DownloadUrl -OutFile $zipPath -ErrorAction Stop

        Write-Host '  Removing old version...' -ForegroundColor Cyan
        Remove-Item -Path $local.ModPath -Recurse -Force

        Write-Host '  Installing new version...' -ForegroundColor Cyan
        Expand-Archive -Path $zipPath -DestinationPath $modsPath -Force

        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue

        Write-Host "`n  Successfully updated AutoDrive to v$($latest.Version)!" -ForegroundColor Green
    }
    catch {
        Write-Error "Update failed: $_"
        if (Test-Path $backupPath) {
            Write-Host '  Restoring backup...' -ForegroundColor Yellow
            if (Test-Path $local.ModPath) { Remove-Item -Path $local.ModPath -Recurse -Force }
            Copy-Item -Path $backupPath -Destination $local.ModPath -Recurse -Force
            Write-Host '  Backup restored.' -ForegroundColor Green
        }
    }
}

function Show-AutoDriveMenu {
    do {
        Write-Host ''
        Write-Host '==============================' -ForegroundColor DarkCyan
        Write-Host '   FS25 AutoDrive Manager     ' -ForegroundColor Cyan
        Write-Host '==============================' -ForegroundColor DarkCyan
        Write-Host ' [1] Check local version'
        Write-Host ' [2] Check latest version'
        Write-Host ' [3] Compare local vs latest'
        Write-Host ' [4] Update to latest version'
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
                Update-AutodriveModVersion
            }
            'Q' { }
            default { Write-Host "`n  Invalid option. Please try again." -ForegroundColor Red }
        }
    } while ($choice.Trim().ToUpper() -ne 'Q')

    Write-Host ''
}

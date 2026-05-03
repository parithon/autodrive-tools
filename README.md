# AutoDrive Tools

A PowerShell-based management tool for the FS25 AutoDrive mod. This suite provides utilities to check, compare, and update the AutoDrive mod for Farming Simulator 2025.

## Features

- ✅ Check locally installed AutoDrive version
- ✅ Check latest available AutoDrive version from GitHub
- ✅ Compare local vs. latest versions
- ✅ Download and install updates automatically
- ✅ Automatic backup before updates
- ✅ Rollback on update failure
- ✅ Interactive menu interface
- ✅ Cross-platform support (Windows & macOS)

## System Requirements

- **PowerShell**: Version 5.1 or later
- **Operating System**: Windows or macOS
- **Internet Connection**: Required for version checking and downloads

## Project Structure

```
autodrive-tools/
├── src/                          # Source code
│   ├── AutoDrive.ps1             # Main entry point script
│   └── AutoDrive-Core.ps1        # Core functions and business logic
├── tests/                        # Test suite
│   └── AutoDrive-Core.Tests.ps1  # Pester tests
├── .github/
│   └── instructions/             # PowerShell coding guidelines
├── README.md                      # This file
└── .gitignore
```

## Installation

### Quick Start

Download and run the main script:

```powershell
irm 'https://parithon.github.io/autodrive-tools/AutoDrive.ps1' | iex
```

## GitHub Pages Deployment

This repository deploys GitHub Pages via GitHub Actions with `src/` as the artifact root.

- Workflow: `.github/workflows/deploy-pages.yml`
- Artifact path: `./src`
- Result: Files in `src/` are published at the site root, so URLs do **not** include `/src`.

### Manual Installation

1. Clone or download this repository
2. Open PowerShell
3. Navigate to the repository directory
4. Run the script:

```powershell
.\src\AutoDrive.ps1
```

## Usage

### Interactive Menu

When you run the script, an interactive menu appears with the following options:

```
==============================
   FS25 AutoDrive Manager     
==============================
 [1] Check local version
 [2] Check latest version
 [3] Compare local vs latest
 [4] Update to latest version
 [5] Preview update (WhatIf)
 [Q] Quit
```

**Option 1 - Check Local Version**: Displays the currently installed AutoDrive version and its location

**Option 2 - Check Latest Version**: Fetches the latest available version from the official GitHub repository

**Option 3 - Compare Versions**: Shows side-by-side comparison of local and latest versions with update status

**Option 4 - Update**: Downloads and installs the latest version. A backup of the current installation is created before updating.

**Option 5 - Preview Update**: Shows what actions would be performed without making any changes (WhatIf mode)

### Programmatic Usage

You can also use the functions programmatically in your own scripts:

```powershell
# Import the core module from src
. './src/AutoDrive-Core.ps1'

# Get the local version
$local = Get-LocalAutodriveVersion
Write-Host "Installed: $($local.Version)"

# Get the latest version
$latest = Get-LatestAutodriveVersion
Write-Host "Latest: $($latest.Version)"

# Compare versions
$comparison = Compare-AutodriveVersions
if ($comparison.UpdateAvailable) {
    Write-Host "Update available!"
}
```

## File Locations

### Windows
```
Documents\My Games\FarmingSimulator2025\mods\
```

### macOS
```
~/Library/Application Support/FarmingSimulator2025/mods/
```

## Function Reference

### Get-FarmingSimulatorModsPath
Returns the path to the Farming Simulator 2025 mods directory for the current operating system.

```powershell
$modsPath = Get-FarmingSimulatorModsPath
```

### Invoke-GitHubAPICall
Calls the GitHub API with proper error handling and rate limit detection.

```powershell
$response = Invoke-GitHubAPICall -Uri 'https://api.github.com/repos/Stephan-S/FS25_AutoDrive/releases/latest'
```

### Get-LatestAutodriveVersion
Retrieves the latest AutoDrive release information from GitHub.

```powershell
$latest = Get-LatestAutodriveVersion
# Returns: Version, ReleaseDate, DownloadUrl, IsPreRelease
```

### Get-LocalAutodriveVersion
Retrieves the locally installed AutoDrive version information.

```powershell
$local = Get-LocalAutodriveVersion
# Returns: IsInstalled, Version, ModPath, ModDescPath
```

### Compare-AutodriveVersions
Compares the local and latest versions and returns update status.

```powershell
$comparison = Compare-AutodriveVersions
# Returns: LocalVersion, LatestVersion, UpdateAvailable, IsInstalled
```

### Update-AutodriveModVersion
Updates the AutoDrive mod to the latest version with automatic backup.

```powershell
# Perform update with confirmation
Update-AutodriveModVersion

# Preview without making changes
Update-AutodriveModVersion -WhatIf
```

### Show-AutoDriveMenu
Displays the interactive management menu.

```powershell
Show-AutoDriveMenu
```

## Testing

This project includes comprehensive Pester tests covering all functions in the `tests/` directory.

### Run All Tests
```powershell
Invoke-Pester -Path ./tests/AutoDrive-Core.Tests.ps1 -Output Detailed
```

### Test Results
- **38 tests** covering all major functions
- Tests for success and failure scenarios
- Proper mocking of external dependencies
- Edge case coverage

## Error Handling

The scripts implement robust error handling:

- **Validation Errors**: Parameters are validated with `ValidateNotNullOrEmpty()`
- **API Errors**: GitHub API errors are caught and reported with helpful messages
- **Rate Limiting**: Special handling for GitHub API rate limit (403) errors
- **File I/O Errors**: File operations include proper error recovery
- **Update Failures**: Automatic rollback on update failure with backup restoration

## Platform Support

- ✅ **Windows**: Full support via `$env:USERPROFILE\Documents\My Games\FarmingSimulator2025\mods`
- ✅ **macOS**: Full support via `~/Library/Application Support/FarmingSimulator2025/mods`
- ❌ **Linux**: Not supported (will throw `NotSupportedException`)

## Contributing

When contributing to this project:

1. Follow PowerShell cmdlet naming conventions (Verb-Noun format)
2. Use `[CmdletBinding()]` on all functions
3. Include comment-based help for public functions
4. Use proper error handling with `$PSCmdlet.ThrowTerminatingError()`
5. Add tests for new functionality
6. Ensure all tests pass before submitting

## Licensing

This project is provided as-is for managing the FS25 AutoDrive mod.

## Related Projects

- [FS25_AutoDrive](https://github.com/Stephan-S/FS25_AutoDrive) - The AutoDrive mod for Farming Simulator 2025

## Troubleshooting

### "API rate limit reached" error
GitHub has rate limits for unauthenticated API requests. Wait a few moments and try again.

### Mod not found in mods directory
Ensure AutoDrive is properly installed in your Farming Simulator mods folder. The script searches recursively through the mods directory.

### Update fails
Check your internet connection. If the update fails, the previous version will be automatically restored from backup.

### Permission denied errors
Ensure you have write permissions to your Farming Simulator mods directory.

## Support

For issues with the AutoDrive mod itself, visit: https://github.com/Stephan-S/FS25_AutoDrive

For issues with this management tool, please check the troubleshooting section above.

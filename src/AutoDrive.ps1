<#
.SYNOPSIS
Downloads and executes the AutoDrive Core script from GitHub.

.DESCRIPTION
This script downloads the latest AutoDrive Core module from the personal GitHub Pages site
and executes it to display the interactive AutoDrive menu for managing the FS25 AutoDrive mod.

.EXAMPLE
.\AutoDrive.ps1

.NOTES
Requires internet connectivity to download the core script.
Requires PowerShell 5.1 or later.
#>

#Requires -Version 5.1

iex (Invoke-RestMethod -Uri 'https://parithon.github.io/autodrive-tools/AutoDrive-Core.ps1')
Show-AutoDriveMenu

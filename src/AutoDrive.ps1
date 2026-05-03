<#
.SYNOPSIS
Loads and executes the AutoDrive Core script.

.DESCRIPTION
This bootstrap script first looks for AutoDrive-Core.ps1 in the local script directory.
If the file is missing, it loads the latest script
from the GitHub Pages URL directly into the current session.

.EXAMPLE
.\AutoDrive.ps1

.NOTES
Requires internet connectivity only when local core is unavailable.
Requires PowerShell 5.1 or later.
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$coreScriptPath = Join-Path -Path $PSScriptRoot -ChildPath 'AutoDrive-Core.ps1'
$coreScriptUri = 'https://parithon.github.io/autodrive-tools/AutoDrive-Core.ps1'

if (Test-Path -Path $coreScriptPath -PathType Leaf) {
	try {
		Write-Verbose "Loading local core script from: $coreScriptPath"
		. $coreScriptPath
	}
	catch {
		Write-Warning "Failed to load local AutoDrive-Core.ps1. Falling back to remote load. Error: $($_.Exception.Message)"
	}
}
else {
	Invoke-WebRequest -Uri $coreScriptUri -ErrorAction Stop | Invoke-Expression
}

if (-not (Get-Command -Name Show-AutoDriveMenu -ErrorAction SilentlyContinue)) {
	Write-Error 'AutoDrive core script loaded, but Show-AutoDriveMenu function was not found.'
	return
}

Show-AutoDriveMenu
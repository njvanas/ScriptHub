<#
.SYNOPSIS
    Intune Proactive Remediation script to install required software.

.DESCRIPTION
    Detection and remediation script for Intune Proactive Remediation.
    Detects if required software is installed and installs if missing.

.PARAMETER SoftwareName
    Name of the software to check/install.

.PARAMETER InstallCommand
    Command to install the software.

.PARAMETER DetectionMethod
    Detection method: Process, File, Registry, Service.

.PARAMETER DetectionValue
    Value to check for detection.

.NOTES
    Designed for Intune Proactive Remediation (Detection and Remediation scripts).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SoftwareName,
    
    [Parameter(Mandatory = $false)]
    [string]$InstallCommand,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Process', 'File', 'Registry', 'Service')]
    [string]$DetectionMethod = 'File',
    
    [Parameter(Mandatory = $false)]
    [string]$DetectionValue
)

$ErrorActionPreference = 'Stop'

function Test-SoftwareInstalled {
    param([string]$Method, [string]$Value)
    
    switch ($Method) {
        'Process' {
            $process = Get-Process -Name $Value -ErrorAction SilentlyContinue
            return $null -ne $process
        }
        'File' {
            return Test-Path -Path $Value
        }
        'Registry' {
            $regPath = $Value.Split('\')
            $keyPath = $regPath[0..($regPath.Length - 2)] -join '\'
            $valueName = $regPath[-1]
            $value = Get-ItemProperty -Path $keyPath -Name $valueName -ErrorAction SilentlyContinue
            return $null -ne $value
        }
        'Service' {
            $service = Get-Service -Name $Value -ErrorAction SilentlyContinue
            return $null -ne $service -and $service.Status -eq 'Running'
        }
    }
    return $false
}

try {
    # Detection script
    if (-not $DetectionValue) {
        Write-Output "Detection value not specified"
        exit 1
    }
    
    $isInstalled = Test-SoftwareInstalled -Method $DetectionMethod -Value $DetectionValue
    
    if ($isInstalled) {
        Write-Output "$SoftwareName is installed"
        exit 0
    }
    else {
        Write-Output "$SoftwareName is not installed"
        
        # Remediation script
        if ($InstallCommand) {
            Write-Output "Installing $SoftwareName..."
            Invoke-Expression $InstallCommand
            Start-Sleep -Seconds 30
            
            # Verify installation
            $isInstalled = Test-SoftwareInstalled -Method $DetectionMethod -Value $DetectionValue
            if ($isInstalled) {
                Write-Output "$SoftwareName installed successfully"
                exit 0
            }
            else {
                Write-Output "Failed to install $SoftwareName"
                exit 1
            }
        }
        else {
            Write-Output "Install command not provided"
            exit 1
        }
    }
}
catch {
    Write-Error "Script execution failed: $_"
    exit 1
}


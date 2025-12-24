<#
.SYNOPSIS
    Gets Intune device compliance status.

.DESCRIPTION
    Retrieves compliance status for Intune-managed devices using Microsoft Graph API.

.PARAMETER DeviceId
    Optional specific device ID filter.

.PARAMETER ExportToCsv
    Path to export results as CSV.

.NOTES
    Requires Microsoft.Graph.Identity.DirectoryManagement and Microsoft.Graph.DeviceManagement modules.
    Requires Connect-MgGraph with appropriate permissions (DeviceManagementManagedDevices.Read.All).

.EXAMPLE
    Get-IntuneDeviceCompliance -ExportToCsv "C:\Reports\IntuneCompliance.csv"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DeviceId,
    
    [Parameter(Mandatory = $false)]
    [string]$ExportToCsv
)

$ErrorActionPreference = 'Stop'

# Check for Graph module
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.DeviceManagement)) {
    throw "Microsoft.Graph.DeviceManagement module is required. Install with: Install-Module -Name Microsoft.Graph.DeviceManagement -Force"
}

Import-Module Microsoft.Graph.DeviceManagement -ErrorAction Stop

try {
    # Check Graph connection
    $context = Get-MgContext -ErrorAction SilentlyContinue
    if (-not $context) {
        Write-Verbose "Not connected to Microsoft Graph. Connecting..."
        Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All" -ErrorAction Stop
    }
    
    Write-Verbose "Retrieving Intune devices..."
    
    $devices = if ($DeviceId) {
        Get-MgDeviceManagementManagedDevice -ManagedDeviceId $DeviceId -ErrorAction Stop
    }
    else {
        Get-MgDeviceManagementManagedDevice -All -ErrorAction Stop
    }
    
    $compliance = foreach ($device in $devices) {
        $complianceState = $device.ComplianceState
        $jailBroken = $device.JailBroken
        $osVersion = $device.OperatingSystemVersion
        $lastSync = $device.LastSyncDateTime
        
        $issues = @()
        $severity = 'Info'
        
        if ($complianceState -ne 'Compliant') {
            $issues += "Non-compliant: $complianceState"
            $severity = 'High'
        }
        
        if ($jailBroken) {
            $issues += "Jailbroken/Rooted device"
            $severity = 'Critical'
        }
        
        if ($lastSync) {
            $daysSinceSync = (New-TimeSpan -Start $lastSync -End (Get-Date)).Days
            if ($daysSinceSync -gt 30) {
                $issues += "Device not synced in $daysSinceSync days"
                if ($severity -eq 'Info') { $severity = 'Medium' }
            }
        }
        
        [PSCustomObject]@{
            DeviceName = $device.DeviceName
            DeviceId = $device.Id
            UserPrincipalName = $device.UserPrincipalName
            ComplianceState = $complianceState
            OperatingSystem = $device.OperatingSystem
            OperatingSystemVersion = $osVersion
            ManagementAgent = $device.ManagementAgent
            EnrollmentType = $device.EnrollmentType
            IsManaged = $device.IsManaged
            IsEncrypted = $device.IsEncrypted
            JailBroken = $jailBroken
            LastSyncDateTime = $lastSync
            Issues = ($issues -join '; ')
            Severity = $severity
        }
    }
    
    Write-Verbose "Found $($compliance.Count) devices"
    
    if ($ExportToCsv) {
        $compliance | Export-Csv -Path $ExportToCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Device compliance exported to: $ExportToCsv" -ForegroundColor Green
    }
    
    return $compliance
}
catch {
    Write-Error "Failed to retrieve device compliance: $_"
    throw
}


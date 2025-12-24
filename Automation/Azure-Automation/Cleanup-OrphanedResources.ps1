<#
.SYNOPSIS
    Azure Automation runbook to clean up orphaned resources.

.DESCRIPTION
    Identifies and optionally removes orphaned resources such as:
    - Unattached disks
    - Empty resource groups
    - Unused public IPs
    - Orphaned network interfaces

.PARAMETER SubscriptionId
    Subscription ID to process.

.PARAMETER ResourceTypes
    Array of resource types to check: Disks, PublicIPs, NICs, ResourceGroups.

.PARAMETER WhatIf
    Preview resources that would be deleted without actually deleting them.

.NOTES
    Designed for use in Azure Automation with managed identity authentication.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Disks', 'PublicIPs', 'NICs', 'ResourceGroups')]
    [string[]]$ResourceTypes = @('Disks', 'PublicIPs', 'NICs'),
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

# Connect using managed identity in Azure Automation
try {
    Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
}
catch {
    Write-Error "Failed to authenticate: $_"
    throw
}

$orphanedResources = @()

# Check for unattached disks
if ($ResourceTypes -contains 'Disks') {
    Write-Output "Checking for unattached disks..."
    $disks = Get-AzDisk | Where-Object { $_.DiskState -eq 'Unattached' -and $_.TimeCreated -lt (Get-Date).AddDays(-30) }
    
    foreach ($disk in $disks) {
        $orphanedResources += [PSCustomObject]@{
            Type = 'Disk'
            Name = $disk.Name
            ResourceGroupName = $disk.ResourceGroupName
            ResourceId = $disk.Id
            Age = (New-TimeSpan -Start $disk.TimeCreated -End (Get-Date)).Days
        }
    }
}

# Check for unused public IPs
if ($ResourceTypes -contains 'PublicIPs') {
    Write-Output "Checking for unused public IPs..."
    $publicIPs = Get-AzPublicIpAddress | Where-Object { -not $_.IpConfiguration -and $_.TimeCreated -lt (Get-Date).AddDays(-30) }
    
    foreach ($ip in $publicIPs) {
        $orphanedResources += [PSCustomObject]@{
            Type = 'PublicIP'
            Name = $ip.Name
            ResourceGroupName = $ip.ResourceGroupName
            ResourceId = $ip.Id
            Age = (New-TimeSpan -Start $ip.TimeCreated -End (Get-Date)).Days
        }
    }
}

# Check for orphaned NICs
if ($ResourceTypes -contains 'NICs') {
    Write-Output "Checking for orphaned network interfaces..."
    $nics = Get-AzNetworkInterface | Where-Object { -not $_.VirtualMachine -and $_.TimeCreated -lt (Get-Date).AddDays(-30) }
    
    foreach ($nic in $nics) {
        $orphanedResources += [PSCustomObject]@{
            Type = 'NetworkInterface'
            Name = $nic.Name
            ResourceGroupName = $nic.ResourceGroupName
            ResourceId = $nic.Id
            Age = (New-TimeSpan -Start $nic.TimeCreated -End (Get-Date)).Days
        }
    }
}

# Check for empty resource groups
if ($ResourceTypes -contains 'ResourceGroups') {
    Write-Output "Checking for empty resource groups..."
    $resourceGroups = Get-AzResourceGroup | Where-Object {
        $resources = Get-AzResource -ResourceGroupName $_.ResourceGroupName
        $resources.Count -eq 0
    }
    
    foreach ($rg in $resourceGroups) {
        $orphanedResources += [PSCustomObject]@{
            Type = 'ResourceGroup'
            Name = $rg.ResourceGroupName
            ResourceGroupName = $rg.ResourceGroupName
            ResourceId = $rg.ResourceId
            Age = $null
        }
    }
}

Write-Output "Found $($orphanedResources.Count) orphaned resources"

if ($orphanedResources.Count -gt 0) {
    if ($WhatIf) {
        Write-Output "Resources that would be deleted:"
        $orphanedResources | Format-Table -AutoSize
    }
    else {
        foreach ($resource in $orphanedResources) {
            try {
                if ($PSCmdlet.ShouldProcess($resource.Name, "Remove orphaned $($resource.Type)")) {
                    switch ($resource.Type) {
                        'Disk' { Remove-AzDisk -ResourceGroupName $resource.ResourceGroupName -DiskName $resource.Name -Force }
                        'PublicIP' { Remove-AzPublicIpAddress -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name -Force }
                        'NetworkInterface' { Remove-AzNetworkInterface -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name -Force }
                        'ResourceGroup' { Remove-AzResourceGroup -Name $resource.ResourceGroupName -Force }
                    }
                    Write-Output "Removed: $($resource.Type) - $($resource.Name)"
                }
            }
            catch {
                Write-Warning "Failed to remove $($resource.Type) $($resource.Name): $_"
            }
        }
    }
}

return $orphanedResources


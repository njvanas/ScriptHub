<#
.SYNOPSIS
    Gets detailed inventory of Azure Virtual Machines.

.DESCRIPTION
    Retrieves comprehensive VM information including status, size, OS, disks, networking,
    and tags. Useful for inventory, compliance, and cost management.

.PARAMETER SubscriptionId
    Subscription ID to query. Uses current context if not specified.

.PARAMETER ResourceGroupName
    Optional resource group filter.

.PARAMETER VMName
    Optional specific VM name filter.

.PARAMETER ExportToCsv
    Path to export results as CSV.

.EXAMPLE
    Get-AzVMInventory -ExportToCsv "C:\Reports\VMInventory.csv"
    Get-AzVMInventory -ResourceGroupName "Production-RG"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$VMName,
    
    [Parameter(Mandatory = $false)]
    [string]$ExportToCsv
)

. "$PSScriptRoot\..\..\Utilities\Common-Functions\Test-AzConnection.ps1"
Test-AzConnection -ConnectIfNeeded $true | Out-Null

$ErrorActionPreference = 'Stop'

try {
    if ($SubscriptionId) {
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    }
    
    $params = @{}
    if ($ResourceGroupName) { $params.ResourceGroupName = $ResourceGroupName }
    if ($VMName) { $params.Name = $VMName }
    
    Write-Verbose "Retrieving VM inventory..."
    $vms = Get-AzVM @params
    
    $vmInventory = foreach ($vm in $vms) {
        $vmStatus = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status -ErrorAction SilentlyContinue
        $osDisk = $vm.StorageProfile.OsDisk
        $dataDisks = $vm.StorageProfile.DataDisks
        
        [PSCustomObject]@{
            Name = $vm.Name
            ResourceGroupName = $vm.ResourceGroupName
            Location = $vm.Location
            SubscriptionId = (Get-AzContext).Subscription.Id
            PowerState = ($vmStatus.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).Code
            ProvisioningState = ($vmStatus.Statuses | Where-Object { $_.Code -notlike 'PowerState/*' }).Code
            VMSize = $vm.HardwareProfile.VmSize
            OSType = $vm.StorageProfile.OsDisk.OsType
            OSDiskType = $osDisk.ManagedDisk.StorageAccountType
            OSDiskSizeGB = $osDisk.DiskSizeGB
            DataDiskCount = $dataDisks.Count
            DataDiskTotalSizeGB = ($dataDisks | Measure-Object -Property DiskSizeGB -Sum).Sum
            NICs = ($vm.NetworkProfile.NetworkInterfaces | ForEach-Object { $_.Id.Split('/')[-1] }) -join '; '
            AvailabilitySet = if ($vm.AvailabilitySetReference) { $vm.AvailabilitySetReference.Id.Split('/')[-1] } else { $null }
            Tags = ($vm.Tags.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join '; '
            CreatedTime = $vm.TimeCreated
            ResourceId = $vm.Id
        }
    }
    
    Write-Verbose "Found $($vmInventory.Count) VMs"
    
    if ($ExportToCsv) {
        $vmInventory | Export-Csv -Path $ExportToCsv -NoTypeInformation -Encoding UTF8
        Write-Host "VM inventory exported to: $ExportToCsv" -ForegroundColor Green
    }
    
    return $vmInventory
}
catch {
    Write-Error "Failed to retrieve VM inventory: $_"
    throw
}


<#
.SYNOPSIS
    Resizes Azure Virtual Machines based on utilization or schedule.

.DESCRIPTION
    Resizes VMs to optimize costs based on utilization metrics or scheduled resizing.
    Supports both scale-up and scale-down operations.

.PARAMETER ResourceGroupName
    Resource group name containing the VMs.

.PARAMETER VMName
    Specific VM name. If not specified, processes all VMs in resource group.

.PARAMETER TargetSize
    Target VM size (e.g., Standard_B2s, Standard_D2s_v3).

.PARAMETER ResizeBasedOnUtilization
    Automatically resize based on CPU utilization metrics.

.PARAMETER UtilizationThreshold
    CPU utilization threshold percentage. Default: 20 for scale-down, 80 for scale-up.

.PARAMETER WhatIf
    Preview resize operations without making changes.

.EXAMPLE
    Resize-AzVM -ResourceGroupName "Production-RG" -VMName "WebServer01" -TargetSize "Standard_B2s" -WhatIf
    Resize-AzVM -ResourceGroupName "Dev-RG" -ResizeBasedOnUtilization -UtilizationThreshold 20
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$VMName,
    
    [Parameter(Mandatory = $false)]
    [string]$TargetSize,
    
    [Parameter(Mandatory = $false)]
    [switch]$ResizeBasedOnUtilization,
    
    [Parameter(Mandatory = $false)]
    [int]$UtilizationThreshold = 20,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

. "$PSScriptRoot\..\..\Utilities\Common-Functions\Test-AzConnection.ps1"
Test-AzConnection -ConnectIfNeeded $true | Out-Null

$ErrorActionPreference = 'Stop'

try {
    $params = @{ ResourceGroupName = $ResourceGroupName }
    if ($VMName) { $params.Name = $VMName }
    
    $vms = Get-AzVM @params
    
    foreach ($vm in $vms) {
        $currentSize = $vm.HardwareProfile.VmSize
        Write-Verbose "Processing VM: $($vm.Name) (Current size: $currentSize)"
        
        if ($ResizeBasedOnUtilization) {
            # Get CPU utilization from metrics (requires diagnostic settings enabled)
            Write-Verbose "Analyzing utilization for: $($vm.Name)"
            # Note: This requires diagnostic settings and Log Analytics
            # Implementation would query metrics API or Log Analytics
            Write-Warning "Utilization-based resizing requires diagnostic settings. Use TargetSize parameter for direct resizing."
            continue
        }
        
        if ($TargetSize) {
            if ($currentSize -eq $TargetSize) {
                Write-Verbose "VM $($vm.Name) is already size $TargetSize"
                continue
            }
            
            if ($PSCmdlet.ShouldProcess($vm.Name, "Resize VM from $currentSize to $TargetSize")) {
                if (-not $WhatIf) {
                    # Stop VM if running
                    $vmStatus = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status
                    $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).Code
                    
                    if ($powerState -eq 'PowerState/running') {
                        Write-Verbose "Stopping VM: $($vm.Name)"
                        Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force
                        $vm | Wait-AzVM -Status Stopped
                    }
                    
                    Write-Verbose "Resizing VM: $($vm.Name) to $TargetSize"
                    $vm.HardwareProfile.VmSize = $TargetSize
                    Update-AzVM -ResourceGroupName $vm.ResourceGroupName -VM $vm -ErrorAction Stop
                    
                    if ($powerState -eq 'PowerState/running') {
                        Write-Verbose "Starting VM: $($vm.Name)"
                        Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name
                    }
                    
                    Write-Host "Successfully resized VM: $($vm.Name) to $TargetSize" -ForegroundColor Green
                }
                else {
                    Write-Host "Would resize VM: $($vm.Name) from $currentSize to $TargetSize" -ForegroundColor Yellow
                }
            }
        }
    }
}
catch {
    Write-Error "Failed to resize VM: $_"
    throw
}


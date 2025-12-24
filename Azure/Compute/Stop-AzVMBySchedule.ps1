<#
.SYNOPSIS
    Stops Azure VMs based on schedule tags.

.DESCRIPTION
    Stops VMs that have a 'ScheduleStop' tag matching the current time/day.
    Designed for use with Azure Automation or scheduled tasks.

.PARAMETER SubscriptionId
    Subscription ID to process. Uses current context if not specified.

.PARAMETER ResourceGroupName
    Optional resource group filter.

.PARAMETER ScheduleTagName
    Tag name containing schedule. Default: 'ScheduleStop'.

.PARAMETER WhatIf
    Preview which VMs would be stopped without actually stopping them.

.EXAMPLE
    Stop-AzVMBySchedule -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$ScheduleTagName = 'ScheduleStop',
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

. "$PSScriptRoot\..\..\Utilities\Common-Functions\Test-AzConnection.ps1"
Test-AzConnection -ConnectIfNeeded $true | Out-Null

$ErrorActionPreference = 'Stop'

try {
    if ($SubscriptionId) {
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    }
    
    $currentTime = Get-Date
    $currentDay = $currentTime.DayOfWeek.ToString()
    $currentHour = $currentTime.Hour
    
    Write-Verbose "Current time: $currentTime ($currentDay, Hour: $currentHour)"
    
    $params = @{}
    if ($ResourceGroupName) { $params.ResourceGroupName = $ResourceGroupName }
    
    $vms = Get-AzVM @params | Where-Object {
        $_.Tags -and $_.Tags.ContainsKey($ScheduleTagName)
    }
    
    $vmsToStop = @()
    
    foreach ($vm in $vms) {
        $schedule = $vm.Tags[$ScheduleTagName]
        $shouldStop = $false
        
        if ($schedule -match '^(?<days>[\w-]+):(?<time>\d{2}:\d{2})$') {
            $days = $matches['days']
            $time = $matches['time']
            $scheduleHour = [int]($time.Split(':')[0])
            
            if ($days -eq 'Daily' -or $days -eq 'All') {
                $shouldStop = ($scheduleHour -eq $currentHour)
            }
            elseif ($days -match '-') {
                $dayRange = $days.Split('-')
                $startDay = [System.DayOfWeek]::$dayRange[0]
                $endDay = [System.DayOfWeek]::$dayRange[1]
                $currentDayEnum = [System.DayOfWeek]::$currentDay
                
                if ($currentDayEnum -ge $startDay -and $currentDayEnum -le $endDay -and $scheduleHour -eq $currentHour) {
                    $shouldStop = $true
                }
            }
            elseif ($days -eq $currentDay) {
                $shouldStop = ($scheduleHour -eq $currentHour)
            }
        }
        elseif ($schedule -match '^\d{2}:\d{2}$') {
            $scheduleHour = [int]($schedule.Split(':')[0])
            $shouldStop = ($scheduleHour -eq $currentHour)
        }
        
        if ($shouldStop) {
            $vmStatus = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status -ErrorAction SilentlyContinue
            $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).Code
            
            if ($powerState -eq 'PowerState/running') {
                $vmsToStop += $vm
            }
        }
    }
    
    if ($vmsToStop.Count -eq 0) {
        Write-Verbose "No VMs scheduled to stop at this time"
        return
    }
    
    Write-Verbose "Found $($vmsToStop.Count) VMs to stop"
    
    foreach ($vm in $vmsToStop) {
        if ($WhatIf -or $PSCmdlet.ShouldProcess($vm.Name, "Stop VM")) {
            if (-not $WhatIf) {
                Write-Verbose "Stopping VM: $($vm.Name)"
                Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force -NoWait
            }
            else {
                Write-Host "Would stop VM: $($vm.Name) in $($vm.ResourceGroupName)" -ForegroundColor Yellow
            }
        }
    }
}
catch {
    Write-Error "Failed to stop VMs by schedule: $_"
    throw
}


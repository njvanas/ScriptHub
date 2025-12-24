<#
.SYNOPSIS
    Starts Azure VMs based on schedule tags.

.DESCRIPTION
    Starts VMs that have a 'ScheduleStart' tag matching the current time/day.
    Designed for use with Azure Automation or scheduled tasks.

.PARAMETER SubscriptionId
    Subscription ID to process. Uses current context if not specified.

.PARAMETER ResourceGroupName
    Optional resource group filter.

.PARAMETER ScheduleTagName
    Tag name containing schedule. Default: 'ScheduleStart'.

.PARAMETER WhatIf
    Preview which VMs would be started without actually starting them.

.EXAMPLE
    Start-AzVMBySchedule -WhatIf
    Start-AzVMBySchedule -SubscriptionId "12345678-1234-1234-1234-123456789012"
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$ScheduleTagName = 'ScheduleStart',
    
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
    
    $vmsToStart = @()
    
    foreach ($vm in $vms) {
        $schedule = $vm.Tags[$ScheduleTagName]
        $shouldStart = $false
        
        # Parse schedule formats: "Mon-Fri:08:00", "Daily:08:00", "08:00"
        if ($schedule -match '^(?<days>[\w-]+):(?<time>\d{2}:\d{2})$') {
            $days = $matches['days']
            $time = $matches['time']
            $scheduleHour = [int]($time.Split(':')[0])
            
            if ($days -eq 'Daily' -or $days -eq 'All') {
                $shouldStart = ($scheduleHour -eq $currentHour)
            }
            elseif ($days -match '-') {
                $dayRange = $days.Split('-')
                $startDay = [System.DayOfWeek]::$dayRange[0]
                $endDay = [System.DayOfWeek]::$dayRange[1]
                $currentDayEnum = [System.DayOfWeek]::$currentDay
                
                if ($currentDayEnum -ge $startDay -and $currentDayEnum -le $endDay -and $scheduleHour -eq $currentHour) {
                    $shouldStart = $true
                }
            }
            elseif ($days -eq $currentDay) {
                $shouldStart = ($scheduleHour -eq $currentHour)
            }
        }
        elseif ($schedule -match '^\d{2}:\d{2}$') {
            $scheduleHour = [int]($schedule.Split(':')[0])
            $shouldStart = ($scheduleHour -eq $currentHour)
        }
        
        if ($shouldStart) {
            $vmStatus = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status -ErrorAction SilentlyContinue
            $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).Code
            
            if ($powerState -ne 'PowerState/running') {
                $vmsToStart += $vm
            }
        }
    }
    
    if ($vmsToStart.Count -eq 0) {
        Write-Verbose "No VMs scheduled to start at this time"
        return
    }
    
    Write-Verbose "Found $($vmsToStart.Count) VMs to start"
    
    foreach ($vm in $vmsToStart) {
        if ($WhatIf -or $PSCmdlet.ShouldProcess($vm.Name, "Start VM")) {
            if (-not $WhatIf) {
                Write-Verbose "Starting VM: $($vm.Name)"
                Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -NoWait
            }
            else {
                Write-Host "Would start VM: $($vm.Name) in $($vm.ResourceGroupName)" -ForegroundColor Yellow
            }
        }
    }
}
catch {
    Write-Error "Failed to start VMs by schedule: $_"
    throw
}


<#
.SYNOPSIS
    Updates all Azure PowerShell modules to latest versions.

.DESCRIPTION
    Updates all installed Az.* modules to their latest versions.
    Can update to specific versions or latest available.

.PARAMETER Scope
    Update scope: CurrentUser or AllUsers. Default: CurrentUser.

.PARAMETER Force
    Force update even if already at latest version.

.PARAMETER WhatIf
    Preview updates without installing.

.EXAMPLE
    Update-AzModules -WhatIf
    Update-AzModules -Scope CurrentUser
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser',
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

Write-Host "Checking for Azure PowerShell module updates..." -ForegroundColor Cyan

$installedModules = Get-Module -ListAvailable Az.* | Sort-Object Name
$modulesToUpdate = @()

foreach ($module in $installedModules) {
    try {
        $latestModule = Find-Module -Name $module.Name -ErrorAction Stop
        $latestVersion = $latestModule.Version
        
        if ($module.Version -lt $latestVersion -or $Force) {
            $modulesToUpdate += [PSCustomObject]@{
                Name = $module.Name
                CurrentVersion = $module.Version
                LatestVersion = $latestVersion
            }
        }
    }
    catch {
        Write-Warning "Failed to check $($module.Name): $_"
    }
}

if ($modulesToUpdate.Count -eq 0) {
    Write-Host "All modules are up to date" -ForegroundColor Green
    return
}

Write-Host "`nModules to update:" -ForegroundColor Yellow
$modulesToUpdate | Format-Table -AutoSize

if ($PSCmdlet.ShouldProcess("Azure Modules", "Update $($modulesToUpdate.Count) modules")) {
    foreach ($module in $modulesToUpdate) {
        if (-not $WhatIf) {
            try {
                Write-Host "Updating $($module.Name) from $($module.CurrentVersion) to $($module.LatestVersion)..." -ForegroundColor Cyan
                Update-Module -Name $module.Name -RequiredVersion $module.LatestVersion -Scope $Scope -Force -ErrorAction Stop
                Write-Host "  Updated successfully" -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to update $($module.Name): $_"
            }
        }
        else {
            Write-Host "Would update $($module.Name) from $($module.CurrentVersion) to $($module.LatestVersion)" -ForegroundColor Yellow
        }
    }
    
    if (-not $WhatIf) {
        Write-Host "`nModule update completed" -ForegroundColor Green
    }
}


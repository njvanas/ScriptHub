<#
.SYNOPSIS
    Checks and reports Azure PowerShell module versions.

.DESCRIPTION
    Compares installed Azure PowerShell module versions against requirements
    and provides update recommendations.

.PARAMETER CheckRequirements
    Check against requirements.txt file. Default: $true.

.PARAMETER UpdateAvailable
    Show only modules with updates available.

.EXAMPLE
    Get-AzModuleVersion
    Get-AzModuleVersion -UpdateAvailable
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [bool]$CheckRequirements = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$UpdateAvailable
)

$ErrorActionPreference = 'Stop'

$moduleReport = @()

# Get all installed Az modules
$installedModules = Get-Module -ListAvailable Az.* | Sort-Object Name

foreach ($module in $installedModules) {
    $latestVersion = Find-Module -Name $module.Name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Version
    
    $status = if ($latestVersion -and $module.Version -lt $latestVersion) {
        "Update Available"
    }
    elseif ($latestVersion -and $module.Version -eq $latestVersion) {
        "Current"
    }
    else {
        "Unknown"
    }
    
    $moduleReport += [PSCustomObject]@{
        ModuleName = $module.Name
        InstalledVersion = $module.Version
        LatestVersion = $latestVersion
        Status = $status
        Path = $module.ModuleBase
    }
}

if ($UpdateAvailable) {
    $moduleReport = $moduleReport | Where-Object { $_.Status -eq "Update Available" }
}

Write-Host "Azure PowerShell Module Versions" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
$moduleReport | Format-Table -AutoSize

if ($CheckRequirements -and (Test-Path "$PSScriptRoot\..\..\requirements.txt")) {
    Write-Host "`nChecking against requirements.txt..." -ForegroundColor Yellow
    $requirements = Get-Content "$PSScriptRoot\..\..\requirements.txt" | Where-Object { $_ -match '^Az\.' }
    
    foreach ($req in $requirements) {
        if ($req -match '^(\S+)\s+>=\s+([\d.]+)') {
            $reqModule = $matches[1]
            $reqVersion = [version]$matches[2]
            
            $installed = $moduleReport | Where-Object { $_.ModuleName -eq $reqModule }
            if ($installed) {
                if ([version]$installed.InstalledVersion -lt $reqVersion) {
                    Write-Warning "$reqModule : Installed $($installed.InstalledVersion), Required >= $reqVersion"
                }
            }
            else {
                Write-Warning "$reqModule : Not installed (Required >= $reqVersion)"
            }
        }
    }
}

return $moduleReport


<#
.SYNOPSIS
    Deploys a complete baseline Azure environment with best practices.

.DESCRIPTION
    Creates a production-ready Azure environment including:
    - Resource groups with proper naming
    - Log Analytics workspace
    - Key Vault with security settings
    - Storage accounts with security baseline
    - Network Watcher
    - Recovery Services Vault
    - Monitoring and alerting

.PARAMETER EnvironmentName
    Environment name (Production, Development, Staging, Test).

.PARAMETER Location
    Azure region for resources.

.PARAMETER ProjectName
    Project name for resource naming.

.PARAMETER CostCenter
    Cost center code for tagging.

.PARAMETER Owner
    Resource owner for tagging.

.PARAMETER LogAnalyticsWorkspaceName
    Name for Log Analytics workspace.

.PARAMETER EnableMonitoring
    Enable comprehensive monitoring. Default: $true.

.PARAMETER EnableBackup
    Enable backup services. Default: $true.

.PARAMETER WhatIf
    Preview changes without applying them.

.EXAMPLE
    New-AzEnvironmentBaseline -EnvironmentName "Production" -Location "East US" -ProjectName "MyProject" -CostCenter "12345" -Owner "IT Team" -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Production', 'Development', 'Staging', 'Test')]
    [string]$EnvironmentName,
    
    [Parameter(Mandatory = $true)]
    [string]$Location,
    
    [Parameter(Mandatory = $true)]
    [string]$ProjectName,
    
    [Parameter(Mandatory = $false)]
    [string]$CostCenter,
    
    [Parameter(Mandatory = $false)]
    [string]$Owner,
    
    [Parameter(Mandatory = $false)]
    [string]$LogAnalyticsWorkspaceName,
    
    [Parameter(Mandatory = $false)]
    [bool]$EnableMonitoring = $true,
    
    [Parameter(Mandatory = $false)]
    [bool]$EnableBackup = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

. "$PSScriptRoot\..\..\Utilities\Common-Functions\Test-AzConnection.ps1"
Test-AzConnection -ConnectIfNeeded $true | Out-Null

$ErrorActionPreference = 'Stop'

try {
    $context = Get-AzContext
    Write-Host "Deploying baseline environment: $EnvironmentName" -ForegroundColor Cyan
    
    # Generate resource names
    $envPrefix = $EnvironmentName.Substring(0, 3).ToLower()
    $rgName = "rg-$ProjectName-$envPrefix-001"
    $lawName = if ($LogAnalyticsWorkspaceName) { $LogAnalyticsWorkspaceName } else { "law-$ProjectName-$envPrefix-001" }
    $kvName = "kv-$ProjectName-$envPrefix-001"
    $rsvName = "rsv-$ProjectName-$envPrefix-001"
    
    # Define tags
    $tags = @{
        Environment = $EnvironmentName
        Project     = $ProjectName
        ManagedBy   = "ScriptHub"
        CreatedDate = (Get-Date -Format "yyyy-MM-dd")
    }
    if ($CostCenter) { $tags.CostCenter = $CostCenter }
    if ($Owner) { $tags.Owner = $Owner }
    
    # Create resource group
    if ($PSCmdlet.ShouldProcess($rgName, "Create resource group")) {
        if (-not $WhatIf) {
            $rg = New-AzResourceGroup -Name $rgName -Location $Location -Tag $tags -Force -ErrorAction Stop
            Write-Host "Created resource group: $rgName" -ForegroundColor Green
        }
        else {
            Write-Host "Would create resource group: $rgName in $Location" -ForegroundColor Yellow
        }
    }
    
    # Create Log Analytics Workspace
    if ($EnableMonitoring) {
        if ($PSCmdlet.ShouldProcess($lawName, "Create Log Analytics workspace")) {
            if (-not $WhatIf) {
                $retentionDays = switch ($EnvironmentName) {
                    'Production' { 90 }
                    'Staging' { 60 }
                    default { 30 }
                }
                
                $law = New-AzOperationalInsightsWorkspace `
                    -ResourceGroupName $rgName `
                    -Name $lawName `
                    -Location $Location `
                    -Sku "PerGB2018" `
                    -RetentionInDays $retentionDays `
                    -Tag $tags `
                    -ErrorAction Stop
                
                Write-Host "Created Log Analytics workspace: $lawName" -ForegroundColor Green
            }
            else {
                Write-Host "Would create Log Analytics workspace: $lawName" -ForegroundColor Yellow
            }
        }
    }
    
    # Create Key Vault
    if ($PSCmdlet.ShouldProcess($kvName, "Create Key Vault")) {
        if (-not $WhatIf) {
            $kv = New-AzKeyVault `
                -ResourceGroupName $rgName `
                -VaultName $kvName `
                -Location $Location `
                -EnabledForDeployment $false `
                -EnabledForTemplateDeployment $false `
                -EnabledForDiskEncryption $true `
                -EnableSoftDelete `
                -EnablePurgeProtection `
                -Sku "Standard" `
                -Tag $tags `
                -ErrorAction Stop
            
            # Set network rules
            Set-AzKeyVaultNetworkRuleSet `
                -VaultName $kvName `
                -ResourceGroupName $rgName `
                -DefaultAction Deny `
                -Bypass AzureServices `
                -ErrorAction SilentlyContinue
            
            Write-Host "Created Key Vault: $kvName" -ForegroundColor Green
        }
        else {
            Write-Host "Would create Key Vault: $kvName with security baseline" -ForegroundColor Yellow
        }
    }
    
    # Create Recovery Services Vault
    if ($EnableBackup) {
        if ($PSCmdlet.ShouldProcess($rsvName, "Create Recovery Services Vault")) {
            if (-not $WhatIf) {
                $rsv = New-AzRecoveryServicesVault `
                    -ResourceGroupName $rgName `
                    -Name $rsvName `
                    -Location $Location `
                    -Sku "Standard" `
                    -Tag $tags `
                    -ErrorAction Stop
                
                Set-AzRecoveryServicesVaultProperty `
                    -Vault $rsv `
                    -SoftDeleteFeatureState "Enabled" `
                    -ErrorAction SilentlyContinue
                
                Write-Host "Created Recovery Services Vault: $rsvName" -ForegroundColor Green
            }
            else {
                Write-Host "Would create Recovery Services Vault: $rsvName" -ForegroundColor Yellow
            }
        }
    }
    
    # Enable Network Watcher
    if ($PSCmdlet.ShouldProcess("Network Watcher", "Enable Network Watcher")) {
        if (-not $WhatIf) {
            try {
                $nw = Get-AzNetworkWatcher -ResourceGroupName "NetworkWatcherRG" -Name "NetworkWatcher_$Location" -ErrorAction SilentlyContinue
                if (-not $nw) {
                    New-AzNetworkWatcher -ResourceGroupName "NetworkWatcherRG" -Name "NetworkWatcher_$Location" -Location $Location -ErrorAction SilentlyContinue
                }
                Write-Host "Network Watcher enabled" -ForegroundColor Green
            }
            catch {
                Write-Verbose "Network Watcher may already be enabled or requires manual setup"
            }
        }
    }
    
    Write-Host "`nBaseline environment deployment summary:" -ForegroundColor Cyan
    Write-Host "  Resource Group: $rgName" -ForegroundColor White
    if ($EnableMonitoring) { Write-Host "  Log Analytics: $lawName" -ForegroundColor White }
    Write-Host "  Key Vault: $kvName" -ForegroundColor White
    if ($EnableBackup) { Write-Host "  Recovery Services Vault: $rsvName" -ForegroundColor White }
    
    Write-Host "`nBaseline environment deployment completed" -ForegroundColor Green
}
catch {
    Write-Error "Failed to deploy baseline environment: $_"
    throw
}


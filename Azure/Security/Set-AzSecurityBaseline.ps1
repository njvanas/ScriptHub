<#
.SYNOPSIS
    Applies security baseline configurations to Azure subscriptions and resources.

.DESCRIPTION
    Implements comprehensive security baselines including:
    - Enables Defender for Cloud
    - Configures diagnostic settings
    - Applies security policies
    - Hardens storage accounts
    - Configures Key Vault security
    - Sets up network security

.PARAMETER SubscriptionId
    Subscription ID to apply baseline to. Uses current context if not specified.

.PARAMETER Scope
    Scope for baseline: Subscription, ResourceGroup, or All. Default: Subscription.

.PARAMETER ResourceGroupName
    Optional resource group name if Scope is ResourceGroup.

.PARAMETER EnableDefender
    Enable Microsoft Defender for Cloud. Default: $true.

.PARAMETER ConfigureDiagnostics
    Configure diagnostic settings for all resources. Default: $true.

.PARAMETER LogAnalyticsWorkspaceId
    Log Analytics workspace ID for diagnostic settings.

.PARAMETER ApplyStorageBaseline
    Apply storage account security baseline. Default: $true.

.PARAMETER ApplyKeyVaultBaseline
    Apply Key Vault security baseline. Default: $true.

.PARAMETER WhatIf
    Preview changes without applying them.

.EXAMPLE
    Set-AzSecurityBaseline -LogAnalyticsWorkspaceId "/subscriptions/.../workspaces/la-workspace" -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Subscription', 'ResourceGroup', 'All')]
    [string]$Scope = 'Subscription',
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [bool]$EnableDefender = $true,
    
    [Parameter(Mandatory = $false)]
    [bool]$ConfigureDiagnostics = $true,
    
    [Parameter(Mandatory = $false)]
    [string]$LogAnalyticsWorkspaceId,
    
    [Parameter(Mandatory = $false)]
    [bool]$ApplyStorageBaseline = $true,
    
    [Parameter(Mandatory = $false)]
    [bool]$ApplyKeyVaultBaseline = $true,
    
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
    
    $context = Get-AzContext
    $subscriptionId = $context.Subscription.Id
    
    Write-Host "Applying security baseline to subscription: $($context.Subscription.Name)" -ForegroundColor Cyan
    
    # Enable Defender for Cloud
    if ($EnableDefender) {
        Write-Verbose "Enabling Microsoft Defender for Cloud..."
        if ($PSCmdlet.ShouldProcess("Subscription", "Enable Defender for Cloud")) {
            if (-not $WhatIf) {
                try {
                    $defenderSettings = Get-AzSecurityPricing -Name "VirtualMachines" -ErrorAction SilentlyContinue
                    if (-not $defenderSettings) {
                        Set-AzSecurityPricing -Name "VirtualMachines" -PricingTier "Standard" -ErrorAction SilentlyContinue
                        Set-AzSecurityPricing -Name "SqlServers" -PricingTier "Standard" -ErrorAction SilentlyContinue
                        Set-AzSecurityPricing -Name "AppServices" -PricingTier "Standard" -ErrorAction SilentlyContinue
                        Set-AzSecurityPricing -Name "StorageAccounts" -PricingTier "Standard" -ErrorAction SilentlyContinue
                        Set-AzSecurityPricing -Name "KeyVaults" -PricingTier "Standard" -ErrorAction SilentlyContinue
                        Write-Host "Defender for Cloud enabled" -ForegroundColor Green
                    }
                }
                catch {
                    Write-Warning "Failed to enable Defender for Cloud: $_"
                }
            }
            else {
                Write-Host "Would enable Defender for Cloud" -ForegroundColor Yellow
            }
        }
    }
    
    # Configure diagnostic settings
    if ($ConfigureDiagnostics -and $LogAnalyticsWorkspaceId) {
        Write-Verbose "Configuring diagnostic settings..."
        $resourceGroups = if ($Scope -eq 'ResourceGroup' -and $ResourceGroupName) {
            Get-AzResourceGroup -Name $ResourceGroupName
        }
        else {
            Get-AzResourceGroup
        }
        
        foreach ($rg in $resourceGroups) {
            $resources = Get-AzResource -ResourceGroupName $rg.ResourceGroupName | Where-Object {
                $_.ResourceType -match 'Microsoft\.(Compute|Storage|Network|KeyVault|Sql|Web)'
            }
            
            foreach ($resource in $resources) {
                if ($PSCmdlet.ShouldProcess($resource.Name, "Enable diagnostic settings")) {
                    if (-not $WhatIf) {
                        try {
                            . "$PSScriptRoot\..\Monitoring\Enable-AzDiagnosticSettings.ps1" `
                                -ResourceId $resource.ResourceId `
                                -LogAnalyticsWorkspaceId $LogAnalyticsWorkspaceId `
                                -ErrorAction SilentlyContinue
                        }
                        catch {
                            Write-Verbose "Failed to enable diagnostics for $($resource.Name): $_"
                        }
                    }
                }
            }
        }
        Write-Host "Diagnostic settings configured" -ForegroundColor Green
    }
    
    # Apply storage baseline
    if ($ApplyStorageBaseline) {
        Write-Verbose "Applying storage account security baseline..."
        $resourceGroups = if ($Scope -eq 'ResourceGroup' -and $ResourceGroupName) {
            Get-AzResourceGroup -Name $ResourceGroupName
        }
        else {
            Get-AzResourceGroup
        }
        
        foreach ($rg in $resourceGroups) {
            if ($PSCmdlet.ShouldProcess($rg.ResourceGroupName, "Apply storage security baseline")) {
                if (-not $WhatIf) {
                    try {
                        . "$PSScriptRoot\Set-AzStorageAccountSecurity.ps1" `
                            -ResourceGroupName $rg.ResourceGroupName `
                            -ErrorAction SilentlyContinue
                    }
                    catch {
                        Write-Verbose "Failed to apply storage baseline for $($rg.ResourceGroupName): $_"
                    }
                }
            }
        }
        Write-Host "Storage security baseline applied" -ForegroundColor Green
    }
    
    # Apply Key Vault baseline
    if ($ApplyKeyVaultBaseline) {
        Write-Verbose "Applying Key Vault security baseline..."
        $keyVaults = Get-AzKeyVault
        
        foreach ($kv in $keyVaults) {
            if ($PSCmdlet.ShouldProcess($kv.VaultName, "Apply Key Vault security baseline")) {
                if (-not $WhatIf) {
                    try {
                        # Enable soft delete and purge protection
                        if (-not $kv.EnableSoftDelete) {
                            Update-AzKeyVault -VaultName $kv.VaultName -ResourceGroupName $kv.ResourceGroupName -EnableSoftDelete -ErrorAction SilentlyContinue
                        }
                        
                        if (-not $kv.EnablePurgeProtection) {
                            Update-AzKeyVault -VaultName $kv.VaultName -ResourceGroupName $kv.ResourceGroupName -EnablePurgeProtection -ErrorAction SilentlyContinue
                        }
                        
                        # Set network rules to deny by default if not configured
                        if ($kv.NetworkAcls.DefaultAction -eq 'Allow') {
                            Update-AzKeyVaultNetworkRuleSet -VaultName $kv.VaultName -ResourceGroupName $kv.ResourceGroupName -DefaultAction Deny -ErrorAction SilentlyContinue
                        }
                    }
                    catch {
                        Write-Verbose "Failed to apply Key Vault baseline for $($kv.VaultName): $_"
                    }
                }
            }
        }
        Write-Host "Key Vault security baseline applied" -ForegroundColor Green
    }
    
    Write-Host "Security baseline application completed" -ForegroundColor Green
}
catch {
    Write-Error "Failed to apply security baseline: $_"
    throw
}


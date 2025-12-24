<#
.SYNOPSIS
    Hardens Azure Storage Account security settings.

.DESCRIPTION
    Applies security best practices to storage accounts:
    - Enables HTTPS only
    - Sets minimum TLS version
    - Disables public blob access
    - Configures network rules

.PARAMETER ResourceGroupName
    Resource group name containing storage accounts.

.PARAMETER StorageAccountName
    Specific storage account name. If not specified, processes all in resource group.

.PARAMETER MinimumTlsVersion
    Minimum TLS version: TLS1_0, TLS1_1, TLS1_2. Default: TLS1_2.

.PARAMETER AllowBlobPublicAccess
    Allow public access to blobs. Default: $false.

.PARAMETER NetworkRuleDefaultAction
    Default network rule action: Allow or Deny. Default: Deny.

.PARAMETER WhatIf
    Preview changes without applying them.

.EXAMPLE
    Set-AzStorageAccountSecurity -ResourceGroupName "Storage-RG" -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$StorageAccountName,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('TLS1_0', 'TLS1_1', 'TLS1_2')]
    [string]$MinimumTlsVersion = 'TLS1_2',
    
    [Parameter(Mandatory = $false)]
    [bool]$AllowBlobPublicAccess = $false,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Allow', 'Deny')]
    [string]$NetworkRuleDefaultAction = 'Deny',
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

. "$PSScriptRoot\..\..\Utilities\Common-Functions\Test-AzConnection.ps1"
Test-AzConnection -ConnectIfNeeded $true | Out-Null

$ErrorActionPreference = 'Stop'

try {
    $params = @{ ResourceGroupName = $ResourceGroupName }
    if ($StorageAccountName) { $params.Name = $StorageAccountName }
    
    $storageAccounts = Get-AzStorageAccount @params
    
    foreach ($sa in $storageAccounts) {
        Write-Verbose "Processing storage account: $($sa.StorageAccountName)"
        
        $changes = @()
        
        # Check and update HTTPS only
        if (-not $sa.EnableHttpsTrafficOnly) {
            $changes += "Enable HTTPS only traffic"
        }
        
        # Check and update minimum TLS version
        if ($sa.MinimumTlsVersion -ne $MinimumTlsVersion) {
            $changes += "Set minimum TLS version to $MinimumTlsVersion"
        }
        
        # Check and update blob public access
        $blobService = Get-AzStorageBlobServiceProperty -ResourceGroupName $sa.ResourceGroupName -StorageAccountName $sa.StorageAccountName -ErrorAction SilentlyContinue
        if ($blobService -and $blobService.AllowBlobPublicAccess -ne $AllowBlobPublicAccess) {
            $changes += "Set blob public access to $AllowBlobPublicAccess"
        }
        
        # Check network rules
        if ($sa.NetworkRuleSet.DefaultAction -ne $NetworkRuleDefaultAction) {
            $changes += "Set network rule default action to $NetworkRuleDefaultAction"
        }
        
        if ($changes.Count -gt 0) {
            if ($PSCmdlet.ShouldProcess($sa.StorageAccountName, "Apply security hardening")) {
                if (-not $WhatIf) {
                    # Update storage account properties
                    $updateParams = @{
                        ResourceGroupName = $sa.ResourceGroupName
                        Name = $sa.StorageAccountName
                        EnableHttpsTrafficOnly = $true
                        MinimumTlsVersion = $MinimumTlsVersion
                    }
                    
                    Set-AzStorageAccount @updateParams -ErrorAction Stop
                    
                    # Update blob service properties
                    if ($blobService) {
                        Update-AzStorageBlobServiceProperty -ResourceGroupName $sa.ResourceGroupName -StorageAccountName $sa.StorageAccountName -AllowBlobPublicAccess $AllowBlobPublicAccess -ErrorAction SilentlyContinue
                    }
                    
                    # Update network rules if needed
                    if ($sa.NetworkRuleSet.DefaultAction -ne $NetworkRuleDefaultAction) {
                        $networkRules = $sa.NetworkRuleSet
                        $networkRules.DefaultAction = $NetworkRuleDefaultAction
                        Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $sa.ResourceGroupName -Name $sa.StorageAccountName -DefaultAction $NetworkRuleDefaultAction -ErrorAction SilentlyContinue
                    }
                    
                    Write-Host "Applied security hardening to: $($sa.StorageAccountName)" -ForegroundColor Green
                    $changes | ForEach-Object { Write-Verbose "  - $_" }
                }
                else {
                    Write-Host "Would apply security hardening to: $($sa.StorageAccountName)" -ForegroundColor Yellow
                    $changes | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
                }
            }
        }
        else {
            Write-Verbose "Storage account $($sa.StorageAccountName) already meets security requirements"
        }
    }
}
catch {
    Write-Error "Failed to harden storage account security: $_"
    throw
}


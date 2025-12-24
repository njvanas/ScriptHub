<#
.SYNOPSIS
    Gets comprehensive inventory of Azure Key Vaults with security analysis.

.DESCRIPTION
    Retrieves Key Vault details including access policies, network rules, and security settings.

.PARAMETER SubscriptionId
    Subscription ID to query. Uses current context if not specified.

.PARAMETER ResourceGroupName
    Optional resource group filter.

.PARAMETER ExportToCsv
    Path to export results as CSV.

.EXAMPLE
    Get-AzKeyVaultInventory -ExportToCsv "C:\Reports\KeyVaultInventory.csv"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
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
    
    Write-Verbose "Retrieving Key Vaults..."
    $keyVaults = Get-AzKeyVault @params
    
    $inventory = foreach ($kv in $keyVaults) {
        $accessPolicies = $kv.AccessPolicies
        $networkAcls = $kv.NetworkAcls
        
        $issues = @()
        $severity = 'Info'
        
        # Check network access
        if ($networkAcls.DefaultAction -eq 'Allow') {
            $issues += "Network access allows all networks"
            $severity = 'High'
        }
        
        # Check for public access
        if (-not $networkAcls.IpRules -and -not $networkAcls.VirtualNetworkResourceIds -and $networkAcls.DefaultAction -eq 'Allow') {
            $issues += "No network restrictions configured"
            $severity = 'Critical'
        }
        
        # Check soft delete
        if (-not $kv.EnableSoftDelete) {
            $issues += "Soft delete not enabled"
            $severity = 'Medium'
        }
        
        # Check purge protection
        if (-not $kv.EnablePurgeProtection) {
            $issues += "Purge protection not enabled"
            $severity = 'Medium'
        }
        
        [PSCustomObject]@{
            Name = $kv.VaultName
            ResourceGroupName = $kv.ResourceGroupName
            Location = $kv.Location
            SubscriptionId = (Get-AzContext).Subscription.Id
            EnabledForDeployment = $kv.EnabledForDeployment
            EnabledForTemplateDeployment = $kv.EnabledForTemplateDeployment
            EnabledForDiskEncryption = $kv.EnabledForDiskEncryption
            EnableSoftDelete = $kv.EnableSoftDelete
            EnablePurgeProtection = $kv.EnablePurgeProtection
            NetworkAclDefaultAction = $networkAcls.DefaultAction
            NetworkAclBypass = $networkAcls.Bypass
            AccessPolicyCount = $accessPolicies.Count
            Tags = ($kv.Tags.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join '; '
            Issues = ($issues -join '; ')
            Severity = $severity
            ResourceId = $kv.ResourceId
        }
    }
    
    Write-Verbose "Found $($inventory.Count) Key Vaults"
    
    if ($ExportToCsv) {
        $inventory | Export-Csv -Path $ExportToCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Key Vault inventory exported to: $ExportToCsv" -ForegroundColor Green
    }
    
    return $inventory
}
catch {
    Write-Error "Failed to retrieve Key Vault inventory: $_"
    throw
}


<#
.SYNOPSIS
    Gets comprehensive inventory of Azure Storage Accounts.

.DESCRIPTION
    Retrieves storage account details including configuration, access settings, encryption,
    and security settings.

.PARAMETER SubscriptionId
    Subscription ID to query. Uses current context if not specified.

.PARAMETER ResourceGroupName
    Optional resource group filter.

.PARAMETER ExportToCsv
    Path to export results as CSV.

.EXAMPLE
    Get-AzStorageAccountInventory -ExportToCsv "C:\Reports\StorageInventory.csv"
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
    
    Write-Verbose "Retrieving storage accounts..."
    $storageAccounts = Get-AzStorageAccount @params
    
    $inventory = foreach ($sa in $storageAccounts) {
        $context = $sa.Context
        $blobService = Get-AzStorageBlobServiceProperty -ResourceGroupName $sa.ResourceGroupName -StorageAccountName $sa.StorageAccountName -ErrorAction SilentlyContinue
        
        [PSCustomObject]@{
            Name = $sa.StorageAccountName
            ResourceGroupName = $sa.ResourceGroupName
            Location = $sa.Location
            SubscriptionId = (Get-AzContext).Subscription.Id
            SkuName = $sa.Sku.Name
            Kind = $sa.Kind
            AccessTier = $sa.AccessTier
            EnableHttpsTrafficOnly = $sa.EnableHttpsTrafficOnly
            MinimumTlsVersion = $sa.MinimumTlsVersion
            AllowBlobPublicAccess = $blobService.AllowBlobPublicAccess
            SupportsHttpsTrafficOnly = $sa.EnableHttpsTrafficOnly
            EncryptionKeySource = $sa.Encryption.KeySource
            EncryptionServicesBlob = $sa.Encryption.Services.Blob.Enabled
            EncryptionServicesFile = $sa.Encryption.Services.File.Enabled
            NetworkRuleSetDefaultAction = $sa.NetworkRuleSet.DefaultAction
            NetworkRuleSetBypass = $sa.NetworkRuleSet.Bypass
            Tags = ($sa.Tags.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join '; '
            CreationTime = $sa.CreationTime
            ResourceId = $sa.Id
        }
    }
    
    Write-Verbose "Found $($inventory.Count) storage accounts"
    
    if ($ExportToCsv) {
        $inventory | Export-Csv -Path $ExportToCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Storage account inventory exported to: $ExportToCsv" -ForegroundColor Green
    }
    
    return $inventory
}
catch {
    Write-Error "Failed to retrieve storage account inventory: $_"
    throw
}


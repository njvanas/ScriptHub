<#
.SYNOPSIS
    Gets comprehensive inventory of Azure resources.

.DESCRIPTION
    Retrieves all resources across subscriptions with key metadata including tags,
    location, resource group, and resource type.

.PARAMETER SubscriptionId
    Specific subscription ID to inventory. If not specified, uses current context.

.PARAMETER ResourceGroupName
    Optional resource group name to filter results.

.PARAMETER ResourceType
    Optional resource type filter (e.g., Microsoft.Compute/virtualMachines).

.PARAMETER ExportToCsv
    Path to export results as CSV.

.EXAMPLE
    Get-AzResourceInventory -ExportToCsv "C:\Reports\AzureInventory.csv"
    Get-AzResourceInventory -ResourceType "Microsoft.Compute/virtualMachines"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceType,
    
    [Parameter(Mandatory = $false)]
    [string]$ExportToCsv
)

. "$PSScriptRoot\Test-AzConnection.ps1"
Test-AzConnection -ConnectIfNeeded $true | Out-Null

$ErrorActionPreference = 'Stop'

try {
    if ($SubscriptionId) {
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    }
    
    $params = @{}
    if ($ResourceGroupName) { $params.ResourceGroupName = $ResourceGroupName }
    if ($ResourceType) { $params.ResourceType = $ResourceType }
    
    Write-Verbose "Retrieving Azure resources..."
    $resources = Get-AzResource @params | Select-Object -Property @(
        'Name',
        'ResourceType',
        'ResourceGroupName',
        'Location',
        'SubscriptionId',
        @{Name='Tags'; Expression={($_.Tags.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join '; '}},
        'Id',
        'Sku',
        'Kind'
    )
    
    Write-Verbose "Found $($resources.Count) resources"
    
    if ($ExportToCsv) {
        $resources | Export-Csv -Path $ExportToCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Inventory exported to: $ExportToCsv" -ForegroundColor Green
    }
    
    return $resources
}
catch {
    Write-Error "Failed to retrieve resource inventory: $_"
    throw
}


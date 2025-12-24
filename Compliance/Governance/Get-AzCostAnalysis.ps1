<#
.SYNOPSIS
    Analyzes Azure costs by resource, resource group, and tags.

.DESCRIPTION
    Retrieves cost data using Azure Consumption API to identify spending patterns
    and opportunities for optimization.

.PARAMETER SubscriptionId
    Subscription ID to analyze. Uses current context if not specified.

.PARAMETER StartDate
    Start date for cost analysis. Default: 30 days ago.

.PARAMETER EndDate
    End date for cost analysis. Default: today.

.PARAMETER GroupBy
    Group results by: ResourceGroup, ResourceType, Tag, or Resource.

.PARAMETER ExportToCsv
    Path to export results as CSV.

.EXAMPLE
    Get-AzCostAnalysis -GroupBy ResourceGroup -ExportToCsv "C:\Reports\CostAnalysis.csv"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [DateTime]$StartDate = (Get-Date).AddDays(-30),
    
    [Parameter(Mandatory = $false)]
    [DateTime]$EndDate = (Get-Date),
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('ResourceGroup', 'ResourceType', 'Tag', 'Resource')]
    [string]$GroupBy = 'ResourceGroup',
    
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
    
    $context = Get-AzContext
    $subscriptionId = $context.Subscription.Id
    
    Write-Verbose "Retrieving cost data for subscription: $subscriptionId"
    Write-Verbose "Date range: $StartDate to $EndDate"
    
    # Get usage aggregates
    $usage = Get-AzConsumptionUsageDetail -StartDate $StartDate -EndDate $EndDate -ErrorAction Stop
    
    $costAnalysis = $usage | Group-Object -Property $GroupBy | ForEach-Object {
        $group = $_.Name
        $items = $_.Group
        $totalCost = ($items | Measure-Object -Property PreTaxCost -Sum).Sum
        $resourceCount = $items.Count
        
        [PSCustomObject]@{
            Group = $group
            TotalCost = [math]::Round($totalCost, 2)
            ResourceCount = $resourceCount
            AverageCost = [math]::Round($totalCost / $resourceCount, 2)
            Currency = $items[0].Currency
        }
    } | Sort-Object -Property TotalCost -Descending
    
    Write-Verbose "Analyzed costs for $($costAnalysis.Count) groups"
    
    if ($ExportToCsv) {
        $costAnalysis | Export-Csv -Path $ExportToCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Cost analysis exported to: $ExportToCsv" -ForegroundColor Green
    }
    
    return $costAnalysis
}
catch {
    Write-Error "Failed to retrieve cost analysis: $_"
    throw
}


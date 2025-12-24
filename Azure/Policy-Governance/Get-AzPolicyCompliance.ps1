<#
.SYNOPSIS
    Gets Azure Policy compliance status across subscriptions.

.DESCRIPTION
    Retrieves policy assignments and their compliance states for resources.

.PARAMETER SubscriptionId
    Subscription ID to analyze. Uses current context if not specified.

.PARAMETER PolicyAssignmentId
    Optional specific policy assignment ID.

.PARAMETER ExportToCsv
    Path to export results as CSV.

.EXAMPLE
    Get-AzPolicyCompliance -ExportToCsv "C:\Reports\PolicyCompliance.csv"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$PolicyAssignmentId,
    
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
    
    Write-Verbose "Retrieving policy assignments for subscription: $subscriptionId"
    
    $assignments = if ($PolicyAssignmentId) {
        Get-AzPolicyAssignment -Id $PolicyAssignmentId -ErrorAction Stop
    }
    else {
        Get-AzPolicyAssignment -Scope "/subscriptions/$subscriptionId" -ErrorAction Stop
    }
    
    $compliance = foreach ($assignment in $assignments) {
        try {
            $states = Get-AzPolicyState -PolicyAssignmentName $assignment.Name -ErrorAction SilentlyContinue
            
            $compliantCount = ($states | Where-Object { $_.ComplianceState -eq 'Compliant' }).Count
            $nonCompliantCount = ($states | Where-Object { $_.ComplianceState -eq 'NonCompliant' }).Count
            $totalCount = $states.Count
            
            $compliancePercentage = if ($totalCount -gt 0) {
                [math]::Round(($compliantCount / $totalCount) * 100, 2)
            }
            else { 0 }
            
            [PSCustomObject]@{
                PolicyAssignmentName = $assignment.Name
                PolicyAssignmentId = $assignment.ResourceId
                PolicyDefinitionId = $assignment.Properties.PolicyDefinitionId
                Scope = $assignment.Properties.Scope
                ComplianceState = if ($nonCompliantCount -gt 0) { 'NonCompliant' } else { 'Compliant' }
                CompliantResources = $compliantCount
                NonCompliantResources = $nonCompliantCount
                TotalResources = $totalCount
                CompliancePercentage = $compliancePercentage
            }
        }
        catch {
            Write-Warning "Failed to get compliance state for assignment $($assignment.Name): $_"
        }
    }
    
    Write-Verbose "Analyzed $($compliance.Count) policy assignments"
    
    if ($ExportToCsv) {
        $compliance | Export-Csv -Path $ExportToCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Policy compliance report exported to: $ExportToCsv" -ForegroundColor Green
    }
    
    return $compliance
}
catch {
    Write-Error "Failed to retrieve policy compliance: $_"
    throw
}


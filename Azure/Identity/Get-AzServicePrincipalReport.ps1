<#
.SYNOPSIS
    Generates comprehensive report of Azure service principals and their permissions.

.DESCRIPTION
    Analyzes service principals, their role assignments, and identifies potential security issues
    such as excessive permissions or unused service principals.

.PARAMETER SubscriptionId
    Subscription ID to analyze. Uses current context if not specified.

.PARAMETER ExportToCsv
    Path to export results as CSV.

.EXAMPLE
    Get-AzServicePrincipalReport -ExportToCsv "C:\Reports\ServicePrincipalReport.csv"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
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
    $scope = "/subscriptions/$subscriptionId"
    
    Write-Verbose "Retrieving service principals and role assignments..."
    
    # Get all role assignments
    $roleAssignments = Get-AzRoleAssignment -Scope $scope
    
    # Filter for service principals
    $spAssignments = $roleAssignments | Where-Object { $_.ObjectType -eq 'ServicePrincipal' }
    
    # Get unique service principals
    $servicePrincipals = $spAssignments | Select-Object -Unique -Property ObjectId, DisplayName, SignInName
    
    $report = foreach ($sp in $servicePrincipals) {
        $spRoles = $spAssignments | Where-Object { $_.ObjectId -eq $sp.ObjectId }
        $highPrivilegeRoles = $spRoles | Where-Object { $_.RoleDefinitionName -in @('Owner', 'User Access Administrator', 'Contributor') }
        
        $issues = @()
        $severity = 'Info'
        
        if ($highPrivilegeRoles.Count -gt 0) {
            $issues += "Has high-privilege roles: $($highPrivilegeRoles.RoleDefinitionName -join ', ')"
            $severity = 'High'
        }
        
        if ($spRoles.Count -gt 5) {
            $issues += "Has $($spRoles.Count) role assignments (consider reviewing)"
            if ($severity -eq 'Info') { $severity = 'Medium' }
        }
        
        # Check for unused (no recent activity - would require additional API calls)
        $lastActivity = "Unknown"  # Would need to query sign-in logs
        
        [PSCustomObject]@{
            ServicePrincipalName = $sp.DisplayName
            ServicePrincipalId = $sp.ObjectId
            SignInName = $sp.SignInName
            RoleCount = $spRoles.Count
            Roles = ($spRoles.RoleDefinitionName -join '; ')
            HighPrivilegeRoles = ($highPrivilegeRoles.RoleDefinitionName -join '; ')
            Issues = ($issues -join '; ')
            Severity = $severity
            LastActivity = $lastActivity
        }
    }
    
    Write-Verbose "Found $($report.Count) service principals"
    
    if ($ExportToCsv) {
        $report | Export-Csv -Path $ExportToCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Service principal report exported to: $ExportToCsv" -ForegroundColor Green
    }
    
    return $report
}
catch {
    Write-Error "Failed to generate service principal report: $_"
    throw
}


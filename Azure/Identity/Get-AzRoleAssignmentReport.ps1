<#
.SYNOPSIS
    Generates comprehensive RBAC role assignment report.

.DESCRIPTION
    Retrieves all role assignments with details about principals, roles, and scope.
    Identifies potential security issues like excessive permissions.

.PARAMETER SubscriptionId
    Subscription ID to analyze. Uses current context if not specified.

.PARAMETER Scope
    Optional scope filter (subscription, resource group, or resource).

.PARAMETER ExportToCsv
    Path to export results as CSV.

.EXAMPLE
    Get-AzRoleAssignmentReport -ExportToCsv "C:\Reports\RBACReport.csv"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$Scope,
    
    [Parameter(Mandatory = $false)]
    [string]$ExportToCsv
)

. "$PSScriptRoot\..\..\Utilities\Common-Functions\Test-AzConnection.ps1"
Test-AzConnection -ConnectIfNeeded $true | Out-Null

$ErrorActionPreference = 'Stop'

try {
    if ($SubscriptionId) {
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
        $scope = "/subscriptions/$SubscriptionId"
    }
    elseif ($Scope) {
        $scope = $Scope
    }
    else {
        $context = Get-AzContext
        $scope = "/subscriptions/$($context.Subscription.Id)"
    }
    
    Write-Verbose "Retrieving role assignments for scope: $scope"
    $roleAssignments = Get-AzRoleAssignment -Scope $scope -ErrorAction Stop
    
    $report = foreach ($assignment in $roleAssignments) {
        $principalType = $assignment.ObjectType
        $roleName = $assignment.RoleDefinitionName
        $scopeLevel = if ($assignment.Scope -match '/subscriptions/') {
            if ($assignment.Scope -match '/resourceGroups/') {
                if ($assignment.Scope -match '/providers/') { 'Resource' } else { 'ResourceGroup' }
            }
            else { 'Subscription' }
        }
        else { 'ManagementGroup' }
        
        $issues = @()
        $severity = 'Info'
        
        # Check for high-privilege roles
        $highPrivilegeRoles = @('Owner', 'User Access Administrator', 'Contributor')
        if ($highPrivilegeRoles -contains $roleName) {
            $issues += "High-privilege role"
            $severity = 'High'
        }
        
        # Check for service principals with Owner/Contributor
        if ($principalType -eq 'ServicePrincipal' -and ($roleName -eq 'Owner' -or $roleName -eq 'Contributor')) {
            $issues += "Service principal with high privileges"
            $severity = 'High'
        }
        
        [PSCustomObject]@{
            PrincipalName = $assignment.DisplayName
            PrincipalType = $principalType
            PrincipalId = $assignment.ObjectId
            RoleDefinitionName = $roleName
            RoleDefinitionId = $assignment.RoleDefinitionId
            Scope = $assignment.Scope
            ScopeLevel = $scopeLevel
            AssignmentId = $assignment.RoleAssignmentId
            Issues = ($issues -join '; ')
            Severity = $severity
        }
    }
    
    Write-Verbose "Found $($report.Count) role assignments"
    
    if ($ExportToCsv) {
        $report | Export-Csv -Path $ExportToCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Role assignment report exported to: $ExportToCsv" -ForegroundColor Green
    }
    
    return $report
}
catch {
    Write-Error "Failed to retrieve role assignments: $_"
    throw
}


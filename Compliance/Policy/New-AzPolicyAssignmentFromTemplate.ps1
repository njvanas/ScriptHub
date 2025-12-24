<#
.SYNOPSIS
    Creates Azure Policy assignments from JSON templates.

.DESCRIPTION
    Deploys Azure Policy assignments from template files with parameter substitution.
    Supports both built-in and custom policy definitions.

.PARAMETER PolicyTemplatePath
    Path to JSON policy assignment template file.

.PARAMETER Scope
    Scope for policy assignment (subscription, resource group, or management group).

.PARAMETER Parameters
    Hashtable of parameters to substitute in the template.

.PARAMETER WhatIf
    Preview policy assignment without creating it.

.EXAMPLE
    New-AzPolicyAssignmentFromTemplate -PolicyTemplatePath ".\templates\require-tags.json" -Scope "/subscriptions/12345678-1234-1234-1234-123456789012"
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$PolicyTemplatePath,
    
    [Parameter(Mandatory = $true)]
    [string]$Scope,
    
    [Parameter(Mandatory = $false)]
    [hashtable]$Parameters = @{},
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

. "$PSScriptRoot\..\..\Utilities\Common-Functions\Test-AzConnection.ps1"
Test-AzConnection -ConnectIfNeeded $true | Out-Null

$ErrorActionPreference = 'Stop'

try {
    if (-not (Test-Path $PolicyTemplatePath)) {
        throw "Policy template file not found: $PolicyTemplatePath"
    }
    
    $templateContent = Get-Content -Path $PolicyTemplatePath -Raw | ConvertFrom-Json
    
    # Substitute parameters
    $templateJson = $templateContent | ConvertTo-Json -Depth 10
    foreach ($key in $Parameters.Keys) {
        $templateJson = $templateJson -replace "\{$key\}", $Parameters[$key]
    }
    
    $template = $templateJson | ConvertFrom-Json
    
    $assignmentName = $template.name
    $policyDefinitionId = $template.properties.policyDefinitionId
    $displayName = $template.properties.displayName
    $description = $template.properties.description
    $parameters = $template.properties.parameters
    
    Write-Verbose "Creating policy assignment: $assignmentName"
    Write-Verbose "Policy definition: $policyDefinitionId"
    Write-Verbose "Scope: $Scope"
    
    if ($PSCmdlet.ShouldProcess($assignmentName, "Create policy assignment")) {
        if (-not $WhatIf) {
            $assignmentParams = @{
                Name = $assignmentName
                Scope = $Scope
                PolicyDefinition = $policyDefinitionId
                DisplayName = $displayName
                Description = $description
            }
            
            if ($parameters) {
                $assignmentParams.PolicyParameter = $parameters
            }
            
            New-AzPolicyAssignment @assignmentParams -ErrorAction Stop
            Write-Host "Policy assignment created: $assignmentName" -ForegroundColor Green
        }
        else {
            Write-Host "Would create policy assignment: $assignmentName" -ForegroundColor Yellow
            Write-Host "  Scope: $Scope" -ForegroundColor Yellow
            Write-Host "  Policy: $policyDefinitionId" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Error "Failed to create policy assignment: $_"
    throw
}


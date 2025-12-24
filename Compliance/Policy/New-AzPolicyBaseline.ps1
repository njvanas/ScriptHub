<#
.SYNOPSIS
    Creates baseline Azure Policy assignments for governance and compliance.

.DESCRIPTION
    Deploys a comprehensive set of Azure Policy assignments including:
    - Required tags
    - Allowed locations
    - Allowed resource types
    - Storage account security
    - Network security
    - Compliance policies

.PARAMETER SubscriptionId
    Subscription ID to apply policies to. Uses current context if not specified.

.PARAMETER PolicySet
    Policy set: Basic, Security, Compliance, or Full. Default: Basic.

.PARAMETER AllowedLocations
    Array of allowed Azure regions. Default: common regions.

.PARAMETER RequiredTags
    Array of required tag names. Default: Environment, CostCenter, Owner.

.PARAMETER WhatIf
    Preview changes without applying them.

.EXAMPLE
    New-AzPolicyBaseline -PolicySet Security -AllowedLocations @("East US", "West US") -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Basic', 'Security', 'Compliance', 'Full')]
    [string]$PolicySet = 'Basic',
    
    [Parameter(Mandatory = $false)]
    [string[]]$AllowedLocations = @("East US", "West US", "West Europe", "North Europe"),
    
    [Parameter(Mandatory = $false)]
    [string[]]$RequiredTags = @("Environment", "CostCenter", "Owner"),
    
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
    $scope = "/subscriptions/$subscriptionId"
    
    Write-Host "Creating policy baseline ($PolicySet) for subscription: $($context.Subscription.Name)" -ForegroundColor Cyan
    
    $policiesCreated = @()
    
    # Basic policies
    if ($PolicySet -in @('Basic', 'Full')) {
        Write-Verbose "Applying basic policies..."
        
        # Required tags
        foreach ($tag in $RequiredTags) {
            $policyName = "RequireTag-$tag"
            $policyDefinitionId = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
            
            if ($PSCmdlet.ShouldProcess($policyName, "Create policy assignment")) {
                if (-not $WhatIf) {
                    try {
                        $policyParams = @{
                            "tagName" = @{ value = $tag }
                        }
                        
                        $assignment = New-AzPolicyAssignment -Name $policyName -Scope $scope -PolicyDefinition $policyDefinitionId -PolicyParameterObject $policyParams -ErrorAction SilentlyContinue
                        if ($assignment) {
                            $policiesCreated += $policyName
                            Write-Verbose "Created policy: $policyName"
                        }
                    }
                    catch {
                        Write-Verbose "Failed to create policy $policyName : $_"
                    }
                }
                else {
                    Write-Host "Would create policy: $policyName (Require tag: $tag)" -ForegroundColor Yellow
                }
            }
        }
        
        # Allowed locations
        $policyName = "AllowedLocations"
        $policyDefinitionId = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
        
        if ($PSCmdlet.ShouldProcess($policyName, "Create policy assignment")) {
            if (-not $WhatIf) {
                try {
                    $policyParams = @{
                        "listOfAllowedLocations" = @{ value = $AllowedLocations }
                    }
                    
                    $assignment = New-AzPolicyAssignment -Name $policyName -Scope $scope -PolicyDefinition $policyDefinitionId -PolicyParameterObject $policyParams -ErrorAction SilentlyContinue
                    if ($assignment) {
                        $policiesCreated += $policyName
                        Write-Verbose "Created policy: $policyName"
                    }
                }
                catch {
                    Write-Verbose "Failed to create policy $policyName : $_"
                }
            }
            else {
                Write-Host "Would create policy: $policyName (Allowed locations: $($AllowedLocations -join ', '))" -ForegroundColor Yellow
            }
        }
    }
    
    # Security policies
    if ($PolicySet -in @('Security', 'Full')) {
        Write-Verbose "Applying security policies..."
        
        $securityPolicies = @(
            @{ Name = "SecureTransferRequired"; Definition = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"; Description = "Require secure transfer for storage accounts" },
            @{ Name = "HTTPSOnlyWebApp"; Definition = "/providers/Microsoft.Authorization/policyDefinitions/a4af4a39-4135-47fb-b175-47fb3489753f"; Description = "Require HTTPS for web apps" },
            @{ Name = "KeyVaultSoftDelete"; Definition = "/providers/Microsoft.Authorization/policyDefinitions/0b60c0b2-2dc2-4e1c-b5c9-abbed971de53"; Description = "Enable soft delete for Key Vaults" },
            @{ Name = "VMDisksEncryption"; Definition = "/providers/Microsoft.Authorization/policyDefinitions/0961003e-5a0a-4549-abde-af6a37f2724d"; Description = "Encrypt VM disks" }
        )
        
        foreach ($policy in $securityPolicies) {
            if ($PSCmdlet.ShouldProcess($policy.Name, "Create policy assignment")) {
                if (-not $WhatIf) {
                    try {
                        $assignment = New-AzPolicyAssignment -Name $policy.Name -Scope $scope -PolicyDefinition $policy.Definition -ErrorAction SilentlyContinue
                        if ($assignment) {
                            $policiesCreated += $policy.Name
                            Write-Verbose "Created policy: $($policy.Name)"
                        }
                    }
                    catch {
                        Write-Verbose "Failed to create policy $($policy.Name) : $_"
                    }
                }
                else {
                    Write-Host "Would create policy: $($policy.Name) - $($policy.Description)" -ForegroundColor Yellow
                }
            }
        }
    }
    
    # Compliance policies
    if ($PolicySet -in @('Compliance', 'Full')) {
        Write-Verbose "Applying compliance policies..."
        
        $compliancePolicies = @(
            @{ Name = "AuditDiagnosticSettings"; Definition = "/providers/Microsoft.Authorization/policyDefinitions/7f89b1eb-2c89-4e53-9465-3c3e5f13a58d"; Description = "Audit diagnostic settings" },
            @{ Name = "AuditPublicIPAddresses"; Definition = "/providers/Microsoft.Authorization/policyDefinitions/3d319a0f-1b6f-484b-814f-5c0ae3673006"; Description = "Audit public IP addresses" }
        )
        
        foreach ($policy in $compliancePolicies) {
            if ($PSCmdlet.ShouldProcess($policy.Name, "Create policy assignment")) {
                if (-not $WhatIf) {
                    try {
                        $assignment = New-AzPolicyAssignment -Name $policy.Name -Scope $scope -PolicyDefinition $policy.Definition -ErrorAction SilentlyContinue
                        if ($assignment) {
                            $policiesCreated += $policy.Name
                            Write-Verbose "Created policy: $($policy.Name)"
                        }
                    }
                    catch {
                        Write-Verbose "Failed to create policy $($policy.Name) : $_"
                    }
                }
                else {
                    Write-Host "Would create policy: $($policy.Name) - $($policy.Description)" -ForegroundColor Yellow
                }
            }
        }
    }
    
    Write-Host "Policy baseline created: $($policiesCreated.Count) policies assigned" -ForegroundColor Green
    if ($policiesCreated.Count -gt 0) {
        Write-Host "Policies created: $($policiesCreated -join ', ')" -ForegroundColor Cyan
    }
}
catch {
    Write-Error "Failed to create policy baseline: $_"
    throw
}


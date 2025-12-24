<#
.SYNOPSIS
    Applies baseline tagging strategy to Azure resources.

.DESCRIPTION
    Implements a comprehensive tagging strategy including:
    - Environment (Prod, Dev, Test, Staging)
    - CostCenter
    - Owner
    - Project
    - Compliance tags
    - Auto-tagging based on resource properties

.PARAMETER SubscriptionId
    Subscription ID to apply tags to. Uses current context if not specified.

.PARAMETER TaggingStrategy
    Tagging strategy: Basic, Advanced, or Compliance. Default: Basic.

.PARAMETER DefaultTags
    Hashtable of default tags to apply to all resources.

.PARAMETER ResourceGroupName
    Optional resource group name to limit scope.

.PARAMETER AutoTagFromResourceGroup
    Automatically inherit tags from resource group. Default: $true.

.PARAMETER WhatIf
    Preview changes without applying them.

.EXAMPLE
    Set-AzTaggingBaseline -DefaultTags @{Environment="Prod"; CostCenter="12345"; Owner="IT Team"} -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Basic', 'Advanced', 'Compliance')]
    [string]$TaggingStrategy = 'Basic',
    
    [Parameter(Mandatory = $false)]
    [hashtable]$DefaultTags = @{},
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [bool]$AutoTagFromResourceGroup = $true,
    
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
    Write-Host "Applying tagging baseline ($TaggingStrategy) to subscription: $($context.Subscription.Name)" -ForegroundColor Cyan
    
    # Define tagging strategy
    $strategyTags = switch ($TaggingStrategy) {
        'Basic' {
            @{
                'ManagedBy' = 'ScriptHub'
                'TaggedDate' = (Get-Date -Format "yyyy-MM-dd")
            }
        }
        'Advanced' {
            @{
                'ManagedBy' = 'ScriptHub'
                'TaggedDate' = (Get-Date -Format "yyyy-MM-dd")
                'LastModified' = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                'Subscription' = $context.Subscription.Name
            }
        }
        'Compliance' {
            @{
                'ManagedBy' = 'ScriptHub'
                'TaggedDate' = (Get-Date -Format "yyyy-MM-dd")
                'ComplianceRequired' = 'Yes'
                'DataClassification' = 'Internal'
                'RetentionPeriod' = '7Years'
            }
        }
    }
    
    # Merge default tags with strategy tags
    $tagsToApply = $strategyTags.Clone()
    foreach ($key in $DefaultTags.Keys) {
        $tagsToApply[$key] = $DefaultTags[$key]
    }
    
    # Get resource groups
    $resourceGroups = if ($ResourceGroupName) {
        Get-AzResourceGroup -Name $ResourceGroupName
    }
    else {
        Get-AzResourceGroup
    }
    
    # Tag resource groups first
    foreach ($rg in $resourceGroups) {
        if ($PSCmdlet.ShouldProcess($rg.ResourceGroupName, "Apply tags to resource group")) {
            if (-not $WhatIf) {
                $existingTags = $rg.Tags
                if (-not $existingTags) { $existingTags = @{} }
                
                foreach ($key in $tagsToApply.Keys) {
                    $existingTags[$key] = $tagsToApply[$key]
                }
                
                Set-AzResourceGroup -Name $rg.ResourceGroupName -Tag $existingTags -ErrorAction SilentlyContinue
                Write-Verbose "Tagged resource group: $($rg.ResourceGroupName)"
            }
            else {
                Write-Host "Would tag resource group: $($rg.ResourceGroupName)" -ForegroundColor Yellow
            }
        }
    }
    
    # Tag resources
    foreach ($rg in $resourceGroups) {
        $resources = Get-AzResource -ResourceGroupName $rg.ResourceGroupName
        
        foreach ($resource in $resources) {
            if ($PSCmdlet.ShouldProcess($resource.Name, "Apply tags")) {
                if (-not $WhatIf) {
                    $resourceTags = $tagsToApply.Clone()
                    
                    # Inherit from resource group if enabled
                    if ($AutoTagFromResourceGroup) {
                        $rgTags = (Get-AzResourceGroup -Name $rg.ResourceGroupName).Tags
                        if ($rgTags) {
                            foreach ($key in $rgTags.Keys) {
                                if (-not $resourceTags.ContainsKey($key)) {
                                    $resourceTags[$key] = $rgTags[$key]
                                }
                            }
                        }
                    }
                    
                    # Add resource-specific tags
                    $resourceTags['ResourceType'] = $resource.ResourceType
                    $resourceTags['Location'] = $resource.Location
                    
                    # Apply tags
                    try {
                        . "$PSScriptRoot\..\..\PowerShell\Azure\Set-AzResourceTags.ps1" `
                            -ResourceId $resource.ResourceId `
                            -Tags $resourceTags `
                            -TagAction Merge `
                            -ErrorAction SilentlyContinue
                        Write-Verbose "Tagged resource: $($resource.Name)"
                    }
                    catch {
                        Write-Verbose "Failed to tag $($resource.Name): $_"
                    }
                }
                else {
                    Write-Host "Would tag resource: $($resource.Name) in $($rg.ResourceGroupName)" -ForegroundColor Yellow
                }
            }
        }
    }
    
    Write-Host "Tagging baseline applied to $($resourceGroups.Count) resource groups" -ForegroundColor Green
}
catch {
    Write-Error "Failed to apply tagging baseline: $_"
    throw
}


<#
.SYNOPSIS
    Sets tags on Azure resources with merge or replace options.

.DESCRIPTION
    Applies tags to resources with support for merging with existing tags or replacing them.
    Supports bulk tagging across resource groups or subscriptions.

.PARAMETER ResourceId
    Resource ID(s) to tag. Can accept pipeline input.

.PARAMETER Tags
    Hashtable of tags to apply.

.PARAMETER ResourceGroupName
    Optional resource group name to tag all resources in the group.

.PARAMETER TagAction
    Merge (default) or Replace existing tags.

.EXAMPLE
    Set-AzResourceTags -ResourceId "/subscriptions/.../resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm1" -Tags @{Environment="Prod"; Owner="IT Team"}
    Set-AzResourceTags -ResourceGroupName "Production-RG" -Tags @{CostCenter="12345"} -TagAction Merge
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [string[]]$ResourceId,
    
    [Parameter(Mandatory = $true)]
    [hashtable]$Tags,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Merge', 'Replace')]
    [string]$TagAction = 'Merge'
)

. "$PSScriptRoot\..\..\Utilities\Common-Functions\Test-AzConnection.ps1"
Test-AzConnection -ConnectIfNeeded $true | Out-Null

$ErrorActionPreference = 'Stop'

begin {
    $resourcesToTag = @()
}

process {
    if ($ResourceGroupName) {
        Write-Verbose "Getting resources from resource group: $ResourceGroupName"
        $resourcesToTag += Get-AzResource -ResourceGroupName $ResourceGroupName | ForEach-Object { $_.ResourceId }
    }
    
    if ($ResourceId) {
        $resourcesToTag += $ResourceId
    }
}

end {
    if ($resourcesToTag.Count -eq 0) {
        Write-Warning "No resources specified to tag"
        return
    }
    
    foreach ($resourceId in $resourcesToTag) {
        try {
            $resource = Get-AzResource -ResourceId $resourceId -ErrorAction Stop
            
            $newTags = if ($TagAction -eq 'Replace') {
                $Tags
            }
            else {
                $existingTags = $resource.Tags
                if (-not $existingTags) {
                    $existingTags = @{}
                }
                $Tags.GetEnumerator() | ForEach-Object {
                    $existingTags[$_.Key] = $_.Value
                }
                $existingTags
            }
            
            if ($PSCmdlet.ShouldProcess($resourceId, "Set tags ($TagAction)")) {
                Set-AzResource -ResourceId $resourceId -Tag $newTags -Force | Out-Null
                Write-Verbose "Tags applied to: $resourceId"
            }
        }
        catch {
            Write-Error "Failed to tag resource $resourceId : $_"
        }
    }
}


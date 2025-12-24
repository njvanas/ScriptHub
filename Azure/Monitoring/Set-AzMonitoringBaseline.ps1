<#
.SYNOPSIS
    Configures baseline monitoring and alerting for Azure resources.

.DESCRIPTION
    Sets up comprehensive monitoring including:
    - Diagnostic settings for all resources
    - Activity log alerts for critical operations
    - Metric alerts for resource health
    - Log Analytics workspace configuration
    - Action groups for notifications

.PARAMETER SubscriptionId
    Subscription ID to configure. Uses current context if not specified.

.PARAMETER LogAnalyticsWorkspaceId
    Log Analytics workspace resource ID.

.PARAMETER ActionGroupName
    Action group name for alert notifications. Will be created if it doesn't exist.

.PARAMETER EmailAddresses
    Array of email addresses for alert notifications.

.PARAMETER EnableActivityLogAlerts
    Enable activity log alerts for critical operations. Default: $true.

.PARAMETER EnableMetricAlerts
    Enable metric alerts for resource health. Default: $true.

.PARAMETER WhatIf
    Preview changes without applying them.

.EXAMPLE
    Set-AzMonitoringBaseline -LogAnalyticsWorkspaceId "/subscriptions/.../workspaces/la-workspace" -EmailAddresses @("admin@company.com") -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$LogAnalyticsWorkspaceId,
    
    [Parameter(Mandatory = $false)]
    [string]$ActionGroupName = "DefaultActionGroup",
    
    [Parameter(Mandatory = $false)]
    [string[]]$EmailAddresses = @(),
    
    [Parameter(Mandatory = $false)]
    [bool]$EnableActivityLogAlerts = $true,
    
    [Parameter(Mandatory = $false)]
    [bool]$EnableMetricAlerts = $true,
    
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
    $resourceGroupName = (Get-AzResource -ResourceId $LogAnalyticsWorkspaceId).ResourceGroupName
    
    Write-Host "Configuring monitoring baseline for subscription: $($context.Subscription.Name)" -ForegroundColor Cyan
    
    # Create or get action group
    $actionGroup = $null
    if ($EmailAddresses.Count -gt 0) {
        Write-Verbose "Creating/updating action group: $ActionGroupName"
        try {
            $actionGroup = Get-AzActionGroup -ResourceGroupName $resourceGroupName -Name $ActionGroupName -ErrorAction SilentlyContinue
            
            if (-not $actionGroup) {
                if ($PSCmdlet.ShouldProcess($ActionGroupName, "Create action group")) {
                    if (-not $WhatIf) {
                        $emailReceivers = $EmailAddresses | ForEach-Object {
                            New-AzActionGroupReceiver -Name "Email-$_" -EmailAddress $_
                        }
                        
                        $actionGroup = Set-AzActionGroup -ResourceGroupName $resourceGroupName -Name $ActionGroupName -ShortName "DefAG" -Receiver $emailReceivers -ErrorAction Stop
                        Write-Host "Action group created: $ActionGroupName" -ForegroundColor Green
                    }
                    else {
                        Write-Host "Would create action group: $ActionGroupName" -ForegroundColor Yellow
                    }
                }
            }
            else {
                Write-Verbose "Action group already exists: $ActionGroupName"
            }
        }
        catch {
            Write-Warning "Failed to create action group: $_"
        }
    }
    
    # Enable diagnostic settings for all resources
    Write-Verbose "Enabling diagnostic settings for resources..."
    $resourceGroups = Get-AzResourceGroup
    
    foreach ($rg in $resourceGroups) {
        $resources = Get-AzResource -ResourceGroupName $rg.ResourceGroupName | Where-Object {
            $_.ResourceType -match 'Microsoft\.(Compute|Storage|Network|KeyVault|Sql|Web|Logic|FunctionApp)'
        }
        
        foreach ($resource in $resources) {
            if ($PSCmdlet.ShouldProcess($resource.Name, "Enable diagnostic settings")) {
                if (-not $WhatIf) {
                    try {
                        . "$PSScriptRoot\Enable-AzDiagnosticSettings.ps1" `
                            -ResourceId $resource.ResourceId `
                            -LogAnalyticsWorkspaceId $LogAnalyticsWorkspaceId `
                            -ErrorAction SilentlyContinue
                    }
                    catch {
                        Write-Verbose "Failed to enable diagnostics for $($resource.Name): $_"
                    }
                }
            }
        }
    }
    
    # Create activity log alerts
    if ($EnableActivityLogAlerts -and $actionGroup) {
        Write-Verbose "Creating activity log alerts..."
        
        $criticalOperations = @(
            @{ Operation = "Microsoft.Compute/virtualMachines/write"; Description = "VM Create or Update" },
            @{ Operation = "Microsoft.Compute/virtualMachines/delete"; Description = "VM Delete" },
            @{ Operation = "Microsoft.Network/networkSecurityGroups/write"; Description = "NSG Create or Update" },
            @{ Operation = "Microsoft.Network/networkSecurityGroups/delete"; Description = "NSG Delete" },
            @{ Operation = "Microsoft.Storage/storageAccounts/write"; Description = "Storage Account Create or Update" },
            @{ Operation = "Microsoft.Storage/storageAccounts/delete"; Description = "Storage Account Delete" },
            @{ Operation = "Microsoft.KeyVault/vaults/write"; Description = "Key Vault Create or Update" },
            @{ Operation = "Microsoft.KeyVault/vaults/delete"; Description = "Key Vault Delete" },
            @{ Operation = "Microsoft.Authorization/roleAssignments/write"; Description = "Role Assignment Create" },
            @{ Operation = "Microsoft.Authorization/roleAssignments/delete"; Description = "Role Assignment Delete" }
        )
        
        foreach ($op in $criticalOperations) {
            $alertName = "ActivityLog-$($op.Operation.Replace('/', '-').Replace('.', '-'))"
            
            if ($PSCmdlet.ShouldProcess($alertName, "Create activity log alert")) {
                if (-not $WhatIf) {
                    try {
                        $condition = New-AzActivityLogAlertCondition -Field "operationName" -Equal $op.Operation
                        Add-AzActivityLogAlert -Name $alertName -ResourceGroupName $resourceGroupName -Location "Global" -Scope "/subscriptions/$subscriptionId" -Action $actionGroup.Id -Condition $condition -ErrorAction SilentlyContinue
                        Write-Verbose "Created activity log alert: $alertName"
                    }
                    catch {
                        Write-Verbose "Failed to create alert $alertName : $_"
                    }
                }
                else {
                    Write-Host "Would create activity log alert: $alertName for $($op.Description)" -ForegroundColor Yellow
                }
            }
        }
        Write-Host "Activity log alerts configured" -ForegroundColor Green
    }
    
    # Create metric alerts for VMs
    if ($EnableMetricAlerts) {
        Write-Verbose "Creating metric alerts for VMs..."
        $vms = Get-AzVM
        
        foreach ($vm in $vms) {
            if ($actionGroup) {
                $alertName = "Metric-VM-$($vm.Name)-HighCPU"
                
                if ($PSCmdlet.ShouldProcess($alertName, "Create metric alert")) {
                    if (-not $WhatIf) {
                        try {
                            $condition = New-AzMetricAlertRuleV2Criteria -MetricName "Percentage CPU" -TimeAggregation Average -Operator GreaterThan -Threshold 80
                            Add-AzMetricAlertRuleV2 -Name $alertName -ResourceGroupName $vm.ResourceGroupName -WindowSize 00:05:00 -Frequency 00:01:00 -TargetResourceId $vm.Id -Condition $condition -ActionGroupId $actionGroup.Id -ErrorAction SilentlyContinue
                            Write-Verbose "Created metric alert: $alertName"
                        }
                        catch {
                            Write-Verbose "Failed to create metric alert $alertName : $_"
                        }
                    }
                    else {
                        Write-Host "Would create metric alert: $alertName for high CPU" -ForegroundColor Yellow
                    }
                }
            }
        }
        Write-Host "Metric alerts configured" -ForegroundColor Green
    }
    
    Write-Host "Monitoring baseline configuration completed" -ForegroundColor Green
}
catch {
    Write-Error "Failed to configure monitoring baseline: $_"
    throw
}


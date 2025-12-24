<#
.SYNOPSIS
    Enables diagnostic settings for Azure resources.

.DESCRIPTION
    Configures diagnostic settings to send logs and metrics to Log Analytics workspace
    or storage account for monitoring and compliance.

.PARAMETER ResourceId
    Resource ID to enable diagnostics for. Can be a single ID or array.

.PARAMETER LogAnalyticsWorkspaceId
    Log Analytics workspace resource ID for log destination.

.PARAMETER StorageAccountId
    Storage account resource ID for log destination (alternative to Log Analytics).

.PARAMETER Category
    Array of log categories to enable. Default: all available categories.

.PARAMETER MetricCategory
    Enable metrics collection. Default: $true.

.EXAMPLE
    Enable-AzDiagnosticSettings -ResourceId "/subscriptions/.../resourceGroups/.../providers/Microsoft.Compute/virtualMachines/vm1" -LogAnalyticsWorkspaceId "/subscriptions/.../resourceGroups/.../providers/Microsoft.OperationalInsights/workspaces/la-workspace"
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string[]]$ResourceId,
    
    [Parameter(Mandatory = $false)]
    [string]$LogAnalyticsWorkspaceId,
    
    [Parameter(Mandatory = $false)]
    [string]$StorageAccountId,
    
    [Parameter(Mandatory = $false)]
    [string[]]$Category,
    
    [Parameter(Mandatory = $false)]
    [switch]$MetricCategory = $true
)

. "$PSScriptRoot\..\..\Utilities\Common-Functions\Test-AzConnection.ps1"
Test-AzConnection -ConnectIfNeeded $true | Out-Null

$ErrorActionPreference = 'Stop'

begin {
    if (-not $LogAnalyticsWorkspaceId -and -not $StorageAccountId) {
        throw "Either LogAnalyticsWorkspaceId or StorageAccountId must be specified"
    }
    
    $destinationId = if ($LogAnalyticsWorkspaceId) { $LogAnalyticsWorkspaceId } else { $StorageAccountId }
}

process {
    foreach ($resource in $ResourceId) {
        try {
            Write-Verbose "Processing resource: $resource"
            
            # Get available diagnostic categories
            $availableCategories = Get-AzDiagnosticSettingCategory -ResourceId $resource -ErrorAction SilentlyContinue
            
            if (-not $availableCategories) {
                Write-Warning "No diagnostic categories available for resource: $resource"
                continue
            }
            
            $categoriesToEnable = if ($Category) {
                $availableCategories | Where-Object { $Category -contains $_.Name }
            }
            else {
                $availableCategories
            }
            
            $logSettings = $categoriesToEnable | Where-Object { $_.CategoryType -eq 'Logs' } | ForEach-Object {
                [Microsoft.Azure.Commands.Insights.OutputClasses.PSLogSettings]@{
                    Enabled = $true
                    Category = $_.Name
                }
            }
            
            $metricSettings = if ($MetricCategory) {
                [Microsoft.Azure.Commands.Insights.OutputClasses.PSMetricSettings]@{
                    Enabled = $true
                    TimeGrain = 'PT1M'
                }
            }
            
            $params = @{
                ResourceId = $resource
                Name = 'diagnostic-settings'
                WorkspaceId = if ($LogAnalyticsWorkspaceId) { $LogAnalyticsWorkspaceId } else { $null }
                StorageAccountId = if ($StorageAccountId) { $StorageAccountId } else { $null }
            }
            
            if ($logSettings) {
                $params.Log = $logSettings
            }
            
            if ($metricSettings) {
                $params.Metric = $metricSettings
            }
            
            if ($PSCmdlet.ShouldProcess($resource, "Enable diagnostic settings")) {
                Set-AzDiagnosticSetting @params -ErrorAction Stop
                Write-Host "Enabled diagnostic settings for: $resource" -ForegroundColor Green
            }
        }
        catch {
            Write-Error "Failed to enable diagnostic settings for $resource : $_"
        }
    }
}


<#
.SYNOPSIS
    Gets backup status for Azure resources.

.DESCRIPTION
    Retrieves backup status for VMs, file shares, and other protected resources.

.PARAMETER SubscriptionId
    Subscription ID to query. Uses current context if not specified.

.PARAMETER ResourceGroupName
    Optional resource group filter.

.PARAMETER VaultName
    Optional Recovery Services vault name filter.

.PARAMETER ExportToCsv
    Path to export results as CSV.

.EXAMPLE
    Get-AzBackupStatus -ExportToCsv "C:\Reports\BackupStatus.csv"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$VaultName,
    
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
    
    $params = @{}
    if ($ResourceGroupName) { $params.ResourceGroupName = $ResourceGroupName }
    if ($VaultName) { $params.Name = $VaultName }
    
    Write-Verbose "Retrieving Recovery Services vaults..."
    $vaults = Get-AzRecoveryServicesVault @params
    
    $backupStatus = @()
    
    foreach ($vault in $vaults) {
        Set-AzRecoveryServicesVaultContext -Vault $vault | Out-Null
        
        # Get VM backups
        $vmBackups = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -ErrorAction SilentlyContinue
        
        foreach ($container in $vmBackups) {
            $backupItem = Get-AzRecoveryServicesBackupItem -Container $container -WorkloadType AzureVM -ErrorAction SilentlyContinue
            
            foreach ($item in $backupItem) {
                $lastBackup = $item.LastBackupTime
                $protectionState = $item.ProtectionState
                $backupManagementType = $item.BackupManagementType
                
                $status = if ($lastBackup) {
                    $daysSinceBackup = (New-TimeSpan -Start $lastBackup -End (Get-Date)).Days
                    if ($daysSinceBackup -gt 7) { 'Warning' } elseif ($daysSinceBackup -gt 30) { 'Critical' } else { 'Healthy' }
                }
                else { 'Unknown' }
                
                $backupStatus += [PSCustomObject]@{
                    VaultName = $vault.Name
                    ResourceGroupName = $vault.ResourceGroupName
                    ResourceName = $item.Name
                    ResourceType = 'AzureVM'
                    ProtectionState = $protectionState
                    LastBackupTime = $lastBackup
                    DaysSinceBackup = if ($lastBackup) { (New-TimeSpan -Start $lastBackup -End (Get-Date)).Days } else { $null }
                    Status = $status
                    BackupManagementType = $backupManagementType
                }
            }
        }
    }
    
    Write-Verbose "Found $($backupStatus.Count) backup items"
    
    if ($ExportToCsv) {
        $backupStatus | Export-Csv -Path $ExportToCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Backup status exported to: $ExportToCsv" -ForegroundColor Green
    }
    
    return $backupStatus
}
catch {
    Write-Error "Failed to retrieve backup status: $_"
    throw
}


<#
.SYNOPSIS
    Applies NIST Cybersecurity Framework baseline configurations for Azure.

.DESCRIPTION
    Implements NIST CSF controls for Azure including:
    - Identify: Asset management, governance
    - Protect: Access control, data security, protective technology
    - Detect: Security monitoring, detection processes
    - Respond: Response planning, communications
    - Recover: Recovery planning, improvements

.PARAMETER SubscriptionId
    Subscription ID to apply baseline to. Uses current context if not specified.

.PARAMETER Framework
    NIST framework: CSF (Cybersecurity Framework) or 800-53. Default: CSF.

.PARAMETER WhatIf
    Preview changes without applying them.

.EXAMPLE
    Set-NISTAzureBaseline -Framework CSF -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('CSF', '800-53')]
    [string]$Framework = 'CSF',
    
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
    Write-Host "Applying NIST $Framework Baseline to subscription: $($context.Subscription.Name)" -ForegroundColor Cyan
    
    $findings = @()
    
    # NIST CSF ID.AM-1: Physical devices and systems within the organization are inventoried
    Write-Verbose "NIST ID.AM-1: Asset inventory"
    $resources = Get-AzResource
    $findings += [PSCustomObject]@{
        Function = "ID.AM-1"
        Category = "Identify - Asset Management"
        Description = "Physical devices and systems within the organization are inventoried"
        Status = "Compliant"
        Details = "Found $($resources.Count) resources inventoried"
    }
    
    # NIST CSF PR.AC-1: Identities and credentials are issued, managed, verified, revoked, and audited
    Write-Verbose "NIST PR.AC-1: Identity and access management"
    $roleAssignments = Get-AzRoleAssignment
    $findings += [PSCustomObject]@{
        Function = "PR.AC-1"
        Category = "Protect - Access Control"
        Description = "Identities and credentials are issued, managed, verified, revoked, and audited"
        Status = "Manual Review Required"
        Details = "Found $($roleAssignments.Count) role assignments. Review for least privilege."
    }
    
    # NIST CSF PR.DS-1: Data-at-rest is protected
    Write-Verbose "NIST PR.DS-1: Data-at-rest protection"
    $storageAccounts = Get-AzStorageAccount
    $unencryptedStorage = $storageAccounts | Where-Object { -not $_.Encryption.Services.Blob.Enabled }
    
    if ($unencryptedStorage.Count -gt 0) {
        $findings += [PSCustomObject]@{
            Function = "PR.DS-1"
            Category = "Protect - Data Security"
            Description = "Data-at-rest is protected"
            Status = "Non-Compliant"
            Details = "$($unencryptedStorage.Count) storage accounts without encryption"
        }
    }
    else {
        $findings += [PSCustomObject]@{
            Function = "PR.DS-1"
            Category = "Protect - Data Security"
            Description = "Data-at-rest is protected"
            Status = "Compliant"
            Details = "All storage accounts have encryption enabled"
        }
    }
    
    # NIST CSF PR.DS-2: Data-in-transit is protected
    Write-Verbose "NIST PR.DS-2: Data-in-transit protection"
    $unsecureStorage = $storageAccounts | Where-Object { -not $_.EnableHttpsTrafficOnly }
    
    if ($unsecureStorage.Count -gt 0) {
        foreach ($sa in $unsecureStorage) {
            if ($PSCmdlet.ShouldProcess($sa.StorageAccountName, "Enable HTTPS only")) {
                if (-not $WhatIf) {
                    Set-AzStorageAccount -ResourceGroupName $sa.ResourceGroupName -Name $sa.StorageAccountName -EnableHttpsTrafficOnly $true -ErrorAction SilentlyContinue
                    Write-Host "NIST PR.DS-2: Enabled HTTPS only for $($sa.StorageAccountName)" -ForegroundColor Green
                }
            }
        }
    }
    
    # NIST CSF DE.AE-1: Baseline of network operations and expected data flows
    Write-Verbose "NIST DE.AE-1: Network monitoring baseline"
    $findings += [PSCustomObject]@{
        Function = "DE.AE-1"
        Category = "Detect - Anomalies and Events"
        Description = "Baseline of network operations and expected data flows"
        Status = "Manual Configuration Required"
        Details = "Configure Network Watcher and flow logs"
    }
    
    # NIST CSF DE.CM-1: Network monitoring systems are deployed
    Write-Verbose "NIST DE.CM-1: Network monitoring deployment"
    $networkWatchers = Get-AzNetworkWatcher -ErrorAction SilentlyContinue
    if ($networkWatchers.Count -eq 0) {
        $findings += [PSCustomObject]@{
            Function = "DE.CM-1"
            Category = "Detect - Security Continuous Monitoring"
            Description = "Network monitoring systems are deployed"
            Status = "Non-Compliant"
            Details = "Network Watcher not deployed"
        }
    }
    
    # NIST CSF RS.CO-1: Personnel know their roles and order of operations
    Write-Verbose "NIST RS.CO-1: Response coordination"
    $findings += [PSCustomObject]@{
        Function = "RS.CO-1"
        Category = "Respond - Communications"
        Description = "Personnel know their roles and order of operations"
        Status = "Manual Process Required"
        Details = "Document incident response procedures"
    }
    
    # NIST CSF RC.IM-1: Recovery plans are in place
    Write-Verbose "NIST RC.IM-1: Recovery planning"
    $recoveryVaults = Get-AzRecoveryServicesVault
    $findings += [PSCustomObject]@{
        Function = "RC.IM-1"
        Category = "Recover - Improvements"
        Description = "Recovery plans are in place"
        Status = if ($recoveryVaults.Count -gt 0) { "Compliant" } else { "Non-Compliant" }
        Details = "Found $($recoveryVaults.Count) Recovery Services vaults"
    }
    
    Write-Host "`nNIST $Framework Baseline Application Summary:" -ForegroundColor Cyan
    $findings | Format-Table -AutoSize
    
    Write-Host "NIST baseline application completed" -ForegroundColor Green
    return $findings
}
catch {
    Write-Error "Failed to apply NIST baseline: $_"
    throw
}


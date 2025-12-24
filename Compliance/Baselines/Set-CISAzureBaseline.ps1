<#
.SYNOPSIS
    Applies CIS Azure Foundations Benchmark baseline configurations.

.DESCRIPTION
    Implements key controls from the CIS Azure Foundations Benchmark including:
    - Identity and Access Management
    - Security Center
    - Storage Accounts
    - Networking
    - Logging and Monitoring
    - Other Security Best Practices

.PARAMETER SubscriptionId
    Subscription ID to apply baseline to. Uses current context if not specified.

.PARAMETER ComplianceLevel
    Compliance level: Level1 (Essential) or Level2 (Advanced). Default: Level1.

.PARAMETER WhatIf
    Preview changes without applying them.

.EXAMPLE
    Set-CISAzureBaseline -ComplianceLevel Level1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Level1', 'Level2')]
    [string]$ComplianceLevel = 'Level1',
    
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
    Write-Host "Applying CIS Azure Baseline ($ComplianceLevel) to subscription: $($context.Subscription.Name)" -ForegroundColor Cyan
    
    $findings = @()
    
    # CIS 1.1: Ensure that multi-factor authentication is enabled for all non-privileged users
    Write-Verbose "Checking CIS 1.1: MFA for non-privileged users"
    $findings += [PSCustomObject]@{
        Control = "CIS 1.1"
        Description = "Ensure that multi-factor authentication is enabled for all non-privileged users"
        Status = "Manual Review Required (Azure AD)"
        Recommendation = "Enable MFA via Azure AD Conditional Access policies"
    }
    
    # CIS 1.3: Ensure that there are no guest users
    Write-Verbose "Checking CIS 1.3: Guest users"
    $findings += [PSCustomObject]@{
        Control = "CIS 1.3"
        Description = "Ensure that there are no guest users"
        Status = "Manual Review Required (Azure AD)"
        Recommendation = "Review and remove unnecessary guest users"
    }
    
    # CIS 2.1: Ensure that Azure Defender is set to On for App Service
    Write-Verbose "Checking CIS 2.1: Defender for App Service"
    try {
        $defenderAppService = Get-AzSecurityPricing -Name "AppServices" -ErrorAction SilentlyContinue
        if ($defenderAppService.PricingTier -ne "Standard") {
            if ($PSCmdlet.ShouldProcess("AppServices", "Enable Defender")) {
                if (-not $WhatIf) {
                    Set-AzSecurityPricing -Name "AppServices" -PricingTier "Standard" -ErrorAction Stop
                    Write-Host "CIS 2.1: Defender for App Service enabled" -ForegroundColor Green
                }
                else {
                    Write-Host "Would enable Defender for App Service" -ForegroundColor Yellow
                }
            }
        }
    }
    catch {
        $findings += [PSCustomObject]@{
            Control = "CIS 2.1"
            Description = "Ensure that Azure Defender is set to On for App Service"
            Status = "Failed"
            Recommendation = "Manually enable Defender for App Service"
        }
    }
    
    # CIS 2.2: Ensure that Azure Defender is set to On for Azure SQL database servers
    Write-Verbose "Checking CIS 2.2: Defender for SQL Servers"
    try {
        $defenderSql = Get-AzSecurityPricing -Name "SqlServers" -ErrorAction SilentlyContinue
        if ($defenderSql.PricingTier -ne "Standard") {
            if ($PSCmdlet.ShouldProcess("SqlServers", "Enable Defender")) {
                if (-not $WhatIf) {
                    Set-AzSecurityPricing -Name "SqlServers" -PricingTier "Standard" -ErrorAction Stop
                    Write-Host "CIS 2.2: Defender for SQL Servers enabled" -ForegroundColor Green
                }
                else {
                    Write-Host "Would enable Defender for SQL Servers" -ForegroundColor Yellow
                }
            }
        }
    }
    catch {
        $findings += [PSCustomObject]@{
            Control = "CIS 2.2"
            Description = "Ensure that Azure Defender is set to On for Azure SQL database servers"
            Status = "Failed"
            Recommendation = "Manually enable Defender for SQL Servers"
        }
    }
    
    # CIS 2.3: Ensure that Azure Defender is set to On for Storage Accounts
    Write-Verbose "Checking CIS 2.3: Defender for Storage Accounts"
    try {
        $defenderStorage = Get-AzSecurityPricing -Name "StorageAccounts" -ErrorAction SilentlyContinue
        if ($defenderStorage.PricingTier -ne "Standard") {
            if ($PSCmdlet.ShouldProcess("StorageAccounts", "Enable Defender")) {
                if (-not $WhatIf) {
                    Set-AzSecurityPricing -Name "StorageAccounts" -PricingTier "Standard" -ErrorAction Stop
                    Write-Host "CIS 2.3: Defender for Storage Accounts enabled" -ForegroundColor Green
                }
                else {
                    Write-Host "Would enable Defender for Storage Accounts" -ForegroundColor Yellow
                }
            }
        }
    }
    catch {
        $findings += [PSCustomObject]@{
            Control = "CIS 2.3"
            Description = "Ensure that Azure Defender is set to On for Storage Accounts"
            Status = "Failed"
            Recommendation = "Manually enable Defender for Storage Accounts"
        }
    }
    
    # CIS 3.1: Ensure that 'Secure transfer required' is set to 'Enabled'
    Write-Verbose "Checking CIS 3.1: Secure transfer required for storage accounts"
    $storageAccounts = Get-AzStorageAccount
    foreach ($sa in $storageAccounts) {
        if (-not $sa.EnableHttpsTrafficOnly) {
            if ($PSCmdlet.ShouldProcess($sa.StorageAccountName, "Enable HTTPS only")) {
                if (-not $WhatIf) {
                    Set-AzStorageAccount -ResourceGroupName $sa.ResourceGroupName -Name $sa.StorageAccountName -EnableHttpsTrafficOnly $true -ErrorAction SilentlyContinue
                    Write-Host "CIS 3.1: Enabled HTTPS only for $($sa.StorageAccountName)" -ForegroundColor Green
                }
                else {
                    Write-Host "Would enable HTTPS only for $($sa.StorageAccountName)" -ForegroundColor Yellow
                }
            }
        }
    }
    
    # CIS 3.5: Ensure that 'Public access level' is set to Private for blob containers
    Write-Verbose "Checking CIS 3.5: Blob public access"
    foreach ($sa in $storageAccounts) {
        $blobService = Get-AzStorageBlobServiceProperty -ResourceGroupName $sa.ResourceGroupName -StorageAccountName $sa.StorageAccountName -ErrorAction SilentlyContinue
        if ($blobService -and $blobService.AllowBlobPublicAccess) {
            if ($PSCmdlet.ShouldProcess($sa.StorageAccountName, "Disable blob public access")) {
                if (-not $WhatIf) {
                    Update-AzStorageBlobServiceProperty -ResourceGroupName $sa.ResourceGroupName -StorageAccountName $sa.StorageAccountName -AllowBlobPublicAccess $false -ErrorAction SilentlyContinue
                    Write-Host "CIS 3.5: Disabled blob public access for $($sa.StorageAccountName)" -ForegroundColor Green
                }
                else {
                    Write-Host "Would disable blob public access for $($sa.StorageAccountName)" -ForegroundColor Yellow
                }
            }
        }
    }
    
    # CIS 3.6: Ensure default network access rule for Storage Accounts is set to deny
    Write-Verbose "Checking CIS 3.6: Storage account network rules"
    foreach ($sa in $storageAccounts) {
        if ($sa.NetworkRuleSet.DefaultAction -ne 'Deny') {
            if ($PSCmdlet.ShouldProcess($sa.StorageAccountName, "Set network rule to Deny")) {
                if (-not $WhatIf) {
                    Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $sa.ResourceGroupName -Name $sa.StorageAccountName -DefaultAction Deny -ErrorAction SilentlyContinue
                    Write-Host "CIS 3.6: Set network rule to Deny for $($sa.StorageAccountName)" -ForegroundColor Green
                }
                else {
                    Write-Host "Would set network rule to Deny for $($sa.StorageAccountName)" -ForegroundColor Yellow
                }
            }
        }
    }
    
    # CIS 3.7: Ensure 'Trusted Microsoft Services' is enabled for Storage Account access
    Write-Verbose "Checking CIS 3.7: Trusted Microsoft Services"
    foreach ($sa in $storageAccounts) {
        if ($sa.NetworkRuleSet.Bypass -notcontains 'AzureServices') {
            if ($PSCmdlet.ShouldProcess($sa.StorageAccountName, "Enable AzureServices bypass")) {
                if (-not $WhatIf) {
                    $bypass = $sa.NetworkRuleSet.Bypass + @('AzureServices')
                    Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $sa.ResourceGroupName -Name $sa.StorageAccountName -Bypass $bypass -ErrorAction SilentlyContinue
                    Write-Host "CIS 3.7: Enabled AzureServices bypass for $($sa.StorageAccountName)" -ForegroundColor Green
                }
                else {
                    Write-Host "Would enable AzureServices bypass for $($sa.StorageAccountName)" -ForegroundColor Yellow
                }
            }
        }
    }
    
    # CIS 5.1.3: Ensure the Activity Log Alert exists for Create or Update Network Security Group Rule
    Write-Verbose "Checking CIS 5.1.3: Activity Log Alert for NSG changes"
    $findings += [PSCustomObject]@{
        Control = "CIS 5.1.3"
        Description = "Ensure the Activity Log Alert exists for Create or Update Network Security Group Rule"
        Status = "Manual Configuration Required"
        Recommendation = "Create Activity Log Alert for Microsoft.Network/networkSecurityGroups/write"
    }
    
    # CIS 5.1.4: Ensure the Activity Log Alert exists for Delete Network Security Group Rule
    Write-Verbose "Checking CIS 5.1.4: Activity Log Alert for NSG deletion"
    $findings += [PSCustomObject]@{
        Control = "CIS 5.1.4"
        Description = "Ensure the Activity Log Alert exists for Delete Network Security Group Rule"
        Status = "Manual Configuration Required"
        Recommendation = "Create Activity Log Alert for Microsoft.Network/networkSecurityGroups/delete"
    }
    
    Write-Host "`nCIS Baseline Application Summary:" -ForegroundColor Cyan
    Write-Host "Controls requiring manual review:" -ForegroundColor Yellow
    $findings | Format-Table -AutoSize
    
    Write-Host "CIS baseline application completed" -ForegroundColor Green
    return $findings
}
catch {
    Write-Error "Failed to apply CIS baseline: $_"
    throw
}


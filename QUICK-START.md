# Quick Start Guide

## Common Tasks

### 1. Inventory and Reporting

**Get VM Inventory**
```powershell
.\Azure\Compute\Get-AzVMInventory.ps1 -ExportToCsv "C:\Reports\VMInventory.csv"
```

**Get Storage Account Inventory**
```powershell
.\Azure\Storage\Get-AzStorageAccountInventory.ps1 -ExportToCsv "C:\Reports\StorageInventory.csv"
```

**Get RBAC Report**
```powershell
.\Azure\Identity\Get-AzRoleAssignmentReport.ps1 -ExportToCsv "C:\Reports\RBACReport.csv"
```

**Get Resource Inventory**
```powershell
.\Utilities\Common-Functions\Get-AzResourceInventory.ps1 -ExportToCsv "C:\Reports\ResourceInventory.csv"
```

### 2. Security Analysis

**Analyze NSG Rules**
```powershell
.\Azure\Networking\Get-AzNSGRuleAnalysis.ps1 -ExportToCsv "C:\Reports\NSGAnalysis.csv"
```

**Get Key Vault Inventory**
```powershell
.\Azure\Security\Get-AzKeyVaultInventory.ps1 -ExportToCsv "C:\Reports\KeyVaultInventory.csv"
```

**Get Security Recommendations**
```powershell
.\Defender\Defender-for-Cloud\Get-DefenderSecurityRecommendations.ps1 -Severity Critical -ExportToCsv "C:\Reports\SecurityRecommendations.csv"
```

### 3. Cost Management

**Cost Analysis**
```powershell
.\Compliance\Governance\Get-AzCostAnalysis.ps1 -GroupBy ResourceGroup -ExportToCsv "C:\Reports\CostAnalysis.csv"
```

### 4. Compliance

**Policy Compliance**
```powershell
.\Azure\Policy-Governance\Get-AzPolicyCompliance.ps1 -ExportToCsv "C:\Reports\PolicyCompliance.csv"
```

**Intune Device Compliance**
```powershell
.\Intune\Device-Configuration\Get-IntuneDeviceCompliance.ps1 -ExportToCsv "C:\Reports\IntuneCompliance.csv"
```

### 5. Automation

**VM Schedule Management**
```powershell
# Preview scheduled VMs
.\Azure\Compute\Start-AzVMBySchedule.ps1 -WhatIf
.\Azure\Compute\Stop-AzVMBySchedule.ps1 -WhatIf

# Execute (use in Azure Automation)
.\Azure\Compute\Start-AzVMBySchedule.ps1
.\Azure\Compute\Stop-AzVMBySchedule.ps1
```

**Resource Tagging**
```powershell
.\PowerShell\Azure\Set-AzResourceTags.ps1 -ResourceGroupName "Production-RG" -Tags @{Environment="Prod"; CostCenter="12345"} -TagAction Merge
```

**Storage Account Security Hardening**
```powershell
.\Azure\Security\Set-AzStorageAccountSecurity.ps1 -ResourceGroupName "Storage-RG" -WhatIf
```

### 6. Monitoring

**Enable Diagnostic Settings**
```powershell
$resources = Get-AzResource -ResourceGroupName "Production-RG"
$workspaceId = "/subscriptions/.../resourceGroups/.../providers/Microsoft.OperationalInsights/workspaces/la-workspace"
$resources | ForEach-Object { .\Azure\Monitoring\Enable-AzDiagnosticSettings.ps1 -ResourceId $_.ResourceId -LogAnalyticsWorkspaceId $workspaceId }
```

**Backup Status**
```powershell
.\Azure\Backup-Recovery\Get-AzBackupStatus.ps1 -ExportToCsv "C:\Reports\BackupStatus.csv"
```

## Script Categories

### Azure Scripts
- **Compute**: VM inventory, scheduling, resizing
- **Networking**: NSG analysis
- **Storage**: Storage account inventory and security
- **Identity**: RBAC reporting
- **Monitoring**: Diagnostic settings
- **Security**: Key Vault inventory, storage security
- **Policy-Governance**: Policy compliance
- **Backup-Recovery**: Backup status

### Intune Scripts
- **Device-Configuration**: Device compliance reporting
- **Remediation-Scripts**: Software installation automation

### Defender Scripts
- **Defender-for-Cloud**: Security recommendations
- **Remediation-Scripts**: Automated remediation

### Terraform Modules
- **storage-account**: Reusable storage account module
- **virtual-network**: Reusable VNet module

### Utilities
- **Common-Functions**: Reusable logging, connection testing, inventory
- **Templates**: Script templates for new scripts

## Best Practices

1. **Always use -WhatIf first** when available to preview changes
2. **Export to CSV** for analysis and reporting
3. **Test in non-production** before production use
4. **Use Azure Automation** for scheduled tasks
5. **Review security recommendations** before automated remediation

## Common Parameters

Most scripts support:
- `-SubscriptionId`: Target specific subscription
- `-ResourceGroupName`: Filter by resource group
- `-ExportToCsv`: Export results to CSV
- `-WhatIf`: Preview changes without applying
- `-Verbose`: Detailed output

## Getting Help

```powershell
# Get help for any script
Get-Help .\Azure\Compute\Get-AzVMInventory.ps1 -Full
```


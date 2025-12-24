# Installation Guide

This guide provides instructions for setting up the ScriptHub repository and required dependencies.

## Prerequisites

- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or PowerShell 7+
- Administrator privileges (for module installation)

## PowerShell Module Installation

### Install All Required Modules

```powershell
# Install all Azure modules
Install-Module -Name Az -Force -AllowClobber -Scope CurrentUser

# Install Microsoft Graph modules for Intune
Install-Module -Name Microsoft.Graph.DeviceManagement -Force -AllowClobber -Scope CurrentUser
Install-Module -Name Microsoft.Graph.Identity.DirectoryManagement -Force -AllowClobber -Scope CurrentUser
```

### Verify Installation

```powershell
# Check installed Az modules
Get-Module -ListAvailable Az.* | Select-Object Name, Version

# Check Graph modules
Get-Module -ListAvailable Microsoft.Graph.* | Select-Object Name, Version
```

## Authentication Setup

### Azure Authentication

```powershell
# Connect to Azure
Connect-AzAccount

# Select subscription
Set-AzContext -SubscriptionId "your-subscription-id"

# Verify connection
Get-AzContext
```

### Microsoft Graph Authentication (for Intune)

```powershell
# Connect to Microsoft Graph
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All", "DeviceManagementConfiguration.Read.All"

# Verify connection
Get-MgContext
```

## Terraform Setup

1. Download Terraform from [terraform.io/downloads](https://www.terraform.io/downloads)
2. Extract and add to PATH
3. Verify installation:
   ```powershell
   terraform version
   ```

### Initialize Terraform Providers

```powershell
cd Terraform\Providers
terraform init
```

## Azure Automation Setup

For scripts designed for Azure Automation:

1. Create an Azure Automation Account
2. Enable System Managed Identity
3. Grant necessary permissions to the managed identity
4. Import scripts as runbooks
5. Configure schedules as needed

## Usage Examples

### Run a Script

```powershell
# Example: Get VM inventory
.\Azure\Compute\Get-AzVMInventory.ps1 -ExportToCsv "C:\Reports\VMInventory.csv"

# Example: Analyze NSG rules
.\Azure\Networking\Get-AzNSGRuleAnalysis.ps1 -ExportToCsv "C:\Reports\NSGAnalysis.csv"
```

### Use Common Functions

```powershell
# Import common functions
. .\Utilities\Common-Functions\Test-AzConnection.ps1
. .\Utilities\Common-Functions\Write-Log.ps1

# Use in your scripts
Test-AzConnection -ConnectIfNeeded $true
Write-Log -Message "Script started" -Level Info
```

## Troubleshooting

### Module Not Found

If you encounter "module not found" errors:

```powershell
# Update module repository
Update-Module -Name Az -Force

# Reinstall specific module
Uninstall-Module -Name Az.Accounts -AllVersions
Install-Module -Name Az.Accounts -Force -AllowClobber
```

### Authentication Issues

```powershell
# Clear cached credentials
Clear-AzContext -Force
Connect-AzAccount

# For Graph API
Disconnect-MgGraph
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All"
```

### Execution Policy

If scripts are blocked by execution policy:

```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy (requires admin)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Best Practices

1. Always test scripts in non-production environments first
2. Use `-WhatIf` parameter when available to preview changes
3. Review and customize scripts for your environment
4. Keep modules updated regularly
5. Use managed identities in Azure Automation for production
6. Store sensitive data in Azure Key Vault, not in scripts


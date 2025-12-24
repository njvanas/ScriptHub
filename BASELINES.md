# Baseline Configurations Guide

This guide explains how to use the baseline configuration scripts to establish consistent, secure, and compliant Azure environments.

## Overview

Baseline scripts provide standardized configurations for:
- **Security**: Hardening and security best practices
- **Compliance**: CIS, NIST, and other compliance frameworks
- **Monitoring**: Comprehensive monitoring and alerting
- **Governance**: Tagging, policies, and resource management
- **Environments**: Complete environment setup with best practices

## Security Baselines

### Azure Security Baseline

Applies comprehensive security configurations to your Azure subscription:

```powershell
# Preview security baseline
.\Azure\Security\Set-AzSecurityBaseline.ps1 `
    -LogAnalyticsWorkspaceId "/subscriptions/.../workspaces/la-workspace" `
    -WhatIf

# Apply security baseline
.\Azure\Security\Set-AzSecurityBaseline.ps1 `
    -LogAnalyticsWorkspaceId "/subscriptions/.../workspaces/la-workspace"
```

**What it does:**
- Enables Microsoft Defender for Cloud
- Configures diagnostic settings for all resources
- Applies storage account security baseline
- Hardens Key Vault configurations
- Sets network security rules

## Compliance Baselines

### CIS Azure Foundations Benchmark

Implements controls from the CIS Azure Foundations Benchmark:

```powershell
# Apply CIS Level 1 (Essential) baseline
.\Compliance\Baselines\Set-CISAzureBaseline.ps1 -ComplianceLevel Level1 -WhatIf

# Apply CIS Level 2 (Advanced) baseline
.\Compliance\Baselines\Set-CISAzureBaseline.ps1 -ComplianceLevel Level2
```

**Key Controls:**
- Identity and Access Management (MFA, guest users)
- Security Center configuration
- Storage account security (HTTPS, public access, network rules)
- Activity log alerts
- Defender for Cloud enablement

### NIST Cybersecurity Framework

Applies NIST CSF controls:

```powershell
# Apply NIST CSF baseline
.\Compliance\Baselines\Set-NISTAzureBaseline.ps1 -Framework CSF -WhatIf
```

**Framework Functions:**
- **Identify**: Asset management, governance
- **Protect**: Access control, data security
- **Detect**: Security monitoring
- **Respond**: Response planning
- **Recover**: Recovery planning

## Monitoring Baselines

### Comprehensive Monitoring Setup

Configures monitoring and alerting for your Azure environment:

```powershell
.\Azure\Monitoring\Set-AzMonitoringBaseline.ps1 `
    -LogAnalyticsWorkspaceId "/subscriptions/.../workspaces/la-workspace" `
    -EmailAddresses @("admin@company.com", "ops@company.com") `
    -WhatIf
```

**Features:**
- Diagnostic settings for all resources
- Activity log alerts for critical operations
- Metric alerts for resource health
- Action groups for notifications
- Log Analytics workspace configuration

## Governance Baselines

### Tagging Strategy

Applies consistent tagging across resources:

```powershell
# Basic tagging
.\Compliance\Governance\Set-AzTaggingBaseline.ps1 `
    -TaggingStrategy Basic `
    -DefaultTags @{Environment="Prod"; CostCenter="12345"; Owner="IT Team"} `
    -WhatIf

# Compliance tagging
.\Compliance\Governance\Set-AzTaggingBaseline.ps1 `
    -TaggingStrategy Compliance `
    -DefaultTags @{DataClassification="Internal"; RetentionPeriod="7Years"}
```

**Tagging Strategies:**
- **Basic**: Essential tags (Environment, CostCenter, Owner)
- **Advanced**: Extended tags with metadata
- **Compliance**: Compliance-focused tags (DataClassification, RetentionPeriod)

### Policy Baseline

Deploys Azure Policy assignments:

```powershell
# Basic policy set
.\Compliance\Policy\New-AzPolicyBaseline.ps1 `
    -PolicySet Basic `
    -AllowedLocations @("East US", "West US") `
    -RequiredTags @("Environment", "CostCenter", "Owner") `
    -WhatIf

# Security policy set
.\Compliance\Policy\New-AzPolicyBaseline.ps1 -PolicySet Security

# Full policy set (Basic + Security + Compliance)
.\Compliance\Policy\New-AzPolicyBaseline.ps1 -PolicySet Full
```

**Policy Sets:**
- **Basic**: Required tags, allowed locations
- **Security**: Storage security, HTTPS, encryption, Key Vault
- **Compliance**: Audit diagnostic settings, public IPs
- **Full**: All policies combined

## Environment Baselines

### Complete Environment Deployment

Creates a production-ready Azure environment:

```powershell
.\Azure\Deployment\New-AzEnvironmentBaseline.ps1 `
    -EnvironmentName "Production" `
    -Location "East US" `
    -ProjectName "MyProject" `
    -CostCenter "12345" `
    -Owner "IT Team" `
    -EnableMonitoring $true `
    -EnableBackup $true `
    -WhatIf
```

**Creates:**
- Resource group with proper naming
- Log Analytics workspace
- Key Vault with security settings
- Recovery Services Vault
- Network Watcher
- All resources tagged appropriately

## Intune Baselines

### Device Configuration Profiles

Creates baseline Intune configuration profiles:

```powershell
.\Intune\Device-Configuration\New-IntuneBaselineProfile.ps1 `
    -ProfileName "Windows Security Baseline" `
    -ProfileType SecurityBaseline `
    -Platform Windows10 `
    -WhatIf
```

## Terraform Environment Baselines

### Production Environment

```bash
cd Terraform/Environments/Production
terraform init
terraform plan -var="project_name=MyProject" -var="cost_center=12345" -var="owner=IT Team"
terraform apply
```

### Development Environment

```bash
cd Terraform/Environments/Dev
terraform init
terraform plan -var="project_name=MyProject"
terraform apply
```

## Baseline Application Workflow

### Recommended Order

1. **Deploy Environment Baseline**
   ```powershell
   .\Azure\Deployment\New-AzEnvironmentBaseline.ps1 -EnvironmentName "Production" ...
   ```

2. **Apply Security Baseline**
   ```powershell
   .\Azure\Security\Set-AzSecurityBaseline.ps1 -LogAnalyticsWorkspaceId "..." ...
   ```

3. **Configure Monitoring**
   ```powershell
   .\Azure\Monitoring\Set-AzMonitoringBaseline.ps1 -LogAnalyticsWorkspaceId "..." ...
   ```

4. **Apply Tagging Strategy**
   ```powershell
   .\Compliance\Governance\Set-AzTaggingBaseline.ps1 -TaggingStrategy Advanced ...
   ```

5. **Deploy Policy Baseline**
   ```powershell
   .\Compliance\Policy\New-AzPolicyBaseline.ps1 -PolicySet Full ...
   ```

6. **Apply Compliance Baseline**
   ```powershell
   .\Compliance\Baselines\Set-CISAzureBaseline.ps1 -ComplianceLevel Level1
   ```

## Best Practices

1. **Always use -WhatIf first** to preview changes
2. **Start with non-production** environments
3. **Review compliance requirements** before applying baselines
4. **Customize baselines** for your organization's needs
5. **Document deviations** from baseline standards
6. **Regularly review and update** baseline configurations
7. **Use version control** for baseline customizations

## Customization

All baseline scripts support customization through parameters. Review script help for available options:

```powershell
Get-Help .\Azure\Security\Set-AzSecurityBaseline.ps1 -Full
```

## Troubleshooting

### Common Issues

1. **Permission Errors**: Ensure you have Contributor or Owner role
2. **Resource Conflicts**: Some resources may already exist
3. **Policy Conflicts**: Review existing policy assignments
4. **Tag Conflicts**: Existing tags may conflict with baseline

### Verification

After applying baselines, verify compliance:

```powershell
# Check policy compliance
.\Azure\Policy-Governance\Get-AzPolicyCompliance.ps1

# Review security recommendations
.\Defender\Defender-for-Cloud\Get-DefenderSecurityRecommendations.ps1

# Check resource inventory
.\Utilities\Common-Functions\Get-AzResourceInventory.ps1
```


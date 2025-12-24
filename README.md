# ScriptHub

A comprehensive collection of scripts and automation tools for Azure-focused MSP cloud engineers. This repository contains scripts for managing Azure environments, Intune, Microsoft Defender, Terraform infrastructure, and various automation tasks.

## 📁 Folder Structure

### Azure
Core Azure service management scripts:
- **Compute** - Virtual Machines, App Services, Azure Functions, Container Instances
- **Networking** - Virtual Networks, Network Security Groups, Load Balancers, VPN Gateways
- **Storage** - Storage Accounts, Blob Storage, File Shares, Disk Management
- **Identity** - Azure AD, RBAC, Managed Identities, Service Principals
- **Monitoring** - Log Analytics, Application Insights, Metrics, Diagnostic Settings
- **Security** - Key Vault, Security Center, Azure Sentinel, Security Policies
- **Backup-Recovery** - Backup scripts, disaster recovery procedures, restore operations
- **Policy-Governance** - Azure Policy definitions, governance scripts, compliance checks

### Intune
Microsoft Intune management and configuration scripts:
- **Device-Configuration** - Device configuration profiles, settings management
- **Compliance-Policies** - Compliance policy scripts, remediation automation
- **App-Protection** - App protection policies, MAM policies
- **Enrollment** - Device enrollment automation, bulk enrollment scripts
- **Remediation-Scripts** - Proactive remediation scripts, detection/remediation automation

### Defender
Microsoft Defender suite management scripts:
- **Defender-for-Cloud** - Cloud security posture management, security recommendations
- **Defender-for-Endpoint** - Endpoint detection and response, threat management
- **Defender-for-Identity** - Identity security monitoring, threat detection
- **Defender-for-Office365** - Email and collaboration security, threat protection
- **Remediation-Scripts** - Automated remediation for security findings

### Terraform
Infrastructure as Code (IaC) for Azure:
- **Modules** - Reusable Terraform modules for common Azure resources
- **Environments** - Environment-specific configurations
  - **Dev** - Development environment configurations
  - **Staging** - Staging environment configurations
  - **Production** - Production environment configurations
- **Providers** - Terraform provider configurations and versions

### PowerShell
PowerShell scripts organized by service:
- **Azure** - Azure-specific PowerShell scripts and modules
- **Intune** - Intune management via PowerShell (Graph API, Intune PowerShell SDK)
- **Defender** - Defender management and automation scripts
- **Utilities** - General-purpose PowerShell utilities and helper functions

### Automation
Automation runbooks and workflows:
- **Azure-Automation** - Azure Automation runbooks (PowerShell, Python)
- **Logic-Apps** - Azure Logic Apps workflows and templates
- **Azure-Functions** - Azure Functions code and configurations

### Monitoring
Monitoring, alerting, and observability scripts:
- **Log-Analytics-Queries** - KQL queries for Log Analytics workspaces
- **Alert-Rules** - Alert rule definitions and automation scripts
- **Dashboards** - Dashboard configurations and export scripts

### Compliance
Compliance and governance automation:
- **Policy** - Azure Policy definitions, assignments, and remediation
- **Blueprints** - Azure Blueprint definitions and assignments
- **Governance** - Governance automation, resource tagging, cost management

### Utilities
Shared utilities and common functions:
- **Common-Functions** - Reusable functions used across multiple scripts
- **Helpers** - Helper scripts and utilities
- **Templates** - Script templates and boilerplate code

## 🎯 Usage

This repository is designed for MSP cloud engineers managing multiple Azure environments. Scripts are organized to be:
- **Reusable** - Can be adapted for multiple clients
- **Maintainable** - Clear folder structure for easy navigation
- **Public** - Suitable for public sharing and collaboration

## 📝 Contributing

When adding new scripts:
1. Place them in the appropriate folder based on their primary function
2. Include clear documentation and comments
3. Follow PowerShell/scripting best practices
4. Test scripts in non-production environments first

## ⚠️ Disclaimer

These scripts are provided as-is for educational and operational purposes. Always review and test scripts in a non-production environment before deploying to production. Ensure compliance with your organization's security and governance policies.
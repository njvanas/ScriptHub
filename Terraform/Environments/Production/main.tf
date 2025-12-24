# Production Environment Baseline Configuration
# This file defines the baseline infrastructure for production environments

terraform {
  required_version = ">= 1.5.0"
  
  backend "azurerm" {
    # Configure backend via backend.hcl or environment variables
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Variables
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "Production"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "cost_center" {
  description = "Cost center code"
  type        = string
}

variable "owner" {
  description = "Resource owner"
  type        = string
}

# Common tags for all resources
locals {
  common_tags = {
    Environment   = var.environment
    Project       = var.project_name
    CostCenter    = var.cost_center
    Owner         = var.owner
    ManagedBy     = "Terraform"
    CreatedDate   = timestamp()
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-prod-001"
  location = var.location

  tags = local.common_tags
}

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.project_name}-prod-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 90

  tags = local.common_tags
}

# Recovery Services Vault for backups
resource "azurerm_recovery_services_vault" "main" {
  name                = "rsv-${var.project_name}-prod-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  soft_delete_enabled = true

  tags = local.common_tags
}

# Key Vault with security best practices
resource "azurerm_key_vault" "main" {
  name                = "kv-${var.project_name}-prod-001"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  enabled_for_deployment          = false
  enabled_for_template_deployment = false
  enabled_for_disk_encryption     = true
  enable_rbac_authorization      = true
  soft_delete_retention_days      = 90
  purge_protection_enabled        = true

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = local.common_tags
}

data "azurerm_client_config" "current" {}

# Storage Account with security baseline
module "storage_account" {
  source = "../../Modules/storage-account"

  storage_account_name      = "st${replace(var.project_name, "-", "")}prod001"
  resource_group_name       = azurerm_resource_group.main.name
  location                  = var.location
  account_tier              = "Standard"
  account_replication_type  = "GRS"
  min_tls_version           = "TLS1_2"
  allow_nested_items_to_be_public = false

  network_rules = {
    default_action             = "Deny"
    ip_rules                   = []
    virtual_network_subnet_ids = []
    bypass                     = ["AzureServices"]
  }

  tags = local.common_tags
}

# Outputs
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = module.storage_account.storage_account_name
}


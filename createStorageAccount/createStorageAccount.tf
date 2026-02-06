
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}

variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

variable "resourceGroup" {
  description = "Resource Group"
  type        = string

  default = "ncezid-ezdtx-devops"

}

variable "storageAccountName" {
  description = "Storage Account"
  type        = string

  validation {
    condition     = length(var.storageAccountName) >= 3 && length(var.storageAccountName) <= 24
    error_message = "Storage account name must be between 3 and 24 characters."
  }

  validation {
    condition     = (!can(regex("[^a-z0-9]", var.storageAccountName)))
    error_message = "Storage account name must contain only lowercase letters and numbers."
  }

}

variable "accountTier" {
  description = "Account Tier"
  type        = string
}

variable "accountKind" {
  description = "Account Kind"
  type        = string
}

variable "accountReplicationType" {
  description = "Account Replication Type"
  type        = string
}

variable "readOnlyADGroup" {
  description = "AD Group with read only role"
  type        = string

  default = "NCIRD_NDSP_DEV_R"
}

variable "readWriteADGroup" {
  description = "AD Group with read/write role"
  type        = string

  default = "NCIRD_NDSP_DEV_RW"
}

data "azurerm_resource_group" "selected-rg" {
  name = var.resourceGroup
}

data "azuread_group" "readOnlyGroup" {
  display_name     = var.readOnlyADGroup
  security_enabled = true
}

data "azuread_group" "readWriteGroup" {
  display_name     = var.readWriteADGroup
  security_enabled = true
}

resource "azurerm_storage_account" "storageAccount" {
  name                = var.storageAccountName
  resource_group_name = data.azurerm_resource_group.selected-rg.name

  location                 = data.azurerm_resource_group.selected-rg.location
  account_kind             = var.accountKind
  account_tier             = var.accountTier
  account_replication_type = var.accountTier == "Premium" ? "LRS" : var.accountReplicationType
  min_tls_version          = "TLS1_2"
  allow_blob_public_access = false

  tags = {
    AccountKind = var.accountKind

  }
}

resource "azurerm_storage_container" "container-1" {
  name                  = "inbound"
  storage_account_name  = azurerm_storage_account.storageAccount.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "container-2" {
  name                  = "outbound"
  storage_account_name  = azurerm_storage_account.storageAccount.name
  container_access_type = "private"
}

resource "azurerm_role_assignment" "readerroleassignment1" {
  scope                = azurerm_storage_account.storageAccount.id
  role_definition_name = "Reader"
  principal_id         = data.azuread_group.readOnlyGroup.object_id
}

resource "azurerm_role_assignment" "readerroleassignment2" {
  scope                = azurerm_storage_account.storageAccount.id
  role_definition_name = "Reader"
  principal_id         = data.azuread_group.readWriteGroup.object_id
}

resource "azurerm_role_assignment" "blobreaderroleassignment1" {
  scope                = azurerm_storage_container.container-1.resource_manager_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = data.azuread_group.readOnlyGroup.object_id
}

resource "azurerm_role_assignment" "blobcontributerroleassignment1" {
  scope                = azurerm_storage_container.container-1.resource_manager_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_group.readWriteGroup.object_id
}

resource "azurerm_role_assignment" "blobreaderroleassignment2" {
  scope                = azurerm_storage_container.container-2.resource_manager_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = data.azuread_group.readOnlyGroup.object_id
}

resource "azurerm_role_assignment" "blobcontributerroleassignment2" {
  scope                = azurerm_storage_container.container-2.resource_manager_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_group.readWriteGroup.object_id
}

resource "azurerm_storage_management_policy" "storagemgmtpolicy" {
  storage_account_id = azurerm_storage_account.storageAccount.id

  rule {
    name    = "rule1"
    enabled = true
    filters {
      blob_types = ["blockBlob"]
    }
    actions {
      base_blob {
        tier_to_archive_after_days_since_modification_greater_than = 180
      }
    }
  }
}
#NCIRD_NDSP_IDODIFX_RW
# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.68.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
 admin_users = [
  "mcq1@cdc.gov",
  "qkw9@cdc.gov",
  "ygj6@cdc.gov",
  "iuj6@cdc.gov"
]
}

locals{
tenant_users = [
  "iuj6@cdc.gov",
  "wyw7@cdc.gov"
]
}

locals{
  tags = {
    env = "${lower(var.tags.env)}",
    center = "${lower(var.tags.center)}",
    program = "${lower(var.tags.program)}",
    tenant = "${lower(var.tags.tenant)}",
    poc = "${lower(var.tags.poc)}"
}
}

data "azurerm_client_config" "current" {}

resource "azurerm_storage_account" "storageAccount" {
  name                     = "${lower(var.tags.tenant)}"
  resource_group_name      = var.resourceGroup.name
  location                 = var.resourceGroup.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "RAGRS"
  is_hns_enabled           = "true"
  tags = local.tags
}

resource "azurerm_storage_container" "tenant_container" {
  name                  = var.tags.tenant
  storage_account_name  = azurerm_storage_account.storageAccount.name
  container_access_type = "private"
}

# Query the Principal ID for each user in support_users
data "azuread_user" "user" {
  for_each            = toset(local.admin_users)
  user_principal_name = format("%s", each.key)
}

resource "azurerm_role_assignment" "example" {
  for_each = toset(local.admin_users)
  scope                = azurerm_storage_account.storageAccount.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = data.azuread_user.user[each.key].object_id 
}

resource "azurerm_key_vault" "tenant-kv" {
  name                        = "${lower(var.tags.program)}-${lower(var.tags.tenant)}-${lower(var.tags.env)}"
  location                    = var.resourceGroup.location
  resource_group_name         = var.resourceGroup.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name = "standard"
  tags = local.tags
}

# Query the Principal ID for each user in tenant_users
data "azuread_user" "tenant_user" {
  for_each            = toset(local.tenant_users)
  user_principal_name = format("%s", each.key)
}

resource "azurerm_key_vault_access_policy" "example" {
  for_each = toset(local.tenant_users)
  key_vault_id = azurerm_key_vault.tenant-kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    =  data.azuread_user.tenant_user[each.key].object_id 

  key_permissions = [
    "Get",
  ]

  secret_permissions = [
    "Get", "Delete", "List", "Purge", "Recover", "Restore", "Set"
  ]
}

resource "azurerm_data_factory" "tenant_adf" {
  name                = "${var.tags.program}-${var.tags.tenant}-adf-${var.tags.env}"
  location                 = var.resourceGroup.location
  resource_group_name         = var.resourceGroup.name
  tags = local.tags
}

# Query the Principal ID for each user in support_users
data "azuread_user" "adf_user" {
  for_each            = toset(local.tenant_users)
  user_principal_name = format("%s", each.key)
}

resource "azurerm_role_assignment" "adf_users" {
  for_each = toset(local.tenant_users)
  scope                = azurerm_data_factory.tenant_adf.id
  role_definition_name = "Data Factory Contributor"
  principal_id         = data.azuread_user.adf_user[each.key].object_id 
}
# Configure the Azure provider
#provider "databricks" {}

locals {
  tags = {
    env = "${lower(var.tags.env)}"
    center = "${lower(var.tags.center)}"
    program = "${lower(var.tags.program)}"
    #tenant = "${lower(var.tags.tenant)}"
    poc = "${lower(var.tags.poc)}"
  }
}

resource "azurerm_databricks_workspace" "this" {
  name                     = "${lower(var.tags.program)}-${var.tags.env}"
  resource_group_name      = var.resourceGroup.name
  location                 = var.resourceGroup.location
  sku                         = "premium"
 # managed_resource_group_name = "${lower(var.tags.program)}-${lower(var.tags.tenant)}-${var.tags.env}-rg"
  tags                        = local.tags
  timeouts {
    create = "60m"
    delete = "2h"
  }
}
output "databricks_host" {
  value = "https://${azurerm_databricks_workspace.this.workspace_url}/"
}

provider "databricks" {
   /*azure_workspace_resource_id = azurerm_databricks_workspace.this.id
    azure_client_id             = var.credentials.clientId
    azure_client_secret         = var.credentials.clientSecret
    azure_tenant_id             = var.credentials.tenantId
    azure_subscription_id       = var.credentials.subscriptionId
*/
    profile = "ezdx-onboard"
}
resource "databricks_directory" "tenant_directory" {
  path = "/${upper(var.tags.env)}"
}

locals {
 db_admin_users = [
  #"wyw7@cdc.gov",
  "ggx7@cdc.gov",
  "ygj6@cdc.gov",
  "mcq1@cdc.gov",
  "zfi4@cdc.gov",
  "mcq1@cdc.gov"
  ]
}

locals {
 db_arbonet_dev_users = [
 # "wyw7@cdc.gov"
  ]
}

locals {
 db_arbonet_users = [
  #"mly8@cdc.gov"
  ]
}

locals {
 db_arbonet_ta = [
  /* "lim4@cdc.gov",*/
    "xea6@cdc.gov",
    "frd3@cdc.gov",
    "jjj4@cdc.gov"
  ]
}

#RW
locals {
 db_foodnet_users = [
  "lim4@cdc.gov",
  "wpa8@cdc.gov",
  "nbi9@cdc.gov",
  "lku0@cdc.gov",
  "omx9@cdc.gov"
  ]
}

/* READ Only */
locals {
 db_foodnet_ta = [
  "qki7@cdc.gov",
  "sji6@cdc.gov",
  "mly8@cdc.gov",
  "tcu0@cdc.gov",
  "tcu8@cdc.gov"
  ]
}

data "databricks_group" "admins" {
    display_name = "admins"
}

resource "databricks_user" "db_admin_user" {
  for_each            = toset(local.db_admin_users)
    user_name = format("%s", each.key)
}
resource "databricks_group_member" "admin_member" {
   for_each = toset(local.db_admin_users)
    group_id = data.databricks_group.admins.id
    member_id = databricks_user.db_admin_user[each.key].id  
}

resource "databricks_group" "db_tenant_dev_group" {
  display_name = "${var.tags.tenant}dev"
  allow_cluster_create = false
  allow_instance_pool_create = false
  allow_sql_analytics_access = true
  workspace_access = true
}

resource "databricks_user" "tenant_dev_users" {
  for_each            = toset(local.db_tenant_dev_group)
    user_name = format("%s", each.key)
}

resource "databricks_group_member" "tenant_dev_member" {
   for_each = toset(local.db_tenant_dev_group)
    group_id = databricks_group.db_tenant_dev_group.id
    member_id = databricks_user.tenant_dev_users[each.key].id  
}

resource "databricks_group" "db_tenant_user_group" {
  display_name = "${var.tags.tenant}users"
  allow_cluster_create = false
  allow_instance_pool_create = false
  allow_sql_analytics_access = true
  workspace_access = true
}

resource "databricks_user" "tenant_users" {
  for_each            = toset(local.db_tenant_users)
    user_name = format("%s", each.key)
}

resource "databricks_group_member" "tenant_user_member" {
   for_each = toset(local.db_tenant_users)
    group_id = databricks_group.db_tenant_user_group.id
    member_id = databricks_user.tenant_users[each.key].id  
}

resource "databricks_group" "db_tenant_ta_group" {
  display_name = "${var.tags.tenant}ta"
  allow_cluster_create = false
  allow_instance_pool_create = false
  allow_sql_analytics_access = true
  workspace_access = true
}

resource "databricks_user" "tenant_ta" {
  for_each            = toset(local.db_tenant_ta)
    user_name = format("%s", each.key)
}

resource "databricks_group_member" "tenant_ta_member" {
   for_each = toset(local.db_tenant_ta)
    group_id = databricks_group.db_tenant_ta_group.id
    member_id = databricks_user.tenant_ta[each.key].id  
}

resource "databricks_cluster" "tenant_cluster" {
    cluster_name            = "All_Purpose_${upper(var.tags.env)}_Cluster"
    spark_version           = "10.3.x-scala2.12"
    node_type_id            = "Standard_DS3_v2"
    autotermination_minutes = 60
    autoscale {
        min_workers = 1
        max_workers = 6
    }
}

resource "databricks_permissions" "tenant_user_cluster_usage" {
    cluster_id = databricks_cluster.tenant_cluster.cluster_id
    access_control {
        group_name = databricks_group.db_tenant_user_group.display_name
        permission_level = "CAN_RESTART"
    }
    access_control {
        group_name = databricks_group.db_tenant_ta_group.display_name
        permission_level = "CAN_RESTART"
    }   
}

resource "databricks_sql_endpoint" "this" {
  name = "${var.tags.program}-analytics-${var.tags.env}"
  cluster_size = "Small"
  max_num_clusters = 1

  tags {
    custom_tags {
        key = "tenant"
        value = "${var.tags.tenant}"
    }
  }
}

resource "databricks_permissions" "tenant_user_endpoint_usage" {
    sql_endpoint_id = databricks_sql_endpoint.this.id

    access_control {
        group_name = databricks_group.db_tenant_user_group.display_name
        permission_level = "CAN_USE"
    }
    access_control {
        group_name = databricks_group.db_tenant_ta_group.display_name
        permission_level = "CAN_USE"
    }
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault_access_policy" "this" {
  key_vault_id       = azurerm_key_vault.tenant-kv.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = data.azurerm_client_config.current.object_id
  secret_permissions = ["get", "list", "set"]
}

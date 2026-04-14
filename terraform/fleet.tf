# Fleet Manager — Hubless Mode
# No hub cluster, no CRP — update orchestration only

resource "azurerm_kubernetes_fleet_manager" "fleet" {
  name                = "${var.prefix}-fleet-${local.suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = local.tags
}

# Fleet Members
resource "azurerm_kubernetes_fleet_member" "dev" {
  name                  = "dev"
  kubernetes_fleet_id   = azurerm_kubernetes_fleet_manager.fleet.id
  kubernetes_cluster_id = azurerm_kubernetes_cluster.dev.id
  group                 = "dev-group"
}

resource "azurerm_kubernetes_fleet_member" "staging" {
  name                  = "staging"
  kubernetes_fleet_id   = azurerm_kubernetes_fleet_manager.fleet.id
  kubernetes_cluster_id = azurerm_kubernetes_cluster.staging.id
  group                 = "staging-group"
}

resource "azurerm_kubernetes_fleet_member" "prod" {
  name                  = "prod"
  kubernetes_fleet_id   = azurerm_kubernetes_fleet_manager.fleet.id
  kubernetes_cluster_id = azurerm_kubernetes_cluster.prod.id
  group                 = "prod-group"
}

# Staged Rollout Update Strategy
resource "azurerm_kubernetes_fleet_update_strategy" "staged" {
  name                        = "staged-rollout"
  kubernetes_fleet_manager_id = azurerm_kubernetes_fleet_manager.fleet.id

  stage {
    name = "dev"
    group {
      name = "dev-group"
    }
  }

  stage {
    name                         = "staging"
    after_stage_wait_in_seconds  = 60
    group {
      name = "staging-group"
    }
  }

  stage {
    name                         = "production"
    after_stage_wait_in_seconds  = 120
    group {
      name = "prod-group"
    }
  }
}

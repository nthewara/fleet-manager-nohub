########## AKS Cluster — Dev (Fleet Member)
resource "azurerm_kubernetes_cluster" "dev" {
  name                = "${var.prefix}-aks-dev-${local.suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  dns_prefix          = "${var.prefix}-dev-${local.suffix}"
  kubernetes_version  = var.kubernetes_version
  tags = merge(local.tags, { env = "dev", tier = "non-prod" })

  default_node_pool {
    name                        = "system"
    node_count                  = 2
    vm_size                     = var.node_vm_size
    os_disk_size_gb             = 50
    temporary_name_for_rotation = "systmp"
  }

  identity {
    type = "SystemAssigned"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  }
}

resource "azurerm_role_assignment" "dev_acr" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.dev.kubelet_identity[0].object_id
}

########## AKS Cluster — Staging (Fleet Member)
resource "azurerm_kubernetes_cluster" "staging" {
  name                = "${var.prefix}-aks-stg-${local.suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  dns_prefix          = "${var.prefix}-stg-${local.suffix}"
  kubernetes_version  = var.kubernetes_version
  tags = merge(local.tags, { env = "staging", tier = "non-prod" })

  default_node_pool {
    name                        = "system"
    node_count                  = 2
    vm_size                     = var.node_vm_size
    os_disk_size_gb             = 50
    temporary_name_for_rotation = "systmp"
  }

  identity {
    type = "SystemAssigned"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  }
}

resource "azurerm_role_assignment" "staging_acr" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.staging.kubelet_identity[0].object_id
}

########## AKS Cluster — Production (Fleet Member)
resource "azurerm_kubernetes_cluster" "prod" {
  name                = "${var.prefix}-aks-prod-${local.suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  dns_prefix          = "${var.prefix}-prod-${local.suffix}"
  kubernetes_version  = var.kubernetes_version
  tags = merge(local.tags, { env = "prod", tier = "production" })

  default_node_pool {
    name                        = "system"
    node_count                  = 2
    vm_size                     = var.node_vm_size
    os_disk_size_gb             = 50
    temporary_name_for_rotation = "systmp"
  }

  identity {
    type = "SystemAssigned"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  }
}

resource "azurerm_role_assignment" "prod_acr" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.prod.kubelet_identity[0].object_id
}

########## AKS Cluster — Monitor (NOT fleet-managed — runs Fleet Monitor)
resource "azurerm_kubernetes_cluster" "monitor" {
  name                = "${var.prefix}-aks-monitor-${local.suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  dns_prefix          = "${var.prefix}-mon-${local.suffix}"
  kubernetes_version  = "1.34"
  tags = merge(local.tags, { env = "monitor", tier = "tooling" })

  default_node_pool {
    name                        = "system"
    node_count                  = 1
    vm_size                     = var.monitor_node_vm_size
    os_disk_size_gb             = 50
    temporary_name_for_rotation = "systmp"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "monitor_acr" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.monitor.kubelet_identity[0].object_id
}

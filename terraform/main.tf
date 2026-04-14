resource "random_string" "suffix" {
  length  = 4
  lower   = true
  special = false
  numeric = false
  upper   = false
}

locals {
  suffix = random_string.suffix.result
  tags = {
    project     = "fleet-manager-nohub"
    environment = "demo"
    managed_by  = "terraform"
  }
}

########## Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-${local.suffix}"
  location = var.location
  tags     = local.tags
}

########## Log Analytics Workspace (shared)
resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.prefix}-law-${local.suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

########## Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "${var.prefix}acr${local.suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags
}

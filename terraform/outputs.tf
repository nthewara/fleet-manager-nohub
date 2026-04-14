output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "fleet_name" {
  value = azurerm_kubernetes_fleet_manager.fleet.name
}

output "dev_cluster_name" {
  value = azurerm_kubernetes_cluster.dev.name
}

output "staging_cluster_name" {
  value = azurerm_kubernetes_cluster.staging.name
}

output "prod_cluster_name" {
  value = azurerm_kubernetes_cluster.prod.name
}

output "monitor_cluster_name" {
  value = azurerm_kubernetes_cluster.monitor.name
}

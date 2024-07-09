output "resource_group_name" {
  value = azurerm_resource_group.mb-crdb-multi-region.name
}

output "kubernetes_cluster_name_region_1" {
  value = azurerm_kubernetes_cluster.aks_region_1.name
}

output "kube_config_region_1" {
  value = azurerm_kubernetes_cluster.aks_region_1.kube_config_raw
  sensitive = true
}

output "client_certificate_region_1" {
  value     = azurerm_kubernetes_cluster.aks_region_1.kube_config.client_certificate
  sensitive = true
}

output "client_key_region_1" {
  value     = azurerm_kubernetes_cluster.aks_region_1.kube_config.client_key
  sensitive = true
}

output "cluster_ca_certificate_region_1" {
  value     = azurerm_kubernetes_cluster.aks_region_1.kube_config.cluster_ca_certificate
  sensitive = true
}

output "cluster_password_region_1" {
  value     = azurerm_kubernetes_cluster.aks_region_1.kube_config.password
  sensitive = true
}

output "cluster_username_region_1" {
  value     = azurerm_kubernetes_cluster.aks_region_1.kube_config.username
  sensitive = true
}

output "host_region_1" {
  value     = azurerm_kubernetes_cluster.aks_region_1.kube_config.host
  sensitive = true
}

output "crdb_namespace_region_1" {
  value     = kubernetes_namespace_v1.ns_region_1.metadata.name
}
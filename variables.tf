variable "prefix" {
  description = "A prefix used for all resources in this example"
}

variable "location_1" {
  description = "The Azure Region in which all resources in this example should be provisioned"
}

variable "location_1_vnet_address_space" {
  description = "The Azure VNET address space for first location"
  default = ["10.1.0.0/16"]
}


variable "location_1_aks_subnet" {
  description = "The Azure VNET address space for first location"
  default = ["10.1.0.0/22"]
}

variable "aks_pool_name" {
  description = "The Azure Region in which all resources in this example should be provisioned"
  default = "nodepool"
}

variable "aks_vm_size" {
  description = "The Azure Region in which all resources in this example should be provisioned"
  default = "Standard_D8s_v3"
}

variable "aks_node_count" {
  description = "The Azure Region in which all resources in this example should be provisioned"
  default = 3
}

variable "cockroachdb_version" {
  description = "The Azure Region in which all resources in this example should be provisioned"
  default = "v23.2.5"
}

variable "cockroachdb_pod_cpu" {
  description = "The Azure Region in which all resources in this example should be provisioned"
  default = "4"
}

variable "cockroachdb_pod_memory" {
  description = "The Azure Region in which all resources in this example should be provisioned"
  default = "8Gi"
}

variable "cockroachdb_storage" {
  description = "The Azure Region in which all resources in this example should be provisioned"
  default = "50Gi"
}

variable "statfulset_replicas" {
  description = "The Azure Region in which all resources in this example should be provisioned"
  default = 3
}
# CockroachDB Azure AKS Region Terraform Module

## Usage

```
module "my_cockroachdb_region_1" {
  source = "github.com/mbookham7/crdb-aks-region-tf-module.git"

  location_1 = "uksouth"
  prefix = "mb-crdb-sr"
  aks_node_count = 6
  cockroachdb_pod_cpu = "8"
  cockroachdb_pod_memory = "16Gi"
  aks_vm_size = "Standard_D16s_v3"

}

#####################################
# Azure Infrastructure              #
#####################################

### Creation of VNET in three regions with a single subnet.

# Create a Azure Resource Group for all other resources.

resource "azurerm_resource_group" "mb-crdb-multi-region" {
  name     = "${var.prefix}-k8s-resources"
  location = var.location_1
}

# Create VNET

resource "azurerm_virtual_network" "region_1" {
  name                = "${var.prefix}-${var.location_1}"
  location            = var.location_1
  resource_group_name = azurerm_resource_group.mb-crdb-multi-region.name
  address_space       = var.location_1_vnet_address_space
}

# Create subnet

resource "azurerm_subnet" "internal-region_1" {
  name                 = "internal-${var.location_1}"
  virtual_network_name = azurerm_virtual_network.region_1.name
  resource_group_name  = azurerm_resource_group.mb-crdb-multi-region.name
  address_prefixes     = var.location_1_aks_subnet
}

### Identity
resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-aks-cac-001"
  resource_group_name = azurerm_resource_group.mb-crdb-multi-region.name
  location            = var.location_1
}

resource "azurerm_role_assignment" "network_contributor_region_1" {
  scope                = azurerm_virtual_network.region_1.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

### AKS Cluster Creation
resource "azurerm_kubernetes_cluster" "aks_region_1" {
  name                = "${var.prefix}-k8s-${var.location_1}"
  location            = var.location_1
  resource_group_name = azurerm_resource_group.mb-crdb-multi-region.name
  dns_prefix          = "${var.prefix}-k8s"

  default_node_pool {
    name           = var.aks_pool_name
    node_count     = var.aks_node_count
    vm_size        = var.aks_vm_size
    vnet_subnet_id = azurerm_subnet.internal-region_1.id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  network_profile {
    network_plugin = "azure"
  }
}


#####################################
# tls                               #
#####################################

#######################################################################
# Create Certificates and upload these as secrets to each cluster     #
#######################################################################

# Create a CA Certificate and Key

# Key
resource "tls_private_key" "ca_private_key" {
  algorithm = "RSA"
}

resource "local_file" "ca_key" {
  content  = tls_private_key.ca_private_key.private_key_pem
  filename = "${path.module}/my-safe-directory/ca.key"
}

# Certificate

resource "tls_self_signed_cert" "ca_cert" {
  private_key_pem = tls_private_key.ca_private_key.private_key_pem

  is_ca_certificate = true

  subject {
    common_name         = "Cockroach CA"
    organization        = "Cockroach"
  }

  validity_period_hours = 8760 //  365 days or 1 years

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "client_auth",
    "server_auth",
    "cert_signing",
    "crl_signing",
  ]
}

# Output as a file for retention

resource "local_file" "ca_cert" {
  content  = tls_self_signed_cert.ca_cert.cert_pem
  filename = "${path.module}/certs/ca.crt"
}

resource "local_file" "ca_cert_region_1" {
  content  = tls_self_signed_cert.ca_cert.cert_pem
  filename = "${path.module}/certs/${var.location_1}/ca.crt"
}


# Create a Client certificate and ket for the first user

# Key
resource "tls_private_key" "client_private_key" {
  algorithm = "RSA"
}

# Output as a file for retention

resource "local_file" "client_key" {
  content  = tls_private_key.client_private_key.private_key_pem
  filename = "${path.module}/certs/client.root.key"
}

# Create CSR for for server certificate 
resource "tls_cert_request" "cert_client_csr" {

  private_key_pem = tls_private_key.client_private_key.private_key_pem

  dns_names = [
    "root",
    ]

  subject {
    common_name         = "root"

  }
}

# Sign Server Certificate by Private CA 
resource "tls_locally_signed_cert" "client_cert" {
  // CSR by the region_1 nodes
  cert_request_pem = tls_cert_request.cert_client_csr.cert_request_pem
  // CA Private key 
  ca_private_key_pem = tls_private_key.ca_private_key.private_key_pem
  // CA certificate
  ca_cert_pem = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "client_auth",
  ]
}

resource "local_file" "client_cert" {
  content  = tls_locally_signed_cert.client_cert.cert_pem
  filename = "${path.module}/certs/client.root.crt"
}

# Create Certificate and key for nodes in each region

# Create private key for server certificate 
resource "tls_private_key" "node_cert_region_1" {
  algorithm = "RSA"
}

# Output as a file for retention

resource "local_file" "node_cert_region_1_key" {
  content  = tls_private_key.node_cert_region_1.private_key_pem
  filename = "${path.module}/certs/${var.location_1}/node.key"
}


# Create CSR for for server certificate 
resource "tls_cert_request" "node_cert_region_1_csr" {

  private_key_pem = tls_private_key.node_cert_region_1.private_key_pem

  dns_names = [
    "localhost",
    "127.0.0.1",
    "cockroachdb-public",
    "cockroachdb-public.${var.location_1}",
    "cockroachdb-public.${var.location_1}.svc.cluster.local",
    "*.cockroachdb",
    "*.cockroachdb.${var.location_1}",
    "*.cockroachdb.${var.location_1}.svc.cluster.local"
    ]

  subject {
    common_name         = "node"
  }
}

# Sign Server Certificate by Private CA 
resource "tls_locally_signed_cert" "node_cert_region_1" {
  // CSR by the region_1 nodes
  cert_request_pem = tls_cert_request.node_cert_region_1_csr.cert_request_pem
  // CA Private key 
  ca_private_key_pem = tls_private_key.ca_private_key.private_key_pem
  // CA certificate
  ca_cert_pem = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}

# Output as a file for retention

resource "local_file" "node_cert_region_1_cert" {
  content  = tls_locally_signed_cert.node_cert_region_1.cert_pem
  filename = "${path.module}/certs/${var.location_1}/node.crt"
}

# Upload Certificates as secrets to kubernetes

# Upload CA Cert and Key as a Secret to each cluster

resource "kubernetes_secret_v1" "cockroachdb_client_root_region_1" {
  metadata {
    name = "cockroachdb.client.root"
    namespace = var.location_1
  }

  data = {
    "ca.crt" = tls_self_signed_cert.ca_cert.cert_pem
    "client.root.crt" = tls_locally_signed_cert.client_cert.cert_pem
    "client.root.key" = tls_private_key.client_private_key.private_key_pem
  }
}

# Upload Node Cert and Key as a Secret to each cluster

resource "kubernetes_secret_v1" "cockroachdb_node_region_1" {
  metadata {
    name = "cockroachdb.node"
    namespace = var.location_1
  }

  data = {
    "ca.crt" = tls_self_signed_cert.ca_cert.cert_pem
    "node.crt" = tls_locally_signed_cert.node_cert_region_1.cert_pem
    "node.key" = tls_private_key.node_cert_region_1.private_key_pem
  }
}

#########################################
# Deploy CockroachDB                    #
#########################################

### Create the namespaces based on the region names

# Create namespace in first region

resource "kubernetes_namespace_v1" "ns_region_1" {
  metadata {
    name = var.location_1

    annotations = {
      name = "CockroachDB Namespace"
    }

    labels = {
      app = "cockroachdb"
    }
  }
}

### Apply the StatefulSet manifests updated with the required regions.

# Region 1

resource "kubernetes_service_account_v1" "serviceaccount_cockroachdb_region_1" {
  depends_on = [kubernetes_namespace_v1.ns_region_1]
  metadata {
    name = "cockroachdb"

    labels = {
      app = "cockroachdb"
    }
    namespace = var.location_1
  }
}

resource "kubernetes_role_v1" "role_cockroachdb_region_1" {
  depends_on = [kubernetes_namespace_v1.ns_region_1]
  metadata {
    name = "cockroachdb"

    labels = {
      app = "cockroachdb"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "create"]
  }
}

resource "kubernetes_cluster_role_v1" "clusterrole_cockroachdb_region_1" {
  depends_on = [kubernetes_namespace_v1.ns_region_1] 
  metadata {
    name = "cockroachdb"
    labels = {
      app = "cockroachdb"
    }
  }

  rule {
    api_groups = ["certificates.k8s.io"]
    resources  = ["certificatesigningrequests"]
    verbs      = ["get", "create", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "rolebinding_cockroachdb_region_1" {
  depends_on = [kubernetes_namespace_v1.ns_region_1]
  metadata {
    name      = "cockroachdb"
    namespace = var.location_1
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "cockroachdb"
  }
  subject {
    kind      = "User"
    name      = "admin"
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "cockroachdbdefault"
    namespace = var.location_1
  }
}

resource "kubernetes_cluster_role_binding_v1" "clusterrolebinding_cockroachdb_region_1" {
  depends_on = [kubernetes_namespace_v1.ns_region_1]
  metadata {
    name = "cockroachdb"
    labels = {
      app = "cockroachdb"
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cockroachdb"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "cockroachdb"
    namespace = var.location_1
  }
  subject {
    kind      = "Group"
    name      = "system:masters"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_service" "service_cockroachdb_public_region_1" {
  depends_on = [kubernetes_namespace_v1.ns_region_1]
  metadata {
    name = "cockroachdb-public"
    labels = {
      app = "cockroachdb"
    }
    namespace = var.location_1
  }
  spec {
    selector = {
      app = "cockroachdb"
    }
    port {
      name        = "grpc"
      port        = 26257
      target_port = 26257
    }
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }
  }
}

resource "kubernetes_service" "service_cockroachdb_region_1" {
  depends_on = [kubernetes_namespace_v1.ns_region_1]
  metadata {
    name = "cockroachdb"
    labels = {
      app = "cockroachdb"
    }
    annotations = {
        "prometheus.io/path" = "_status/vars"
        "prometheus.io/port" = "8080"
        "prometheus.io/scrape" = "true"
        "service.alpha.kubernetes.io/tolerate-unready-endpoints" = "true"
    }
    namespace = var.location_1
  }
  spec {
    selector = {
      app = "cockroachdb"
    }
    port {
      name        = "grpc"
      port        = 26257
      target_port = 26257
    }
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }
    type = "ClusterIP"
    publish_not_ready_addresses = "true"
  }
}

resource "kubernetes_pod_disruption_budget_v1" "poddisruptionbudget_cockroachdb_budget_region_1" {
  depends_on = [kubernetes_namespace_v1.ns_region_1]
  metadata {
    name = "cockroachdb-budget"
    labels = {
      app = "cockroachdb"
    }
    namespace = var.location_1
  }
  spec {
    max_unavailable = 1
    selector {
      match_labels = {
        app = "cockroachdb"
      }
    }
  }
}

resource "kubernetes_stateful_set_v1" "statefulset_region_1_cockroachdb" {
  depends_on = [kubernetes_namespace_v1.ns_region_1]
  metadata {
    annotations = {
    }

    labels = {
    }

    name = "cockroachdb"
    namespace = var.location_1
  }

  spec {
    pod_management_policy  = "Parallel"
    replicas               = var.statfulset_replicas

    selector {
      match_labels = {
        app = "cockroachdb"
      }
    }

    service_name = "cockroachdb"

    template {
      metadata {
        labels = {
          app = "cockroachdb"
        }

        annotations = {}
      }

      spec {

        affinity {
          pod_anti_affinity {
              preferred_during_scheduling_ignored_during_execution {
                weight = 100 

                pod_affinity_term {
                  label_selector {
                    match_expressions {
                      key      = "app"
                      operator = "In"
                      values   = ["cockroachdb"]
                    }
                  }
                  topology_key = "kubernetes.io/hostname"
                }
              }
            }
        }

        container {
          command = [
            "/bin/bash",
            "-ecx",
            "exec /cockroach/cockroach start --logtostderr --certs-dir /cockroach/cockroach-certs --advertise-host $(hostname -f) --http-addr 0.0.0.0 --join cockroachdb-0.cockroachdb.${var.location_1},cockroachdb-1.cockroachdb.${var.location_1} --locality=cloud=azure,region=azure-${var.location_1} --cache $(expr $MEMORY_LIMIT_MIB / 4)MiB --max-sql-memory $(expr $MEMORY_LIMIT_MIB / 4)MiB",
            ]

          env {
            name = "COCKROACH_CHANNEL"
            value = "kubernetes-multiregion"            
          }

          env {
            name = "GOMAXPROCS"


            value_from {
              resource_field_ref {
                divisor = 1
                resource = "limits.cpu"
              }
            }
          }

          env {
            name = "MEMORY_LIMIT_MIB"


            value_from {
              resource_field_ref {
                divisor = "1Mi"
                resource = "limits.memory"
              }
            }           
          }

          name              = "cockroachdb"
          image             = "cockroachdb/cockroach:${var.cockroachdb_version}"
          image_pull_policy = "IfNotPresent"

          port {
            name = "grcp"
            container_port = 26257
          }
          port {
            name = "http"
            container_port = 8080
          }

          readiness_probe {
            failure_threshold = 2
              http_get {
                path = "/health?ready=1"
                port = "http"
                scheme = "HTTPS"
              }

            initial_delay_seconds = 10
            period_seconds = 5
          }

          resources {
            limits = {
              cpu    = var.cockroachdb_pod_cpu
              memory = var.cockroachdb_pod_memory
            }

            requests = {
              cpu    = var.cockroachdb_pod_cpu
              memory = var.cockroachdb_pod_memory
            }
          }
        
          volume_mount {
            name       = "datadir"
            mount_path = "/cockroach/cockroach-data"
          }

          volume_mount {
            name       = "certs"
            mount_path = "/cockroach/cockroach-certs"
          }

          volume_mount {
            name       = "cockroach-env"
            mount_path = "/etc/cockroach-env"
          }
        }


        service_account_name = "cockroachdb"

        termination_grace_period_seconds = 60

        volume {
          name = "datadir"

          persistent_volume_claim {
            claim_name = "datadir"
          }
        }
        volume {
          name = "certs"

          secret {
            default_mode = "0400"
            secret_name = "cockroachdb.node"
          }
        }
        volume {
          name = "cockroach-env"
          empty_dir {}
        }
      }
    }

    update_strategy {
      type = "RollingUpdate"

      rolling_update {
        partition = 1
      }
    }

    volume_claim_template {
      metadata {
        name = "datadir"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]

        resources {
          requests = {
            storage = var.cockroachdb_storage
          }
        }
      }
    }
  }
}

### Expose the Admin UI externally.

resource "kubernetes_service" "service_cockroachdb_ui_region_1" {
  depends_on = [kubernetes_namespace_v1.ns_region_1]
  metadata {
    name = "cockroachdb-adminui"
    labels = {
      app = "cockroachdb"
    }
    namespace = var.location_1
  }
  spec {
    selector = {
      app = "cockroachdb"
    }
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }
        type = "LoadBalancer"
  }
}

#########################################
# Cluster Initalisation                 #
#########################################


resource "time_sleep" "wait_120_seconds" {
  depends_on = [kubernetes_service.service_cockroachdb_public_region_1, kubernetes_namespace_v1.ns_region_1 ]
  create_duration = "120s"
}

resource "kubernetes_job_v1" "cockroachdb_init_job" {
  depends_on = [time_sleep.wait_120_seconds]
    metadata {
      name = "cockroachdb-client-secure"

      labels = {
        app = "cockroachdb-client"
      }
      
      namespace = var.location_1
    }
    spec {
      template {
      metadata {}
        spec {
          container {
            command = ["/cockroach/cockroach", "init", "--certs-dir=/cockroach-certs", "--host=cockroachdb-0.cockroachdb.${var.location_1}"]
            image = "cockroachdb/cockroach:${var.cockroachdb_version}"
            image_pull_policy  = "IfNotPresent"
            name = "cockroachdb-client"
            volume_mount {
                mount_path = "/cockroach-certs"
                name = "client-certs"
            }
        }
          service_account_name = "cockroachdb"
          termination_grace_period_seconds = 0
          volume {
            name = "client-certs"
            secret {
              default_mode = "0400"
              secret_name = "cockroachdb.client.root"
            }
          }
        }
      }
    }
}

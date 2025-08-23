terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.6.0"   
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.33.0"
    }
  }
  required_version = ">= 1.12.2"
}

# KIND Cluster definition
resource "kind_cluster" "devops_cluster" {
  name = var.cluster_name

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    # First control plane with ingress port mappings
    node {
      role = "control-plane"

      # Map host:80 -> container:80 (HTTP)
      extra_port_mappings {
        container_port = 80
        host_port      = 80
        protocol       = "TCP"
      }

      # Map host:443 -> container:443 (HTTPS)
      extra_port_mappings {
        container_port = 443
        host_port      = 443
        protocol       = "TCP"
      }
    }

    # Additional control planes
    dynamic "node" {
      for_each = range(var.control_plane_count - 1)
      content {
        role = "control-plane"
      }
    }

    # App workers
    dynamic "node" {
      for_each = range(var.app_worker_count)
      content {
        role = "worker"
        labels = {
          "role" = "app"
        }
      }
    }

    # Mongo workers
    dynamic "node" {
      for_each = range(var.mongo_worker_count)
      content {
        role = "worker"
        labels = {
          "role" = "mongo"
        }
      }
    }
  }
}

# Output kubeconfig path for kubectl (optional)
# output "kubeconfig_path" {
#   value = kind_cluster.devops_cluster.kubeconfig_path
# }

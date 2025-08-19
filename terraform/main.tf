terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.6.0"   # compatible with your kind v0.29.0
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

    # First control plane
    node {
      role = "control-plane"
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

# Output kubeconfig path for kubectl
# output "kubeconfig_path" {
#  value = kind_cluster.devops_cluster.kubeconfig_path
#}

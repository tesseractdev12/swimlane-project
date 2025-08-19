output "cluster_name" {
  description = "The name of the Kind cluster"
  value       = kind_cluster.devops_cluster.name
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = kind_cluster.devops_cluster.kubeconfig_path
}

output "kubeconfig" {
  description = "Kubeconfig content"
  value       = kind_cluster.devops_cluster.kubeconfig
  sensitive   = true
}

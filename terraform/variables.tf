variable "cluster_name" {
  type    = string
  default = "devops-cluster"
}

variable "control_plane_count" {
  type    = number
  default = 2
}

variable "app_worker_count" {
  type    = number
  default = 2
}

variable "mongo_worker_count" {
  type    = number
  default = 2
}

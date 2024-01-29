variable "cluster_name" { type = string }
variable "cluster_version" { type = string }
variable "cluster_cidr" { type = string }
variable "cluster_endpoint_public_access" { type = bool }

# Resources

variable "cluster_log_retention_days" {
  type        = number
  description = "Number of days to retain cluster logs"
}
variable "container_log_retention_days" {
  type        = number
  description = "Number of days to retain container logs"
}

variable "cluster_ec2_instance_type" {
  type        = string
  description = "EC2 instance type for cluster nodes"
}
variable "cluster_nodes_count" {
  type        = number
  description = "Number of cluster nodes"
}

# Versions

variable "aws_for_fluent_bit_helm_chart_version" { type = string }
variable "aws_load_balancer_controller_helm_chart_version" { type = string }

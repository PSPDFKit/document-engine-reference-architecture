# Document Engine

variable "document_engine" {
  description = "Document Engine parameters"
  type = object({
    activation_key     = string
    logging_level      = string
    namespace_name     = string
    helm_release_name  = string
    helm_chart_version = string
  })
}

# AWS

variable "aws_profile_name" {
  type    = string
  default = "default"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "eu-north-1"
}

# Names 

variable "additional_tags" {
  type        = map(string)
  description = "Additional resource tags"
  default     = {}
}

variable "environment_name" {
  type        = string
  description = "Environment name to use all over the place"
}

# Resources

variable "cluster_cidr" {
  type        = string
  description = "Cluster CIDR"
}

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

variable "cluster_version" {
  type        = string
  description = "Kubernetes version for the EKS cluster"
}
variable "aws_for_fluent_bit_helm_chart_version" {
  type        = string
  description = "Helm chart version for AWS for Fluent Bit"
}
variable "aws_load_balancer_controller_helm_chart_version" {
  type        = string
  description = "Helm chart version for AWS Load Balancer Controller"
}

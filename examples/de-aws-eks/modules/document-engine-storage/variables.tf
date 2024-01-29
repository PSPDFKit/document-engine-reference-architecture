variable "cluster_info" {
  type        = map(string)
  description = "EKS cluster information, to pass from the EKS module"
}
variable "cluster_vpc_info" {
  type = object({
    vpc_id                    = string
    private_subnets           = list(string)
    public_subnets            = list(string)
    primary_security_group_id = string
    node_security_group_id    = string
    db_subnet_group_name      = string
  })
  description = "EKS cluster VPC information, to pass from the EKS module"
}

locals {
  cluster_name                       = var.cluster_info["cluster_name"]
  cluster_version                    = var.cluster_info["cluster_version"]
  cluster_oidc_provider_arn          = var.cluster_info["cluster_oidc_provider_arn"]
  cluster_endpoint                   = var.cluster_info["cluster_endpoint"]
  cluster_certificate_authority_data = var.cluster_info["cluster_certificate_authority_data"]
  containers_log_group_prefix_ec2    = var.cluster_info["containers_log_group_prefix_ec2"]
}

variable "database_properties" {
  type = object({
    identifier                   = string
    publicly_accessible          = bool
    username                     = string
    db_name                      = string
    postgres_engine_version      = string
    postgres_parameter_family    = string
    ec2_instance_type            = string
    preferred_maintenance_window = string
  })
  description = "RDS database properties"
}

variable "database_password" {
  type        = string
  sensitive   = true
  description = "RDS database password"
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.cluster_eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.cluster_eks.cluster_arn
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.cluster_eks.cluster_endpoint
}

output "cluster_vpc_id" {
  description = "EKS cluster VPC id"
  value       = module.cluster_vpc.vpc_id
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster authority data"
  value       = module.cluster_eks.cluster_certificate_authority_data
}

output "kubeconfig_command" {
  description = "Getting `.kubeconfig` command for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${local.aws_region_name} --name ${var.cluster_name} --kubeconfig .kubeconfig"
}

output "cluster_info" {
  description = "Consolidated EKS cluster information"
  value = {
    cluster_name                       = module.cluster_eks.cluster_name
    cluster_arn                        = module.cluster_eks.cluster_arn
    cluster_oidc_provider_arn          = module.cluster_eks.oidc_provider_arn
    cluster_oidc_provider              = module.cluster_eks.oidc_provider
    cluster_endpoint                   = module.cluster_eks.cluster_endpoint
    cluster_version                    = module.cluster_eks.cluster_version
    cluster_certificate_authority_data = module.cluster_eks.cluster_certificate_authority_data
    containers_log_group_prefix_ec2    = local.containers_log_group_prefix_ec2
  }
}

output "cluster_vpc_info" {
  description = "Consolidated EKS cluster VPC information"
  value = {
    vpc_id                    = module.cluster_vpc.vpc_id
    private_subnets           = module.cluster_vpc.private_subnets
    public_subnets            = module.cluster_vpc.public_subnets
    primary_security_group_id = module.cluster_eks.cluster_primary_security_group_id
    node_security_group_id    = module.cluster_eks.node_security_group_id
    db_subnet_group_name      = aws_db_subnet_group.cluster.name
  }
}

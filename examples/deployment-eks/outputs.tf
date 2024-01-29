output "cluster_name" {
  description = "EKS cluster name"
  value       = module.kubernetes_cluster.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.kubernetes_cluster.cluster_arn
}

output "cluster_endpoint" {
  value = module.kubernetes_cluster.cluster_endpoint
}

output "cluster_vpc_id" {
  value = module.kubernetes_cluster.cluster_vpc_id
}

output "kubeconfig_command" {
  description = "Getting `.kubeconfig` command"
  value       = module.kubernetes_cluster.kubeconfig_command
}

output "cluster_info" {
  description = "EKS cluster information"
  value       = module.kubernetes_cluster.cluster_info
}

output "cluster_vpc_info" {
  description = "VPC information"
  value       = module.kubernetes_cluster.cluster_vpc_info
}

output "document_engine_url" {
  value = "http://${data.aws_lb.document_engine.dns_name}"
}


locals {
  default_tags = merge(
    var.additional_tags,
    {
      Environment = var.environment_name
    }
  )

  cluster_tags = {
    Component = "cluster"
  }

  cluster_name = "${var.environment_name}-${random_string.cluster_suffix.result}"

  environment_title = replace(title(var.environment_name), "-", " ")
}

resource "random_string" "cluster_suffix" {
  length  = 8
  special = false
}

module "kubernetes_cluster" {
  source                                          = "./modules/eks-cluster"
  cluster_name                                    = local.cluster_name
  cluster_endpoint_public_access                  = true
  cluster_version                                 = var.cluster_version
  cluster_cidr                                    = var.cluster_cidr
  cluster_ec2_instance_type                       = var.cluster_ec2_instance_type
  cluster_nodes_count                             = var.cluster_nodes_count
  cluster_log_retention_days                      = var.container_log_retention_days
  container_log_retention_days                    = var.container_log_retention_days
  aws_for_fluent_bit_helm_chart_version           = var.aws_for_fluent_bit_helm_chart_version
  aws_load_balancer_controller_helm_chart_version = var.aws_load_balancer_controller_helm_chart_version
}

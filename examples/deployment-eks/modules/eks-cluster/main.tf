#
# EKS
#
# https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
# https://github.com/terraform-aws-modules/terraform-aws-eks
# 
locals {
  #
  # Cluster log group name is hardcoded: https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/main.tf#L115
  # So we follow the pattern
  #
  containers_log_group_prefix_ec2 = "/aws/eks/${var.cluster_name}/ec2"
}

module "cluster_eks" {
  source = "terraform-aws-modules/eks/aws"

  cluster_name                   = var.cluster_name
  cluster_version                = var.cluster_version
  cluster_endpoint_public_access = var.cluster_endpoint_public_access

  create_kms_key            = true
  manage_aws_auth_configmap = true
  aws_auth_accounts         = []
  aws_auth_users            = []
  aws_auth_roles            = []

  cluster_addons = {
    kube-proxy = { most_recent = true }
    coredns    = { most_recent = true }
    vpc-cni = {
      most_recent              = true
      before_compute           = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
    }
  }

  vpc_id                   = module.cluster_vpc.vpc_id
  subnet_ids               = module.cluster_vpc.private_subnets
  control_plane_subnet_ids = module.cluster_vpc.intra_subnets

  cloudwatch_log_group_kms_key_id        = aws_kms_key.cluster_eks_logs.arn
  cloudwatch_log_group_retention_in_days = var.cluster_log_retention_days

  eks_managed_node_group_defaults = local.eks_managed_node_group_defaults
  eks_managed_node_groups         = local.eks_managed_node_groups

  tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}

module "vpc_cni_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "${var.cluster_name}-AmazonEKS-VPC-CNI-Role"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true
  vpc_cni_enable_ipv6   = false

  oidc_providers = {
    ex = {
      provider_arn               = module.cluster_eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
  tags = {}
}

#
# VPC
#
# https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
# https://github.com/terraform-aws-modules/terraform-aws-vpc
#
module "cluster_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.cluster_name}-vpc"
  cidr = var.cluster_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.cluster_cidr, 8, k + 1)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.cluster_cidr, 8, k + 101)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(var.cluster_cidr, 8, k + 201)]

  create_igw             = true
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_flow_log = false

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = 1
    "karpenter.sh/discovery"                    = var.cluster_name
  }
}

resource "aws_db_subnet_group" "cluster" {
  name_prefix = "${lower(var.cluster_name)}-db-subnet-group"
  subnet_ids  = module.cluster_vpc.private_subnets
  tags = {
    Name = "${var.cluster_name}-db-subnet-group"
  }
}

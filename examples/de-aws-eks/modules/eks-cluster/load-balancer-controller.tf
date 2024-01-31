#
# https://github.com/aws/eks-charts/tree/master/stable/aws-load-balancer-controller
# https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
# https://github.com/terraform-aws-modules/terraform-aws-iam/blob/master/examples/iam-role-for-service-accounts-eks/main.tf
#

locals {
  load_balancer_controller_service_account_name = "aws-load-balancer-controller"
  load_balancer_controller_namespace            = "kube-system"
}

module "load_balancer_controller_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "${var.cluster_name}-AmazonEKS-LoadBalancerController-Role"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn = module.cluster_eks.oidc_provider_arn
      namespace_service_accounts = [
        "${local.load_balancer_controller_namespace}:${local.load_balancer_controller_service_account_name}"
      ]
    }
  }

  tags = {}
}

resource "helm_release" "aws-load-balancer-controller" {
  depends_on = [module.cluster_eks]

  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  name             = "aws-load-balancer-controller"
  version          = var.aws_load_balancer_controller_helm_chart_version
  namespace        = "kube-system"
  create_namespace = false
  values = [
    templatefile("${path.module}/load-balancer-controller.values.yaml.tftpl", {
      service_account_name     = local.load_balancer_controller_service_account_name
      service_account_role_arn = module.load_balancer_controller_irsa_role.iam_role_arn
      aws_region               = local.aws_region_name
      cluster_name             = var.cluster_name
      vpc_id                   = module.cluster_vpc.vpc_id
      default_tags             = yamlencode(local.default_tags)
      checksum_values          = filemd5("${path.module}/load-balancer-controller.values.yaml.tftpl")
      checksum_code            = filemd5("${path.module}/load-balancer-controller.tf")
    })
  ]
}

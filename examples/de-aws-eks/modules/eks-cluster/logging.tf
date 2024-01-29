#
# https://github.com/aws/eks-charts/blob/master/stable/aws-for-fluent-bit/README.md
#
resource "helm_release" "aws-for-fluent-bit" {
  depends_on = [module.cluster_eks]

  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-for-fluent-bit"
  name             = "aws-for-fluent-bit"
  version          = var.aws_for_fluent_bit_helm_chart_version
  namespace        = "kube-system"
  create_namespace = false
  values = [
    templatefile("${path.module}/logging-ec2_fluentbit.values.yaml.tftpl",
      {
        aws_region         = local.aws_region_name
        log_group_prefix   = local.containers_log_group_prefix_ec2
        log_stream_prefix  = "k-"
        log_retention_days = var.container_log_retention_days
        checksum_values    = filemd5("${path.module}/logging-ec2_fluentbit.values.yaml.tftpl")
        checksum_code      = filemd5("${path.module}/logging.tf")
      }
    )
  ]
}

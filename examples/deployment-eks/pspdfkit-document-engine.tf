resource "kubernetes_namespace" "document_engine" {
  metadata {
    name = var.document_engine.namespace_name
    labels = {
      "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
    }
  }
}

resource "helm_release" "document_engine" {
  depends_on = [module.kubernetes_cluster]

  repository       = "https://pspdfkit.github.io/helm-charts"
  chart            = "document-engine"
  name             = var.document_engine.helm_release_name
  version          = var.document_engine.helm_chart_version
  namespace        = kubernetes_namespace.document_engine.metadata[0].name
  create_namespace = false
  values = [
    templatefile("${path.module}/pspdfkit-document-engine.values.yaml.tftpl",
      {
        activation_key  = var.document_engine.activation_key
        log_level       = var.document_engine.logging_level
        db_host         = module.document_engine_storage.rds_hostname
        db_port         = module.document_engine_storage.rds_port
        db_name         = local.document_engine_db_name
        db_username     = module.document_engine_storage.rds_username
        db_password     = local.document_engine_db_password
        release_name    = var.document_engine.helm_release_name
        checksum_values = filemd5("${path.module}/pspdfkit-document-engine.values.yaml.tftpl")
        checksum_code   = filemd5("${path.module}/pspdfkit-document-engine.tf")
      }
    )
  ]
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [helm_release.document_engine]

  create_duration = "30s"
}

data "aws_lbs" "document_engine" {
  depends_on = [time_sleep.wait_30_seconds]

  tags = {
    "elbv2.k8s.aws/cluster" = local.cluster_name
    "ingress.k8s.aws/stack" = "${var.document_engine.namespace_name}/${var.document_engine.helm_release_name}"
  }
}

data "aws_lb" "document_engine" {
  arn = tolist(data.aws_lbs.document_engine.arns)[0]
}

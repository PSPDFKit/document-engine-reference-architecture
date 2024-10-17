resource "kubernetes_namespace" "document_engine" {
  metadata {
    name = var.document_engine.namespace_name
  }
}

resource "helm_release" "document_engine" {
  repository       = "https://pspdfkit.github.io/helm-charts"
  chart            = "document-engine"
  name             = var.document_engine.helm_release_name
  version          = var.document_engine.helm_chart_version
  namespace        = kubernetes_namespace.document_engine.metadata[0].name
  create_namespace = false
  values = [
    templatefile("${path.module}/pspdfkit-document-engine.values.yaml.tftpl",
      {
        activation_key       = var.document_engine.activation_key
        log_level            = var.document_engine.logging_level
        hostname             = var.document_engine_hostname
        db_host              = "${var.document_engine.helm_release_name}-postgresql.${var.document_engine.namespace_name}.svc.cluster.local"
        db_name              = "pspdfkit"
        db_postgres_password = "despair"
        release_name         = var.document_engine.helm_release_name
        jwt_public_key  = file("${path.module}/jwt-public-key.pem")
        checksum_values      = filemd5("${path.module}/pspdfkit-document-engine.values.yaml.tftpl")
        checksum_code        = filemd5("${path.module}/pspdfkit-document-engine.tf")
      }
    )
  ]
}

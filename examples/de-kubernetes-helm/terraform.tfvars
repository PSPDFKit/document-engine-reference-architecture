# Kubernetes

kubernetes_config_path = "~/.kube/config"

# Document Engine

document_engine_hostname = "document-engine.pspdfkit.local"

document_engine = {
  activation_key     = ""
  logging_level      = "debug"
  namespace_name     = "pspdfkit-document-engine"
  helm_release_name  = "document-engine"
  helm_chart_version = "0.1.7"
}

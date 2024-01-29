# Kubernetes
variable "kubernetes_config_path" {
  description = "Kubernetes config path"
  type        = string
}

variable "kubernetes_config_context" {
  description = "Kubernetes config context"
  type        = string
}

# Document Engine

variable "document_engine_hostname" {
  description = "Document Engine hostname"
  type        = string
}

variable "document_engine" {
  description = "Document Engine parameters"
  type = object({
    activation_key     = string
    logging_level      = string
    namespace_name     = string
    helm_release_name  = string
    helm_chart_version = string
  })
}

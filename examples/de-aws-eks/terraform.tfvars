# Document Engine

document_engine = {
  activation_key     = ""
  logging_level      = "debug"
  namespace_name     = "nutrient-document-engine"
  helm_release_name  = "document-engine"
  helm_chart_version = "5.4.0"
}

# AWS

aws_region = "eu-north-1"

# Names and resources

environment_name = "nutrient-de-demo"
additional_tags = {
  "nutrient:environment" = "nutrient-de-demo"
  "nutrient:demo"        = "true"
}

cluster_cidr = "10.0.0.0/16"

cluster_log_retention_days   = 3
container_log_retention_days = 3

cluster_ec2_instance_type = "m7i.large"
cluster_nodes_count       = 1

# Versions

cluster_version                                 = "1.33"
aws_for_fluent_bit_helm_chart_version           = "0.1.34"
aws_load_balancer_controller_helm_chart_version = "1.9.0"

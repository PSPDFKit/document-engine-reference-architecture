locals {
  document_engine_db_password_version = 1 # for rotation
  document_engine_db_password         = sensitive(random_password.document_engine_db_password.result)
  document_engine_db_name             = "pspdfkit"
}

module "document_engine_storage" {
  source           = "./modules/document-engine-storage"
  cluster_info     = module.kubernetes_cluster.cluster_info
  cluster_vpc_info = module.kubernetes_cluster.cluster_vpc_info
  database_properties = {
    identifier                   = "docengine-eks-example"
    username                     = "pspdfkit"
    db_name                      = local.document_engine_db_name
    ec2_instance_type            = "db.t3.micro"
    postgres_engine_version      = "15.4"
    postgres_parameter_family    = "postgres15"
    publicly_accessible          = false
    preferred_maintenance_window = "sun:05:00-sun:06:00"
  }
  database_password = local.document_engine_db_password
}

resource "random_password" "document_engine_db_password" {
  length  = 40
  special = false

  keepers = {
    version = local.document_engine_db_password_version
  }
}

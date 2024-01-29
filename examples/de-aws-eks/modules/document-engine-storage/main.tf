resource "aws_db_parameter_group" "this" {
  name   = var.database_properties.identifier
  family = var.database_properties.postgres_parameter_family

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "this" {
  identifier           = var.database_properties.identifier
  instance_class       = var.database_properties.ec2_instance_type
  allocated_storage    = 10
  engine               = "postgres"
  engine_version       = var.database_properties.postgres_engine_version
  username             = var.database_properties.username
  password             = var.database_password
  db_name              = var.database_properties.db_name
  db_subnet_group_name = var.cluster_vpc_info.db_subnet_group_name
  storage_encrypted    = true
  vpc_security_group_ids = [
    var.cluster_vpc_info.node_security_group_id,
    var.cluster_vpc_info.primary_security_group_id
  ]
  parameter_group_name = aws_db_parameter_group.this.name
  publicly_accessible  = var.database_properties.publicly_accessible
  skip_final_snapshot  = true
}

#
# VPC
#
# https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
# https://github.com/terraform-aws-modules/terraform-aws-vpc
#

module "vm_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "vm-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = []
  public_subnets  = [cidrsubnet(var.vpc_cidr, 4, 0)]

  create_igw           = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.additional_tags, { Name = "vm-VPC" })
}

resource "aws_security_group" "vm" {
  vpc_id      = module.vm_vpc.vpc_id
  name        = "vm-SG"
  tags        = merge(var.additional_tags, { Name = "vm-SG" })
  description = "What is allowed to the vm"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "vm_in_ssh_4" {
  security_group_id = aws_security_group.vm.id
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "vm_out_4" {
  security_group_id = aws_security_group.vm.id
  from_port         = -1
  to_port           = -1
  ip_protocol       = "all"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "vm_in_http" {
  security_group_id = aws_security_group.vm.id
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "vm_in_https" {
  security_group_id = aws_security_group.vm.id
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

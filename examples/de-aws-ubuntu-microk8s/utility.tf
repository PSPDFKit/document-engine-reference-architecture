terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.31"
    }
  }
}

provider "aws" {
  profile = var.aws_profile_name
  region  = var.aws_region

  default_tags {
    tags = local.default_tags
  }
}

#
# Data
#
data "aws_availability_zones" "available" {
  state = "available"
}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  aws_region_name = data.aws_region.current.name
  aws_account_id  = data.aws_caller_identity.current.account_id
}

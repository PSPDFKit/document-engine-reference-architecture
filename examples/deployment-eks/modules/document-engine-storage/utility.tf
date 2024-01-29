data "aws_availability_zones" "available" {
  state = "available"
}
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_default_tags" "current" {}

locals {
  aws_region_name = data.aws_region.current.name
  aws_account_id  = data.aws_caller_identity.current.account_id
  default_tags    = data.aws_default_tags.current.tags

  flux_protecting_annotations = {
    "kustomize.toolkit.fluxcd.io/prune" : "disabled"
  }
}

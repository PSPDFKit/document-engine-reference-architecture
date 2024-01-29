locals {

  ec2_metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "disabled"
  }

  default_block_device_mappings_bottlerocket = {
    xvda = {
      # Root device
      device_name = "/dev/xvda"
      ebs = {
        volume_size           = 8
        volume_type           = "gp3"
        iops                  = 3000
        throughput            = 150
        encrypted             = true
        delete_on_termination = true
      }
    }
    xvdb = {
      # Data device: Container resources such as images and logs
      device_name = "/dev/xvdb"
      ebs = {
        volume_size           = 40
        volume_type           = "gp3"
        iops                  = 3000
        throughput            = 150
        encrypted             = true
        delete_on_termination = true
      }
    }
  }
  bottlerocket_bootstrap_extra_args = <<-EOT
                [settings.kernel]
                lockdown = "integrity"

                [settings.host-containers.admin]
                enabled = false
                
                [settings.host-containers.control]
                enabled = false
            EOT

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type       = "BOTTLEROCKET_x86_64"
    platform       = "bottlerocket"
    instance_types = [var.cluster_ec2_instance_type]
    capacity_type  = "ON_DEMAND"
    update_config = {
      max_unavailable = 1
    }

    update_launch_template_default_version = true

    vpc_security_group_ids = [
      aws_security_group.node_security_group.id
    ]
    iam_role_additional_policies = {
      additional = aws_iam_policy.additional_node_policy.arn
    }
    metadata_options      = local.ec2_metadata_options
    ebs_optimized         = true
    bootstrap_extra_args  = local.bottlerocket_bootstrap_extra_args
    block_device_mappings = local.default_block_device_mappings_bottlerocket
  }

  eks_managed_node_groups = {
    base-x86-64 = {
      min_size     = var.cluster_nodes_count
      max_size     = var.cluster_nodes_count
      desired_size = var.cluster_nodes_count
      labels = {
        Purpose = "default"
      }
    }
  }

}

resource "aws_iam_policy" "additional_node_policy" {
  name   = "${var.cluster_name}-additional-node-policy"
  policy = data.aws_iam_policy_document.additional_node_policy.json
}

data "aws_iam_policy_document" "additional_node_policy" {
  statement {
    sid       = "AllowEC2Information"
    effect    = "Allow"
    actions   = ["ec2:Describe*"]
    resources = ["*"]
  }
  statement {
    sid       = "AllowAssumeRoleForPodIdentity"
    effect    = "Allow"
    actions   = ["eks-auth:AssumeRoleForPodIdentity"]
    resources = ["*"]
  }
  statement {
    #
    # It's better to have IRSA for this, but the potential damage if abused is just a mess in logs
    #
    sid    = "AllowLogging"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:PutLogEvents",
      "logs:putRetentionPolicy"
    ]
    resources = [
      "arn:aws:logs:${local.aws_region_name}:${local.aws_account_id}:log-group:${local.containers_log_group_prefix_ec2}/*",
    ]
  }
}

resource "aws_security_group" "node_security_group" {
  name_prefix = "${var.cluster_name}-node_security_group"
  vpc_id      = module.cluster_vpc.vpc_id
  tags        = { Name = "${var.cluster_name}-node_security_group" }
}


resource "aws_kms_key" "cluster_eks_logs" {
  description             = "EKS logs: ${var.cluster_name}"
  enable_key_rotation     = true
  deletion_window_in_days = 10
}

resource "aws_kms_alias" "cluster_eks_logs" {
  name          = "alias/${var.cluster_name}/EKS/Logs"
  target_key_id = aws_kms_key.cluster_eks_logs.key_id
}

resource "aws_kms_key_policy" "cluster_eks_logs" {
  key_id = aws_kms_key.cluster_eks_logs.key_id
  policy = data.aws_iam_policy_document.kms_logging_policy.json
}

data "aws_iam_policy_document" "kms_logging_policy" {
  statement {
    sid = "AllowUsersAndRoot"
    actions = [
      "kms:*",
    ]
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${local.aws_account_id}:root"
      ]
    }
    resources = ["*"]
  }
  statement {
    sid = "AllowKeyOperationsForCloudWatchLogs"

    principals {
      type        = "Service"
      identifiers = ["logs.${local.aws_region_name}.amazonaws.com"]
    }

    effect = "Allow"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]

    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${local.aws_region_name}:${local.aws_account_id}:*"]
    }
  }
}

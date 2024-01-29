
locals {
  default_tags = merge(
    var.additional_tags,
    {
      Environment = var.environment_name
    }
  )
}

data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [var.vm_ami_name_filter]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#
# Instance
#
resource "aws_key_pair" "key" {
  key_name   = "vm-key"
  public_key = file(var.vm_public_key)
  tags       = merge(var.additional_tags, { Name = "vm-key" })
}

resource "aws_instance" "vm" {
  ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = var.vm_instance_type
  subnet_id                   = module.vm_vpc.public_subnets[0]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.key.key_name
  vpc_security_group_ids      = [aws_security_group.vm.id]
  root_block_device {
    volume_size           = var.vm_disk_size
    encrypted             = true
    delete_on_termination = true
  }
  iam_instance_profile        = aws_iam_instance_profile.vm.name
  user_data_replace_on_change = true
  user_data = templatefile(
    "${path.module}/vm_userdata.sh",
    {
      aws_region                  = local.aws_region_name
      init_script_content         = file("${path.module}/document-engine_setup.sh")
      signing_service_certificate = file("${path.module}/signing-service.Certificate.yaml")
    }
  )
  tags = merge(
    var.additional_tags,
    {
      Name = "pspdfkit-demo-instance"
    }
  )
}

resource "aws_iam_instance_profile" "vm" {
  name_prefix = "${var.environment_name}-vm"
  role        = aws_iam_role.vm_role.name
}

resource "aws_iam_role" "vm_role" {
  name               = "${var.environment_name}-vm"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.vm_assume_role.json
}

data "aws_iam_policy_document" "vm_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "vm_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "s3:List*"
    ]
    resources = [
      "*"
    ]
  }
  # Add permissions here
}

resource "aws_iam_policy" "vm_permissions" {
  name   = "${var.environment_name}-vm-permissions"
  policy = data.aws_iam_policy_document.vm_permissions.json
}

resource "aws_iam_role_policy_attachment" "vm_permissions" {
  role       = aws_iam_role.vm_role.name
  policy_arn = aws_iam_policy.vm_permissions.arn
}

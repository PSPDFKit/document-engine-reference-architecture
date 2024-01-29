variable "aws_profile_name" {
  type    = string
  default = "default"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "eu-north-1"
}

variable "additional_tags" {
  type        = map(string)
  description = "Additional resource tags"
  default     = {}
}

variable "environment_name" {
  type        = string
  description = "Environment name to use all over the place"
  default     = "pspdfkit-example-microk8s"
}

variable "vm_public_key" {
  type        = string
  description = "SSH public key for the virtual machine"
  default     = ""
}

variable "vm_instance_type" {
  type        = string
  description = "EC2 instance type for the virtual machine"
  default     = "m7i.large"
}

variable "vm_ami_name_filter" {
  type        = string
  description = "AMI name filter"
  default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server*"
}

variable "vm_disk_size" {
  type        = number
  description = "EC2 instance type for the virtual machine"
  default     = 32
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "172.17.18.0/24"
}

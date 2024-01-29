output "vm_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.vm.id
}

output "vm_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.vm.public_ip
}

output "vm_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.vm.public_dns
}

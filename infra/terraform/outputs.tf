output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.epi_pipeline.id
}

output "public_ip" {
  description = "Public IP — use for SSH and RDS security group whitelist"
  value       = aws_instance.epi_pipeline.public_ip
}

output "public_dns" {
  description = "Public DNS hostname"
  value       = aws_instance.epi_pipeline.public_dns
}

output "ssh_command" {
  description = "Ready-to-use SSH command"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_instance.epi_pipeline.public_ip}"
}

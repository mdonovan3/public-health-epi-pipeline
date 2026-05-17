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

output "airflow_tunnel_command" {
  description = "SSH tunnel to reach Airflow UI at http://localhost:8080"
  value       = "ssh -L 8080:localhost:8080 -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_instance.epi_pipeline.public_ip}"
}

output "airflow_ui_note" {
  description = "How to access Airflow after opening the tunnel"
  value       = "Open http://localhost:8080 — login: admin / <airflow_admin_password from tfvars>"
}

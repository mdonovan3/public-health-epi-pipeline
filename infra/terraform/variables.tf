# [PART 15 · STEP 15.1] — Define all input variables before running terraform apply.
# Copy terraform.tfvars.example to terraform.tfvars and fill in values.
# Never commit terraform.tfvars — it contains the DB password.

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type — t3.small is sufficient for R ingestion + dbt"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH access"
  type        = string
  # [PART 15 · STEP 15.1a] Set in terraform.tfvars
}

variable "ami_id" {
  description = "Amazon Linux 2023 AMI — update per region"
  type        = string
  # [PART 15 · STEP 15.1b] Look up current AMI: aws ec2 describe-images --owners amazon \
  #   --filters "Name=name,Values=al2023-ami-*-x86_64" --query 'sort_by(Images,&CreationDate)[-1].ImageId'
}

variable "vpc_id" {
  description = "VPC to launch the instance into"
  type        = string
  # [PART 15 · STEP 15.1c] Use same VPC as the RDS instance (lhrc-db)
}

variable "subnet_id" {
  description = "Public subnet for the instance (needs outbound internet for CDC/EPA downloads)"
  type        = string
}

variable "db_password" {
  description = "DB_PASSWORD_EPI — written to /etc/environment on the instance"
  type        = string
  sensitive   = true
  # [PART 15 · STEP 15.1d] Consider using AWS SSM Parameter Store instead of passing here directly
}

variable "project_repo" {
  description = "Git URL for this repository — cloned on the instance during bootstrap"
  type        = string
  default     = "https://github.com/mdonovan3/public-health-epi-pipeline.git"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Project   = "epi-pipeline"
    ManagedBy = "terraform"
  }
}

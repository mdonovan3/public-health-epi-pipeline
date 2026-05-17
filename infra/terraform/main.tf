terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # [PART 15 · STEP 15.2] Remote state — uncomment and configure before team use
  # backend "s3" {
  #   bucket = "TODO_TERRAFORM_STATE_BUCKET"
  #   key    = "epi-pipeline/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region
}

# ── Security Group ──────────────────────────────────────────────────────────

resource "aws_security_group" "epi_pipeline" {
  name        = "epi-pipeline-sg"
  description = "SSH in; all outbound for CDC/EPA downloads and RDS access"
  vpc_id      = var.vpc_id
  tags        = var.tags

  # [PART 15 · STEP 15.3] Restrict SSH to your IP — replace 0.0.0.0/0
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # TODO: lock down to your IP
  }

  # Airflow webserver — port 8080.
  # Preferred access: SSH tunnel (ssh -L 8080:localhost:8080 ec2-user@<ip>)
  # which requires no inbound rule at all. Uncomment below only if you need
  # direct browser access without a tunnel, and lock it to your IP.
  # ingress {
  #   description = "Airflow UI"
  #   from_port   = 8080
  #   to_port     = 8080
  #   protocol    = "tcp"
  #   cidr_blocks = ["YOUR.IP.HERE/32"]
  # }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── IAM Role ────────────────────────────────────────────────────────────────
# [PART 15 · STEP 15.4] Add S3 policy if pipeline reads/writes source files from S3

resource "aws_iam_role" "epi_pipeline" {
  name = "epi-pipeline-ec2-role"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_instance_profile" "epi_pipeline" {
  name = "epi-pipeline-ec2-profile"
  role = aws_iam_role.epi_pipeline.name
}

# [PART 15 · STEP 15.4a] Attach AmazonSSMManagedInstanceCore if you want Session Manager SSH
# resource "aws_iam_role_policy_attachment" "ssm" {
#   role       = aws_iam_role.epi_pipeline.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }

# ── EC2 Instance ────────────────────────────────────────────────────────────

resource "aws_instance" "epi_pipeline" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.epi_pipeline.id]
  iam_instance_profile   = aws_iam_instance_profile.epi_pipeline.name
  tags                   = merge(var.tags, { Name = "epi-pipeline" })

  root_block_device {
    volume_size = 20 # GB — source data files are ~300MB total, comfortable margin
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    db_password            = var.db_password
    project_repo           = var.project_repo
    airflow_admin_password = var.airflow_admin_password
  })

  # [PART 15 · STEP 15.5] After first apply, connect and tail /var/log/user-data.log
  # to confirm bootstrap completed without errors.
}

# ── Elastic IP ───────────────────────────────────────────────────────────────
# [PART 15 · STEP 15.6] Uncomment if you need a stable IP (e.g. for RDS security group rule)
# resource "aws_eip" "epi_pipeline" {
#   instance = aws_instance.epi_pipeline.id
#   domain   = "vpc"
#   tags     = var.tags
# }

#!/bin/bash
# Bootstrap script — runs once on first EC2 start as root.
# Rendered by Terraform templatefile(); variables injected: db_password, project_repo.
# Tail progress: sudo tail -f /var/log/user-data.log
set -euo pipefail
exec > /var/log/user-data.log 2>&1

echo "=== epi-pipeline bootstrap start ==="

# ── [PART 15 · STEP 15.7] System packages ───────────────────────────────────
dnf update -y
dnf install -y git curl wget unzip python3-pip

# [PART 15 · STEP 15.7a] Install R — Amazon Linux 2023 ships R via EPEL
dnf install -y R

# ── [PART 15 · STEP 15.8] Python / dbt ──────────────────────────────────────
pip3 install dbt-postgres

# ── [PART 15 · STEP 15.9] R packages ────────────────────────────────────────
# [PART 15 · STEP 15.9a] This takes ~5 min on t3.small — consider pre-baking an AMI
Rscript -e "install.packages(c(
  'config', 'here', 'tidyverse', 'janitor',
  'DBI', 'RPostgres'
), repos='https://cloud.r-project.org')"

# ── [PART 15 · STEP 15.10] Environment variables ────────────────────────────
# Written to /etc/environment so they're available to cron and all users
echo "DB_PASSWORD_EPI=${db_password}" >> /etc/environment

# [PART 15 · STEP 15.10a] Consider AWS SSM Parameter Store instead:
#   aws ssm get-parameter --name /epi-pipeline/db-password --with-decryption \
#     --query Parameter.Value --output text >> /etc/environment

# ── [PART 15 · STEP 15.11] Clone repository ─────────────────────────────────
PROJECT_DIR="/home/ec2-user/epi-pipeline"
git clone ${project_repo} "$PROJECT_DIR"
chown -R ec2-user:ec2-user "$PROJECT_DIR"

# ── [PART 15 · STEP 15.12] Cron job ─────────────────────────────────────────
# Install the pipeline poller cron entry for ec2-user
CRON_LINE="* * * * * $PROJECT_DIR/cron/poll_and_run.sh >> $PROJECT_DIR/cron/pipeline.log 2>&1"
(crontab -u ec2-user -l 2>/dev/null; echo "$CRON_LINE") | crontab -u ec2-user -

echo "=== epi-pipeline bootstrap complete ==="

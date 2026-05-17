#!/bin/bash
# Bootstrap script — runs once on first EC2 start as root.
# Rendered by Terraform templatefile(); variables injected:
#   db_password, project_repo, airflow_admin_password
# Tail progress: sudo tail -f /var/log/user-data.log
set -euo pipefail
exec > /var/log/user-data.log 2>&1

echo "=== epi-pipeline bootstrap start ==="

# ── [PART 15 · STEP 15.7] System packages ───────────────────────────────────
dnf update -y
dnf install -y git curl wget unzip python3-pip gcc python3-devel

# [PART 15 · STEP 15.7a] Install R — Amazon Linux 2023 ships R via EPEL
dnf install -y R

# ── [PART 15 · STEP 15.8] Python packages — dbt + Airflow ───────────────────
# [PART 15 · STEP 15.8a] Install dbt
pip3 install dbt-postgres

# [PART 15 · STEP 15.8b] Install Airflow with version-pinned constraints.
# Constraints file ensures compatible dependency versions — do not skip.
AIRFLOW_VERSION=2.9.3
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"
pip3 install "apache-airflow==${AIRFLOW_VERSION}" --constraint "${CONSTRAINT_URL}"

# ── [PART 15 · STEP 15.9] R packages ────────────────────────────────────────
# [PART 15 · STEP 15.9a] This takes ~5 min on t3.small — consider pre-baking an AMI
Rscript -e "install.packages(c(
  'config', 'here', 'tidyverse', 'janitor',
  'DBI', 'RPostgres'
), repos='https://cloud.r-project.org')"

# ── [PART 15 · STEP 15.10] Environment variables ────────────────────────────
# Written to /etc/environment so they're available to all users and services
echo "DB_PASSWORD_EPI=${db_password}" >> /etc/environment
echo "AIRFLOW_HOME=/home/ec2-user/airflow"  >> /etc/environment

# Also write to ec2-user's .bashrc for interactive sessions
cat >> /home/ec2-user/.bashrc <<'BASHRC'
export DB_PASSWORD_EPI=$(grep DB_PASSWORD_EPI /etc/environment | cut -d= -f2)
export AIRFLOW_HOME=/home/ec2-user/airflow
export PATH=$PATH:/home/ec2-user/.local/bin
BASHRC

# ── [PART 15 · STEP 15.11] Clone repository ─────────────────────────────────
PROJECT_DIR="/home/ec2-user/epi-pipeline"
git clone ${project_repo} "$PROJECT_DIR"
chown -R ec2-user:ec2-user "$PROJECT_DIR"

# ── [PART 15 · STEP 15.12] Airflow setup ────────────────────────────────────
AIRFLOW_HOME="/home/ec2-user/airflow"
AIRFLOW_BIN="/usr/local/bin/airflow"

# Create airflow home and dags directory
mkdir -p "$AIRFLOW_HOME/dags"
chown -R ec2-user:ec2-user "$AIRFLOW_HOME"

# Copy DAG from repo
cp "$PROJECT_DIR/docker/dags/epi_pipeline_dag.py" "$AIRFLOW_HOME/dags/"

# Initialize the Airflow metadata DB (SQLite, stored in AIRFLOW_HOME)
# and create the admin user — run as ec2-user so file ownership is correct
sudo -u ec2-user AIRFLOW_HOME="$AIRFLOW_HOME" PATH="$PATH:/usr/local/bin" \
  airflow db migrate

sudo -u ec2-user AIRFLOW_HOME="$AIRFLOW_HOME" PATH="$PATH:/usr/local/bin" \
  airflow users create \
    --username admin \
    --password "${airflow_admin_password}" \
    --firstname Admin \
    --lastname User \
    --role Admin \
    --email admin@example.com

chown -R ec2-user:ec2-user "$AIRFLOW_HOME"

# ── [PART 15 · STEP 15.13] Airflow systemd services ─────────────────────────
# Scheduler — runs the DAG executor
cat > /etc/systemd/system/airflow-scheduler.service <<EOF
[Unit]
Description=Airflow Scheduler
After=network.target

[Service]
User=ec2-user
Group=ec2-user
EnvironmentFile=/etc/environment
Environment="AIRFLOW_HOME=/home/ec2-user/airflow"
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
ExecStart=/usr/local/bin/airflow scheduler
Restart=on-failure
RestartSec=10s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Webserver — Airflow UI on port 8080
cat > /etc/systemd/system/airflow-webserver.service <<EOF
[Unit]
Description=Airflow Webserver
After=network.target airflow-scheduler.service

[Service]
User=ec2-user
Group=ec2-user
EnvironmentFile=/etc/environment
Environment="AIRFLOW_HOME=/home/ec2-user/airflow"
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
ExecStart=/usr/local/bin/airflow webserver --port 8080
Restart=on-failure
RestartSec=10s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable airflow-scheduler airflow-webserver
systemctl start  airflow-scheduler airflow-webserver

echo "=== epi-pipeline bootstrap complete ==="
echo "Airflow UI: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "Or use SSH tunnel: ssh -L 8080:localhost:8080 ec2-user@<instance-ip>"

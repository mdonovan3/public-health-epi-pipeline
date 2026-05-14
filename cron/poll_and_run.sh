#!/bin/bash
# Prod cron script — polls S3 for new raw data files, runs pipeline if found
# Add to crontab on EC2: */60 * * * * /path/to/poll_and_run.sh >> /var/log/epi_pipeline.log 2>&1

export R_CONFIG_ACTIVE=production
export DB_PASSWORD_EPI=  # TODO: load from AWS Secrets Manager or set in environment

PROJECT_DIR="/home/ec2-user/public-health-epi-pipeline"  # TODO: update path on EC2
LOG_FILE="/var/log/epi_pipeline.log"

# TODO: implement S3 check for new files
# Check if new data files exist in S3 that haven't been processed
# aws s3 ls s3://TODO_BUCKET_NAME/raw/ --newer-than last_run_timestamp

# For now: always run (idempotency in R scripts prevents duplicate loads)
echo "[$(date)] Starting pipeline run..."
cd $PROJECT_DIR && Rscript run_pipeline.R
echo "[$(date)] Pipeline complete."

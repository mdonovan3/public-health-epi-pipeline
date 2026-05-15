#!/bin/bash
# Poll data/raw/ for new files and run ingestion when found.
# Files are moved to data/processed/ after successful load so this won't re-fire.
#
# Local crontab (runs every minute):
#   * * * * * /home/mdonovan/Projects/public-health-epi-pipeline/cron/poll_and_run.sh >> /home/mdonovan/Projects/public-health-epi-pipeline/cron/pipeline.log 2>&1
#
# To install:
#   crontab -e
#   paste the line above, save
#
# To remove:
#   crontab -e  → delete the line
#
# Prod EC2 note: set R_CONFIG_ACTIVE=production and load DB_PASSWORD_EPI from
# AWS Secrets Manager before the Rscript calls below.

PROJECT_DIR="/home/mdonovan/Projects/public-health-epi-pipeline"
RAW_DIR="$PROJECT_DIR/data/raw"
PROCESSED_DIR="$PROJECT_DIR/data/processed"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# ── Check for any work to do ──────────────────────────────────────────────────

PLACES_FILE="$RAW_DIR/places_county.csv"
EPA_FILE="$RAW_DIR/epa_pm25_annual.csv"

if [ ! -f "$PLACES_FILE" ] && [ ! -f "$EPA_FILE" ]; then
  exit 0  # nothing to do — silent exit, no log spam
fi

echo "$LOG_PREFIX Files found in data/raw/ — starting ingestion"

# ── Load DB password ──────────────────────────────────────────────────────────

export DB_PASSWORD_EPI=$(grep DB_PASSWORD_EPI ~/.Renviron | cut -d= -f2)

if [ -z "$DB_PASSWORD_EPI" ]; then
  echo "$LOG_PREFIX ERROR: DB_PASSWORD_EPI not set in ~/.Renviron — aborting"
  exit 1
fi

# ── Ingest CDC PLACES ─────────────────────────────────────────────────────────

if [ -f "$PLACES_FILE" ]; then
  echo "$LOG_PREFIX Running load_places.R..."

  Rscript -e "source(here::here('ingestion/load_places.R'))" \
    --vanilla 2>&1

  if [ $? -eq 0 ]; then
    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    mv "$PLACES_FILE" "$PROCESSED_DIR/places_county_${TIMESTAMP}.csv"
    echo "$LOG_PREFIX places_county.csv moved to processed/"
  else
    echo "$LOG_PREFIX ERROR: load_places.R failed — file left in raw/ for retry"
    exit 1
  fi
fi

# ── Ingest EPA PM2.5 ──────────────────────────────────────────────────────────

if [ -f "$EPA_FILE" ]; then
  echo "$LOG_PREFIX Running load_epa_pm25.R..."

  Rscript -e "source(here::here('ingestion/load_epa_pm25.R'))" \
    --vanilla 2>&1

  if [ $? -eq 0 ]; then
    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    mv "$EPA_FILE" "$PROCESSED_DIR/epa_pm25_annual_${TIMESTAMP}.csv"
    echo "$LOG_PREFIX epa_pm25_annual.csv moved to processed/"
  else
    echo "$LOG_PREFIX ERROR: load_epa_pm25.R failed — file left in raw/ for retry"
    exit 1
  fi
fi

# ── Run dbt ───────────────────────────────────────────────────────────────────

echo "$LOG_PREFIX Running dbt..."

cd "$PROJECT_DIR/dbt" && dbt run --target dev 2>&1
if [ $? -ne 0 ]; then
  echo "$LOG_PREFIX ERROR: dbt run failed"
  exit 1
fi

dbt test --target dev 2>&1
if [ $? -ne 0 ]; then
  echo "$LOG_PREFIX WARNING: dbt tests failed — check output above"
fi

echo "$LOG_PREFIX Pipeline complete."

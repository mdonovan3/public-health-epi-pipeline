#!/bin/bash
# Simulate an external data delivery for a given year.
# Copies batch files from data/source/batches/ into data/raw/
# as if they arrived from an external source.
# The cron job picks them up within 1 minute and runs ingestion.
#
# Usage:
#   ./scripts/simulate_drop.sh 2022           # drop both PLACES + EPA for 2022
#   ./scripts/simulate_drop.sh 2022 places    # drop PLACES only
#   ./scripts/simulate_drop.sh 2022 epa       # drop EPA only
#
# Available years:
#   PLACES: 2019, 2020, 2021, 2022, 2023
#   EPA:    2019, 2020, 2021, 2022, 2023, 2024

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BATCHES_DIR="$PROJECT_DIR/data/source/batches"
RAW_DIR="$PROJECT_DIR/data/raw"

YEAR="$1"
DATASET="${2:-both}"   # "places", "epa", or "both" (default)

# ── Validate args ─────────────────────────────────────────────────────────────

if [ -z "$YEAR" ]; then
  echo "Usage: $0 <year> [places|epa|both]"
  echo ""
  echo "Available batches:"
  ls "$BATCHES_DIR" 2>/dev/null | sed 's/^/  /'
  exit 1
fi

# ── Check for files already in raw/ ──────────────────────────────────────────

existing=$(ls "$RAW_DIR"/*.csv 2>/dev/null | wc -l)
if [ "$existing" -gt 0 ]; then
  echo "WARNING: data/raw/ already has files — cron may not have processed them yet:"
  ls "$RAW_DIR"/*.csv 2>/dev/null | sed 's/^/  /'
  echo ""
  read -p "Drop anyway? (y/N) " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
  fi
fi

# ── Drop files ────────────────────────────────────────────────────────────────

dropped=0

if [[ "$DATASET" == "both" || "$DATASET" == "places" ]]; then
  src="$BATCHES_DIR/places_county_${YEAR}.csv"
  if [ -f "$src" ]; then
    cp "$src" "$RAW_DIR/places_county.csv"
    echo "[$(date '+%H:%M:%S')] Dropped → data/raw/places_county.csv  (PLACES $YEAR)"
    dropped=$((dropped + 1))
  else
    echo "Not found: $src"
    echo "  Run scripts/split_source_data.R first to generate batch files."
  fi
fi

if [[ "$DATASET" == "both" || "$DATASET" == "epa" ]]; then
  src="$BATCHES_DIR/epa_pm25_${YEAR}.csv"
  if [ -f "$src" ]; then
    cp "$src" "$RAW_DIR/epa_pm25_annual.csv"
    echo "[$(date '+%H:%M:%S')] Dropped → data/raw/epa_pm25_annual.csv  (EPA $YEAR)"
    dropped=$((dropped + 1))
  else
    echo "Not found: $src"
    echo "  Run scripts/split_source_data.R first to generate batch files."
  fi
fi

# ── Result ────────────────────────────────────────────────────────────────────

if [ "$dropped" -gt 0 ]; then
  echo ""
  echo "Simulating delivery of $YEAR data. Cron will pick up within 1 minute."
  echo "Watch: tail -f $PROJECT_DIR/cron/pipeline.log"
fi

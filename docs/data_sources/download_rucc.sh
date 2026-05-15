#!/bin/bash
# Download USDA Rural-Urban Continuum Codes — 2023 release
# Output: data/source/_pending_rucc/rucc_2023.csv
#
# Status: PENDING — not yet integrated into pipeline
#
# File is in long format: multiple rows per county (population, RUCC code, description).
# Pivot to wide (one row per county) before joining.
# Candidate for a dbt seed rather than a full ingestion script.
#
# RUCC codes 1-3 = metro, 4-6 = suburban/small city, 7-9 = rural
#
# Source: https://www.ers.usda.gov/data-products/rural-urban-continuum-codes/

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$PROJECT_DIR/data/source/_pending_rucc"
mkdir -p "$OUT_DIR"

echo "Downloading USDA Rural-Urban Continuum Codes 2023..."

wget -q --show-progress \
  -O "$OUT_DIR/rucc_2023.csv" \
  "https://www.ers.usda.gov/media/5768/2023-rural-urban-continuum-codes.csv?v=44510" \
  && echo "Done: rucc_2023.csv"

echo ""
echo "RUCC download complete. File is in data/source/_pending_rucc/"
echo "Integrate into pipeline per BUILD.md when ready."

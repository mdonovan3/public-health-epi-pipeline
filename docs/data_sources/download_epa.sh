#!/bin/bash
# Download EPA AQS annual concentration by monitor — 2019 through 2024
# Output: data/source/epa_pm25_YYYY_full.csv
#
# Files contain ALL pollutants. Filtering to specific parameter codes
# happens in the ingestion scripts and split_source_data.R.
#
# Parameter codes of interest:
#   88101 — PM2.5 FRM/FEM     (active in pipeline)
#   44201 — Ozone             (pending integration)
#   42602 — NO2               (pending integration)
#
# Source: https://aqs.epa.gov/aqsweb/airdata/download_files.html

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$PROJECT_DIR/data/source"
mkdir -p "$OUT_DIR"

echo "Downloading EPA AQS annual summary files (2019-2024)..."
echo "These are large files (~35-50MB each compressed)."
echo ""

for year in 2019 2020 2021 2022 2023 2024; do
  echo "Downloading $year..."

  wget -q --show-progress \
    -O "$OUT_DIR/epa_${year}.zip" \
    "https://aqs.epa.gov/aqsweb/airdata/annual_conc_by_monitor_${year}.zip"

  unzip -q -o "$OUT_DIR/epa_${year}.zip" -d "$OUT_DIR/epa_${year}_tmp/"

  mv "$OUT_DIR/epa_${year}_tmp/annual_conc_by_monitor_${year}.csv" \
     "$OUT_DIR/epa_pm25_${year}_full.csv"

  rm -rf "$OUT_DIR/epa_${year}_tmp/" "$OUT_DIR/epa_${year}.zip"

  echo "Done: epa_pm25_${year}_full.csv"
done

echo ""
echo "All EPA downloads complete."
echo "Run: Rscript scripts/split_source_data.R"

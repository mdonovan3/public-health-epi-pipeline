#!/bin/bash
# Download CDC PLACES county data — all available years
# Output: data/source/places_county_*.csv
#
# Sources:
#   2022-2023: https://data.cdc.gov/resource/swc5-untb (PLACES 2025 release)
#   2020-2021: https://data.cdc.gov/resource/h3ej-a9ec (PLACES 2023 release)
#   2019:      https://data.cdc.gov/resource/pqpp-u99h (PLACES 2021 release)
#
# After downloading, run: Rscript scripts/split_source_data.R
# to split into per-year batch files in data/source/batches/

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$PROJECT_DIR/data/source"
mkdir -p "$OUT_DIR"

echo "Downloading CDC PLACES county data..."

wget -q --show-progress \
  -O "$OUT_DIR/places_county_full.csv" \
  "https://data.cdc.gov/resource/swc5-untb.csv?\$limit=500000" \
  && echo "Done: places_county_full.csv (2022-2023)"

wget -q --show-progress \
  -O "$OUT_DIR/places_county_2020_2021_full.csv" \
  "https://data.cdc.gov/resource/h3ej-a9ec.csv?\$limit=500000" \
  && echo "Done: places_county_2020_2021_full.csv (2020-2021)"

wget -q --show-progress \
  -O "$OUT_DIR/places_county_2019_full.csv" \
  "https://data.cdc.gov/resource/pqpp-u99h.csv?\$limit=500000&year=2019" \
  && echo "Done: places_county_2019_full.csv (2019)"

echo ""
echo "All PLACES downloads complete."
echo "Run: Rscript scripts/split_source_data.R"

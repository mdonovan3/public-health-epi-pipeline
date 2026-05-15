#!/bin/bash
# Download CDC/ATSDR Social Vulnerability Index — county level, 2018/2020/2022
# Output: data/source/_pending_svi/svi_county_YYYY.csv
#
# Status: PENDING — not yet integrated into pipeline
#
# The SVI portal (https://svi.cdc.gov/dataDownloads/data-download.html) requires
# a JavaScript form submission. Direct URL pattern was reverse-engineered from:
#   https://svi.cdc.gov/js/loadXML.js
#
# Key columns after download:
#   FIPS         — 5-digit county FIPS (join key)
#   RPL_THEMES   — overall composite vulnerability percentile (0-1)
#   RPL_THEME1   — socioeconomic
#   RPL_THEME2   — household composition
#   RPL_THEME3   — minority status and language
#   RPL_THEME4   — housing and transportation
#
# Year mapping to PLACES/EPA data years:
#   2019-2020 → use SVI 2018
#   2021-2022 → use SVI 2020
#   2023      → use SVI 2022

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$PROJECT_DIR/data/source/_pending_svi"
mkdir -p "$OUT_DIR"

echo "Downloading CDC SVI county data (2018, 2020, 2022)..."

for year in 2018 2020 2022; do
  wget -q --show-progress \
    -U "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
    -O "$OUT_DIR/svi_county_${year}.csv" \
    "https://svi.cdc.gov/Documents/Data/${year}/csv/states_counties/SVI_${year}_US_county.csv" \
    && echo "Done: svi_county_${year}.csv"
done

echo ""
echo "SVI downloads complete. Files are in data/source/_pending_svi/"
echo "Integrate into pipeline per BUILD.md when ready."

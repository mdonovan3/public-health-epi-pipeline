# Data Sources Registry

All datasets used in or planned for this pipeline.
Status: **active** = integrated in pipeline | **pending** = downloaded, not yet integrated

---

## 1. CDC PLACES County Data
**Status:** active  
**What it is:** County-level prevalence estimates for 40 chronic disease outcomes, behavioral risk
factors, preventive services, and social determinants of health. Produced by CDC using BRFSS
survey data + small area estimation. Age-adjusted rates allow comparison across counties with
different age distributions.  
**Grain:** county × year × measure (long format → pivoted to wide in mart)  
**Years available locally:** 2019, 2020, 2021, 2022, 2023  
**Join key:** `county_fips` (5-digit FIPS), `year`

**Source URL:**
```
https://data.cdc.gov/resource/swc5-untb.csv?$limit=500000        # 2022-2023
https://data.cdc.gov/resource/h3ej-a9ec.csv?$limit=500000        # 2020-2021
https://data.cdc.gov/resource/pqpp-u99h.csv?$limit=500000&year=2019  # 2019
```

**Download method:** `wget` direct from CDC Socrata API  
**Local files:**
```
data/source/places_county_full.csv           # 2022-2023
data/source/places_county_2020_2021_full.csv # 2020-2021
data/source/places_county_2019_full.csv      # 2019
data/source/batches/places_county_YYYY.csv   # split by year (run split_source_data.R)
```

**How downloaded:** `scripts/split_source_data.R` splits full files into per-year batches.
The ingestion script `ingestion/load_places.R` loads batches into `raw.places_county`.

---

## 2. EPA AQS Annual Concentration by Monitor
**Status:** active (PM2.5 only — O3 and NO2 pending integration)  
**What it is:** Station-level annual air quality summary for all criteria pollutants.
One row per monitoring station per year. Contains all pollutants in one file — filter by
`Parameter Code` to select the pollutant of interest.  
**Grain:** monitoring station × year (aggregated to county × year in dbt)  
**Years available locally:** 2019, 2020, 2021, 2022, 2023, 2024  
**Join key:** built from `State Code` + `County Code` → `county_fips`, plus `year`

**Parameter codes of interest:**
| Code  | Pollutant | Metric used | Status |
|-------|-----------|-------------|--------|
| 88101 | PM2.5 FRM/FEM | Annual mean (µg/m³) | active |
| 44201 | Ozone | 4th highest daily max 8-hr avg (ppm) | active |
| 42602 | NO2 | Annual mean (ppb) | active |
| 42101 | CO  | 2nd highest non-overlapping 8-hr avg | not planned |
| 42401 | SO2 | 99th percentile daily max 1-hr (ppb) | not planned |

**Source URL:**
```
https://aqs.epa.gov/aqsweb/airdata/annual_conc_by_monitor_YYYY.zip
```
Replace `YYYY` with year (2019–2024). Download page:
```
https://aqs.epa.gov/aqsweb/airdata/download_files.html
```

**Download method:** `wget` + `unzip`  
**Local files:**
```
data/source/epa_pm25_YYYY_full.csv           # full all-parameter files
data/source/batches/epa_pm25_YYYY.csv        # filtered to PM2.5 88101 only
```
Note: full source files contain all parameter codes. The batch files are PM2.5-only.
When O3 and NO2 are integrated, update `split_source_data.R` to generate separate
batch files per pollutant (or a combined multi-pollutant batch).

**How downloaded:** Manual `wget` loop in previous session. To re-download:
```bash
for year in 2019 2020 2021 2022 2023 2024; do
  wget -O data/source/epa_pm25_${year}_full.csv.zip \
    "https://aqs.epa.gov/aqsweb/airdata/annual_conc_by_monitor_${year}.zip"
  unzip -o data/source/epa_pm25_${year}_full.csv.zip -d data/source/
  mv data/source/annual_conc_by_monitor_${year}/annual_conc_by_monitor_${year}.csv \
     data/source/epa_pm25_${year}_full.csv
  rmdir data/source/annual_conc_by_monitor_${year}
  rm data/source/epa_pm25_${year}_full.csv.zip
done
```

---

## 3. CDC/ATSDR Social Vulnerability Index (SVI)
**Status:** pending  
**What it is:** County-level composite vulnerability index built from Census/ACS data.
Measures community resilience to external stressors (disasters, disease outbreaks, etc.).
Percentile rankings from 0 (least vulnerable) to 1 (most vulnerable).  
**Grain:** county (one row per county per release year — no year dimension in the data itself)  
**Releases available locally:** 2018, 2020, 2022  
**Join key:** `FIPS` (5-digit, already zero-padded)

**Key columns:**
| Column | Description |
|--------|-------------|
| `RPL_THEMES` | Overall composite vulnerability percentile |
| `RPL_THEME1` | Socioeconomic (poverty, unemployment, income, education) |
| `RPL_THEME2` | Household composition (elderly, disabled, single-parent, children) |
| `RPL_THEME3` | Minority status and language |
| `RPL_THEME4` | Housing and transportation (crowding, no vehicle, mobile homes) |

**Year mapping to PLACES/EPA data:**
| Data years | Use SVI release |
|------------|----------------|
| 2019–2020  | SVI 2018 |
| 2021–2022  | SVI 2020 |
| 2023       | SVI 2022 |

**Source URL:**
```
https://svi.cdc.gov/Documents/Data/YYYY/csv/states_counties/SVI_YYYY_US_county.csv
```
Replace `YYYY` with 2018, 2020, or 2022. URL pattern discovered from JS source at:
```
https://svi.cdc.gov/js/loadXML.js
```
The portal at `https://svi.cdc.gov/dataDownloads/data-download.html` requires a form
submission (JavaScript-driven) — use the direct URL above instead.

**Download method:** `wget` with browser user-agent  
**Local files:**
```
data/source/_pending_svi/svi_county_2018.csv
data/source/_pending_svi/svi_county_2020.csv
data/source/_pending_svi/svi_county_2022.csv
```

**To re-download:**
```bash
for year in 2018 2020 2022; do
  wget -A "Mozilla/5.0" \
    -O data/source/_pending_svi/svi_county_${year}.csv \
    "https://svi.cdc.gov/Documents/Data/${year}/csv/states_counties/SVI_${year}_US_county.csv"
done
```

---

## 4. USDA Rural-Urban Continuum Codes (RUCC)
**Status:** pending  
**What it is:** Single 9-category classification of every US county on a metro/non-metro
continuum. Static — one code per county, no annual updates.  
**Grain:** county (static lookup table, no year dimension)  
**Release available locally:** 2023  
**Join key:** `FIPS` (5-digit)

**Code categories:**
| Code | Description |
|------|-------------|
| 1 | Metro — 1 million+ population |
| 2 | Metro — 250,000–1 million |
| 3 | Metro — fewer than 250,000 |
| 4 | Non-metro — urban 20,000+, adjacent to metro |
| 5 | Non-metro — urban 20,000+, not adjacent |
| 6 | Non-metro — urban 2,500–19,999, adjacent |
| 7 | Non-metro — urban 2,500–19,999, not adjacent |
| 8 | Non-metro — completely rural, adjacent to metro |
| 9 | Non-metro — completely rural, not adjacent |

For analysis, typically collapsed: 1–3 = urban, 4–6 = suburban/small city, 7–9 = rural.

**Note:** The 2023 file is in long format (multiple rows per county — one for population,
one for RUCC code). Pivot to wide before joining. Candidate for a dbt seed rather than
a full ingestion script.

**Source URL:**
```
https://www.ers.usda.gov/media/5768/2023-rural-urban-continuum-codes.csv?v=44510
```
Download page:
```
https://www.ers.usda.gov/data-products/rural-urban-continuum-codes/
```

**Download method:** `wget` direct  
**Local files:**
```
data/source/_pending_rucc/rucc_2023.csv
```

**To re-download:**
```bash
wget -O data/source/_pending_rucc/rucc_2023.csv \
  "https://www.ers.usda.gov/media/5768/2023-rural-urban-continuum-codes.csv?v=44510"
```

---

## Join summary

```
CDC PLACES  (county_fips, year)          ← primary table, all counties all years
  LEFT JOIN EPA AQS   ON county_fips + year   ← not every county has a monitor
  LEFT JOIN SVI       ON county_fips           ← map year → nearest SVI release
  LEFT JOIN RUCC      ON county_fips           ← static, no year
```

Final mart grain: one row per county × year, columns from all four sources.

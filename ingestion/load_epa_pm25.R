# EPA PM2.5 County Data — ingestion script
# Reads annual summary CSV (all parameters), filters to PM2.5 (parameter_code 88101),
# loads station-level rows to raw.epa_pm25 — county aggregation happens in dbt
#
# Source: https://aqs.epa.gov/aqsweb/airdata/annual_conc_by_monitor_2024.zip
# File already downloaded to data/raw/epa_pm25_annual.csv

source(here::here("ingestion/utils.R"))
library(tidyverse)
library(janitor)

TARGET_TABLE <- "epa_pm25"
TARGET_SCHEMA <- "raw"

# ── Read ───────────────────────────────────────────────────────────────────────

log_msg("Reading EPA annual summary file...")
raw <- read_raw_file("epa_pm25_annual.csv")

# ── Clean ─────────────────────────────────────────────────────────────────────

# Source columns (after clean_names()):
#   state_code, county_code, site_num, parameter_code, poc,
#   latitude, longitude, datum, parameter_name,
#   sample_duration, pollutant_standard, metric_used, method_name,
#   year, units_of_measure, event_type,
#   observation_count, observation_percent, arithmetic_mean,
#   completeness_indicator, ...
#
# Keep columns: state_code, county_code, year, latitude, longitude,
#   arithmetic_mean, observation_count, observation_percent,
#   completeness_indicator, parameter_name, sample_duration, pollutant_standard
#
# Build county_fips:
#   paste0(str_pad(state_code, 2, pad="0"), str_pad(county_code, 3, pad="0"))

log_msg("Cleaning and filtering to PM2.5...")

cleaned <- raw %>%

  # [PART 4 · STEP 4.1] clean_names() and filter to PM2.5 only
  # clean_names() — normalizes "State Code" → state_code, etc.
  # filter(parameter_code == 88101) — keeps PM2.5 FRM/FEM only

  # [PART 4 · STEP 4.2] Select columns
  # select() the columns listed above

  # [PART 4 · STEP 4.3] Build county_fips and cast types
  # mutate():
  #   county_fips = paste0(str_pad(as.character(state_code), 2, pad="0"),
  #                        str_pad(as.character(county_code), 3, pad="0"))
  #   arithmetic_mean → as.numeric()
  #   observation_percent → as.numeric()
  #   observation_count → as.integer()
  #   year → as.integer()
  #   latitude, longitude → as.numeric()
  #   loaded_at = Sys.time()

  # [PART 4 · STEP 4.4] Filter null PM2.5 values
  # filter(!is.na(arithmetic_mean))

  NULL  # remove this line when implementing

log_msg(sprintf("Cleaned: %d PM2.5 station rows", nrow(cleaned)))

# ── Load ───────────────────────────────────────────────────────────────────────

con <- get_con()
on.exit(dbDisconnect(con))

# [PART 4 · STEP 4.5] Create schema and load table
# dbExecute(con, "CREATE SCHEMA IF NOT EXISTS raw")
# dbWriteTable(con,
#   name      = Id(schema = TARGET_SCHEMA, table = TARGET_TABLE),
#   value     = cleaned,
#   overwrite = TRUE,
#   row.names = FALSE
# )

log_msg(sprintf("Loaded %d rows into %s.%s", nrow(cleaned), TARGET_SCHEMA, TARGET_TABLE))

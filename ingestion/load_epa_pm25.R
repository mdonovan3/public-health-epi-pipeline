# EPA PM2.5 County Data — ingestion script
# Downloads or reads pre-downloaded annual summary, aggregates to county-year, loads to raw schema
#
# Source: https://www.epa.gov/outdoor-air-quality-data/download-daily-data
# Download "Annual Summary" data for PM2.5 (parameter code 88101 or 88502)
# Drop file in data/raw/epa_pm25_annual.csv
#
# Note: EPA files are station-level. dbt handles the county-year aggregation,
# but this script loads the raw station data. Keep it raw — don't pre-aggregate here.
#
# Schema target: raw.epa_pm25

source(here::here("ingestion/utils.R"))
library(tidyverse)
library(janitor)

TARGET_TABLE <- "epa_pm25"
TARGET_SCHEMA <- "raw"

# ── Read ───────────────────────────────────────────────────────────────────────

log_msg("Reading EPA PM2.5 annual summary file...")
raw <- read_raw_file("epa_pm25_annual.csv")

# ── Inspect (run manually first time) ─────────────────────────────────────────
# glimpse(raw)
# Expected columns from EPA annual summary (verify against actual download):
#   State Code, County Code, Site Num, Parameter Code, POC,
#   Latitude, Longitude, Datum, Parameter Name,
#   Sample Duration, Pollutant Standard, Units of Measure,
#   Event Type, Observation Count, Observation Percent,
#   Arithmetic Mean, 1st Max Value, 1st Max Hour, AQI,
#   Method Code, Method Name, Local Site Name, Address,
#   State Name, County Name, City Name, CBSA Name, Date of Last Change

# ── Clean ─────────────────────────────────────────────────────────────────────

log_msg("Cleaning...")

cleaned <- raw %>%
  clean_names() %>%

  # TODO: confirm exact column names from actual EPA download
  select(
    state_code,
    county_code,
    state_name,
    county_name,
    # TODO: confirm year column name — may be derived from file or in a "year" column
    # year,
    latitude,
    longitude,
    parameter_name,
    sample_duration,
    arithmetic_mean,    # annual mean PM2.5 concentration — this is the key metric
    observation_count,
    observation_percent,
    units_of_measure
  ) %>%

  # Build 5-digit FIPS code to match CDC PLACES join key
  # TODO: verify zero-padding — state_code is 2 digits, county_code is 3 digits
  mutate(
    county_fips = paste0(
      str_pad(as.character(state_code),  2, pad = "0"),
      str_pad(as.character(county_code), 3, pad = "0")
    ),
    # TODO: extract year — may be in filename or a column
    # year = as.integer(year),
    arithmetic_mean = as.numeric(arithmetic_mean),
    loaded_at = Sys.time()
  ) %>%

  # Keep only PM2.5 rows (should already be filtered if you downloaded the PM2.5 file)
  # TODO: confirm filter is needed or data is already PM2.5-only
  # filter(str_detect(parameter_name, "PM2.5"))

  filter(!is.na(arithmetic_mean))

log_msg(sprintf("Cleaned: %d station-year rows across %d counties",
  nrow(cleaned),
  n_distinct(cleaned$county_fips)))

# ── Load ───────────────────────────────────────────────────────────────────────

con <- get_con()
on.exit(dbDisconnect(con))

dbWithTransaction(con, {
  dbWriteTable(con,
    name = Id(schema = TARGET_SCHEMA, table = TARGET_TABLE),
    value = cleaned,
    append = TRUE,     # TODO: set to FALSE on first run
    row.names = FALSE
  )
})

log_msg(sprintf("Loaded %d rows into %s.%s", nrow(cleaned), TARGET_SCHEMA, TARGET_TABLE))

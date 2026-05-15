# CDC PLACES County Data — ingestion script
# Reads CSV (local or S3), cleans, loads into raw.places_county on PostgreSQL
#
# Source: https://data.cdc.gov/resource/swc5-untb.csv?$limit=500000
# File already downloaded to data/raw/places_county.csv

source(here::here("ingestion/utils.R"))
library(tidyverse)
library(janitor)

TARGET_TABLE <- "places_county"
TARGET_SCHEMA <- "raw"

# ── Read ───────────────────────────────────────────────────────────────────────

log_msg("Reading CDC PLACES county file...")
raw <- read_raw_file("places_county.csv")

# ── Clean ─────────────────────────────────────────────────────────────────────

# Source columns (after clean_names()):
#   locationid, stateabbr, statedesc, locationname, year,
#   category, categoryid, measure, measureid, short_question_text,
#   data_value_type, datavaluetypeid, data_value,
#   low_confidence_limit, high_confidence_limit,
#   totalpopulation, totalpop18plus, geolocation
#
# Target column names:
#   locationid       → county_fips   (5-digit FIPS — pad leading zeros)
#   stateabbr        → state_abbr
#   statedesc        → state_name
#   locationname     → county_name
#   measureid        → measure_id
#   categoryid       → category_id
#   datavaluetypeid  → data_value_type_id
#   totalpopulation  → population_count

log_msg("Cleaning...")

cleaned <- raw %>%

  # [PART 3 · STEP 3.1] clean_names() and select columns
  # Call clean_names() to normalize column names
  # Then select() only the columns listed above (source names, before rename)

  # [PART 3 · STEP 3.2] Rename columns to target names
  # Use rename() to map source → target names per the table above

  # [PART 3 · STEP 3.3] Cast types and pad county_fips
  # mutate():
  #   data_value, low_confidence_limit, high_confidence_limit → as.numeric()
  #   population_count → as.integer()
  #   year → as.integer()
  #   county_fips → str_pad(as.character(county_fips), 5, pad = "0")
  #   loaded_at = Sys.time()

  # [PART 3 · STEP 3.4] Filter null data_value rows
  # filter(!is.na(data_value))

  NULL  # remove this line when implementing

log_msg(sprintf("Cleaned: %d rows", nrow(cleaned)))

# ── Load ───────────────────────────────────────────────────────────────────────

con <- get_con()
on.exit(dbDisconnect(con))

# [PART 3 · STEP 3.5] Create schema and load table
# dbExecute(con, "CREATE SCHEMA IF NOT EXISTS raw")
# dbWriteTable(con,
#   name      = Id(schema = TARGET_SCHEMA, table = TARGET_TABLE),
#   value     = cleaned,
#   overwrite = TRUE,
#   row.names = FALSE
# )

log_msg(sprintf("Loaded %d rows into %s.%s", nrow(cleaned), TARGET_SCHEMA, TARGET_TABLE))

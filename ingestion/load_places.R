# CDC PLACES County Data — ingestion script
# Reads CSV (local or S3), cleans, loads into raw.places_county on PostgreSQL
#
# Source: https://data.cdc.gov/500-Cities-Places/PLACES-Local-Data-for-Better-Health-County-Data-20/swc5-untb
# Download bulk CSV from that page and drop in data/raw/places_county.csv
#
# Schema target: raw.places_county (created by dbt seed + raw table migration, or first-run CREATE)

source(here::here("ingestion/utils.R"))
library(tidyverse)
library(janitor)

TARGET_TABLE <- "places_county"
TARGET_SCHEMA <- "raw"

# ── Read ───────────────────────────────────────────────────────────────────────

log_msg("Reading CDC PLACES county file...")
raw <- read_raw_file("places_county.csv")

# ── Inspect (run manually first time to confirm column names) ─────────────────
# glimpse(raw)
# Expected columns (verify against actual download):
#   StateAbbr, StateDesc, LocationName, DataSource, Category, Measure,
#   Data_Value_Unit, DataValueTypeID, Data_Value_Type, Data_Value,
#   Low_Confidence_Limit, High_Confidence_Limit, Data_Value_Footnote_Symbol,
#   Data_Value_Footnote, PopulationCount, GeoLocation, CategoryID, MeasureId,
#   LocationID, Short_Question_Text, Year

# ── Clean ─────────────────────────────────────────────────────────────────────

log_msg("Cleaning...")

cleaned <- raw %>%
  clean_names() %>%                        # standardize column names to snake_case

  # TODO: confirm exact column names from actual download and adjust selects below
  select(
    state_abbr,
    state_desc,
    location_name,       # county name
    location_id,         # FIPS code — verify format (should be 5-digit string with leading zeros)
    year,
    category,
    measure,
    measure_id,
    short_question_text,
    data_value,
    low_confidence_limit,
    high_confidence_limit,
    data_value_type,
    population_count
  ) %>%

  # TODO: verify FIPS format — should be 5 chars with leading zero (e.g. "01001" not "1001")
  # mutate(location_id = str_pad(as.character(location_id), 5, pad = "0")) %>%

  mutate(
    data_value = as.numeric(data_value),
    year = as.integer(year),
    loaded_at = Sys.time()
  ) %>%

  # Drop rows with no data value — TODO: decide whether to keep suppressed values
  filter(!is.na(data_value))

log_msg(sprintf("Cleaned: %d rows, %d measures, years %s-%s",
  nrow(cleaned),
  n_distinct(cleaned$measure_id),
  min(cleaned$year, na.rm = TRUE),
  max(cleaned$year, na.rm = TRUE)))

# ── Load ───────────────────────────────────────────────────────────────────────

con <- get_con()
on.exit(dbDisconnect(con))

# TODO: create raw schema if not exists (run once manually or add here)
# dbExecute(con, "CREATE SCHEMA IF NOT EXISTS raw")

# Idempotency: skip years already loaded
years_to_load <- unique(cleaned$year)
# TODO: enable idempotency check once already_loaded() is implemented
# years_to_load <- years_to_load[!sapply(years_to_load, function(y) {
#   already_loaded(con, TARGET_TABLE, "year", y)
# })]

if (length(years_to_load) == 0) {
  log_msg("All years already loaded — skipping.")
} else {
  log_msg(sprintf("Loading years: %s", paste(years_to_load, collapse = ", ")))
  to_load <- filter(cleaned, year %in% years_to_load)

  dbWithTransaction(con, {
    # TODO: switch between append and overwrite based on idempotency logic
    dbWriteTable(con,
      name = Id(schema = TARGET_SCHEMA, table = TARGET_TABLE),
      value = to_load,
      append = TRUE,    # TODO: set to FALSE on first run, TRUE for incremental
      row.names = FALSE
    )
  })

  log_msg(sprintf("Loaded %d rows into %s.%s", nrow(to_load), TARGET_SCHEMA, TARGET_TABLE))
}

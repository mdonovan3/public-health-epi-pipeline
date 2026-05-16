# CDC PLACES County Data — ingestion script
# Reads CSV, loads into raw.places_county on PostgreSQL
# All column renaming, casting, and cleaning happens in dbt staging.
#
# Source: https://data.cdc.gov/resource/swc5-untb.csv?$limit=500000
# Drop a year file via: scripts/simulate_drop.sh <year> places → lands in data/raw/places_county.csv

source(here::here("ingestion/utils.R"))
library(tidyverse)

TARGET_TABLE <- "places_county"
TARGET_SCHEMA <- "raw"

# ── Read ───────────────────────────────────────────────────────────────────────

places_files <- list.files(here::here(cfg$data$raw_dir), pattern = "^places_county_", full.names = TRUE)
if (length(places_files) == 0) stop("No places_county_* file found in data/raw/ — run simulate_drop.sh first")
if (length(places_files) > 1) stop("Multiple PLACES files in data/raw/ — process one at a time: ", paste(basename(places_files), collapse = ", "))
log_msg(sprintf("Reading %s...", basename(places_files)))
raw <- read.csv(places_files, stringsAsFactors = FALSE, check.names = FALSE)

# ── Prepare ───────────────────────────────────────────────────────────────────

filtered <- raw %>%
  mutate(loaded_at = as.character(Sys.time())) %>%
  map_dfc(as.character)

log_msg(sprintf("Rows: %d", nrow(filtered)))

# ── Load ───────────────────────────────────────────────────────────────────────

con <- get_con()
on.exit(dbDisconnect(con))

invisible(dbExecute(con, "CREATE SCHEMA IF NOT EXISTS raw"))

incoming_year <- unique(filtered$year)
incoming_rows <- nrow(filtered)

table_exists <- dbExistsTable(con, Id(schema = TARGET_SCHEMA, table = TARGET_TABLE))

if (table_exists) {
  existing_rows <- dbGetQuery(con,
    "SELECT COUNT(*) AS n FROM raw.places_county WHERE year = $1",
    params = list(incoming_year)
  )$n

  #### check if the year's data is already in the database.
  #### if it is and the row count is the same as the dataframe, do nothing.
  #### If it exists, but different row count, drop and reinsert.
  #### If it is not in the DB at all, insert
  if (existing_rows == incoming_rows) {
    log_msg(sprintf("SKIP: Year %s already loaded (%d rows match).", incoming_year, incoming_rows))
    quit(save = "no", status = 0)
  } else if (existing_rows > 0) {
    log_msg(sprintf("Year %s exists with %d rows but incoming has %d — deleting and reinserting.", incoming_year, existing_rows, incoming_rows))
    invisible(dbExecute(con,
      "DELETE FROM raw.places_county WHERE year = $1",
      params = list(incoming_year)
    ))
  }

  #### check for any columns that may have been added to the datafiles that were not in prior years and create them
  new_cols <- setdiff(names(filtered), dbListFields(con, Id(schema = TARGET_SCHEMA, table = TARGET_TABLE)))

  walk(new_cols, \(col) {
    dbExecute(con, paste(
      "ALTER TABLE", paste0(dbQuoteIdentifier(con, TARGET_SCHEMA), ".", dbQuoteIdentifier(con, TARGET_TABLE)),
      "ADD COLUMN IF NOT EXISTS", dbQuoteIdentifier(con, col), "TEXT"
    ))
    log_msg(sprintf("Added column: %s", col))
  })
}

dbWriteTable(con,
  name      = Id(schema = TARGET_SCHEMA, table = TARGET_TABLE),
  value     = filtered,
  append    = TRUE,
  row.names = FALSE
)

log_msg(sprintf("Loaded %d rows into %s.%s", incoming_rows, TARGET_SCHEMA, TARGET_TABLE))

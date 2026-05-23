# EPA air quality ingestion script
# Reads one year of data from data/raw/epa_pm25_YYYY.csv, filters to
# PM2.5 (88101), Ozone (44201), and NO2 (42602), loads to raw.epa_pm25.
# Drop a year via: scripts/simulate_drop.sh <year> epa → lands in data/raw/
#
# Source: https://aqs.epa.gov/aqsweb/airdata/annual_conc_by_monitor_YYYY.zip

source(here::here("ingestion/utils.R"))
library(tidyverse)
TARGET_TABLE <- "epa_pm25"
TARGET_SCHEMA <- "raw"

# ── Read ───────────────────────────────────────────────────────────────────────

epa_files <- list.files(here::here(cfg$data$raw_dir), pattern = "^epa_pm25_", full.names = TRUE)
if (length(epa_files) == 0) stop("No epa_pm25_* file found in data/raw/ — run simulate_drop.sh first")
if (length(epa_files) > 1) stop("Multiple EPA files in data/raw/ — process one at a time: ", paste(basename(epa_files), collapse = ", "))
log_msg(sprintf("Reading %s...", basename(epa_files)))
raw <- read.csv(epa_files, stringsAsFactors = FALSE, check.names = FALSE)

# ── Filter ────────────────────────────────────────────────────────────────────
# 88101 = PM2.5  44201 = Ozone  42602 = NO2
filtered <- raw %>%
  filter(`Parameter Code` %in% c(88101, 44201, 42602)) %>%
  mutate(loaded_at = as.character(Sys.time())) %>%
  map_dfc(as.character)

log_msg(sprintf("Filtered: %d rows", nrow(filtered)))

# ── Load ───────────────────────────────────────────────────────────────────────

con <- get_con()
on.exit(dbDisconnect(con))

invisible(dbExecute(con, "CREATE SCHEMA IF NOT EXISTS raw"))

incoming_year <- unique(filtered$Year)
incoming_rows <- nrow(filtered)

table_exists  <- dbExistsTable(con, Id(schema = TARGET_SCHEMA, table = TARGET_TABLE))
existing_rows <- 0L

if (table_exists) {
  existing_rows <- dbGetQuery(con,
    "SELECT COUNT(*) AS n FROM raw.epa_pm25 WHERE \"Year\" = $1",
    params = list(incoming_year)
  )$n

  if (existing_rows == incoming_rows) {
    log_msg(sprintf("SKIP: Year %s already loaded (%d rows match).", incoming_year, incoming_rows))
    quit(save = "no", status = 0)
  }
}

dbWithTransaction(con, {

  if (existing_rows > 0) {
    log_msg(sprintf("Year %s exists with %d rows but incoming has %d — deleting and reinserting.", incoming_year, existing_rows, incoming_rows))
    invisible(dbExecute(con,
      "DELETE FROM raw.epa_pm25 WHERE \"Year\" = $1",
      params = list(incoming_year)
    ))
  }

  if (table_exists) {
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

})

log_msg(sprintf("Loaded %d rows into %s.%s", incoming_rows, TARGET_SCHEMA, TARGET_TABLE))

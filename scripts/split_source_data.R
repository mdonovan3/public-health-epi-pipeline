# Split full source files into per-year batch files
# Run once after downloading source data.
# Output lands in data/source/batches/ — one file per dataset × year.
#
# Usage: Rscript scripts/split_source_data.R

library(tidyverse)
library(here)

SOURCE_DIR  <- here("data/source")
BATCHES_DIR <- here("data/source/batches")
dir.create(BATCHES_DIR, showWarnings = FALSE, recursive = TRUE)

cat("=== Splitting source data into year batches ===\n\n")

# ── CDC PLACES ────────────────────────────────────────────────────────────────
# Source files and the years each one contains:
#
#   places_county_full.csv          → 2022, 2023
#   places_county_2020_2021_full.csv → 2020, 2021
#   places_county_2019_full.csv     → 2019

places_files <- list(
  "places_county_full.csv",
  "places_county_2020_2021_full.csv",
  "places_county_2019_full.csv"
)

for (fname in places_files) {
  path <- file.path(SOURCE_DIR, fname)
  if (!file.exists(path)) {
    cat(sprintf("  SKIP (not found): %s\n", fname))
    next
  }

  cat(sprintf("Reading %s...\n", fname))
  df <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)

  years <- sort(unique(df$year))
  cat(sprintf("  Years found: %s\n", paste(years, collapse = ", ")))

  for (yr in years) {
    out_path <- file.path(BATCHES_DIR, sprintf("places_county_%s.csv", yr))
    write.csv(df[df$year == yr, ], out_path, row.names = FALSE)
    n <- nrow(df[df$year == yr, ])
    cat(sprintf("  Wrote: places_county_%s.csv (%d rows)\n", yr, n))
  }
}

# ── EPA PM2.5 ─────────────────────────────────────────────────────────────────
# One file per year already — filter to PM2.5 (88101), Ozone (44201), NO2 (42602)
# and copy to batches/ so everything is in one place.
#
# Source files:
#   epa_pm25_2019_full.csv → 2019
#   epa_pm25_2020_full.csv → 2020
#   epa_pm25_2021_full.csv → 2021
#   epa_pm25_2022_full.csv → 2022
#   epa_pm25_2023_full.csv → 2023
#   epa_pm25_2024_full.csv → 2024

epa_years <- 2019:2024

for (yr in epa_years) {
  fname <- sprintf("epa_pm25_%s_full.csv", yr)
  path  <- file.path(SOURCE_DIR, fname)

  if (!file.exists(path)) {
    cat(sprintf("  SKIP (not found): %s\n", fname))
    next
  }

  cat(sprintf("Reading %s...\n", fname))
  df <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)

  # Filter to PM2.5 (88101), Ozone (44201), NO2 (42602)
  if ("Parameter Code" %in% names(df)) {
    df <- df[df$`Parameter Code` %in% c(88101, 44201, 42602), ]
  }

  out_path <- file.path(BATCHES_DIR, sprintf("epa_pm25_%s.csv", yr))
  write.csv(df, out_path, row.names = FALSE)
  cat(sprintf("  Wrote: epa_pm25_%s.csv (%d PM2.5 rows)\n", yr, nrow(df)))
}

cat("\nDone. Batches written to data/source/batches/\n")
cat("Run scripts/simulate_drop.sh <year> to drop a year into data/source/\n")

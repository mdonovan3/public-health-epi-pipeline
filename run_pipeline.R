# Master pipeline orchestrator
# Drop data files in data/raw/, then run this script.
# Runs: ingestion → dbt seed → dbt run → dbt test
#
# Usage:
#   Local:  Rscript run_pipeline.R
#   Prod:   R_CONFIG_ACTIVE=production Rscript run_pipeline.R
#   Cron:   see cron/poll_and_run.sh

library(config)
library(here)

cfg <- config::get()
cat(sprintf("\n=== Pipeline starting [env: %s] ===\n\n", cfg$env))

# ── Step 1: Ingest raw data ───────────────────────────────────────────────────

cat("-- Step 1: Ingestion\n")
source(here("ingestion/load_places.R"))
source(here("ingestion/load_epa_pm25.R"))

# TODO: add additional source scripts here as new datasets are added

# ── Step 2: dbt seed (reference tables) ──────────────────────────────────────

cat("\n-- Step 2: dbt seed\n")
dbt_profile <- cfg$dbt$target
system(paste("cd", here("dbt"), "&& dbt seed --target", dbt_profile))

# ── Step 3: dbt run (staging → intermediate → marts) ─────────────────────────

cat("\n-- Step 3: dbt run\n")
system(paste("cd", here("dbt"), "&& dbt run --target", dbt_profile))

# ── Step 4: dbt test ──────────────────────────────────────────────────────────

cat("\n-- Step 4: dbt test\n")
system(paste("cd", here("dbt"), "&& dbt test --target", dbt_profile))

# ── Step 5: Render Quarto report ──────────────────────────────────────────────

cat("\n-- Step 5: Quarto render\n")
# TODO: decide output destination for prod (S3? shinyapps.io? static host?)
system(paste("cd", here("quarto"), "&& quarto render epi_report.qmd"))

cat("\n=== Pipeline complete ===\n")

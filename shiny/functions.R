# Shiny helper functions — DB queries, data loading
# Sourced by app.R

library(config)
library(DBI)
library(RPostgres)

cfg <- config::get()

# ── DB connection ──────────────────────────────────────────────────────────────

get_con <- function() {
  dbConnect(
    RPostgres::Postgres(),
    host     = cfg$db$host,
    port     = cfg$db$port,
    dbname   = cfg$db$dbname,
    user     = cfg$db$user,
    password = Sys.getenv("DB_PASSWORD_EPI")
  )
}

# ── Load mart data ─────────────────────────────────────────────────────────────

load_mart_data <- function(year_filter = NULL) {
  con <- get_con()
  on.exit(dbDisconnect(con))

  query <- "SELECT * FROM marts.mart_epi_analysis"

  # [PART 12 · STEP 12.1] Add year filter when provided
  # if (!is.null(year_filter)) {
  #   query <- paste0(query, " WHERE year = $1")
  #   return(dbGetQuery(con, query, list(year_filter)))
  # }

  dbGetQuery(con, query)
}

# ── Most recent year in mart ───────────────────────────────────────────────────

max_available_year <- function() {
  con <- get_con()
  on.exit(dbDisconnect(con))

  # [PART 12 · STEP 12.2] Query mart for most recent year
  # dbGetQuery(con, "SELECT MAX(year) FROM marts.mart_epi_analysis")[[1]]

  2021  # placeholder — replace with real query above
}

# Shiny helper functions — DB queries, data loading
# Sourced by app.R

library(config)
library(DBI)
library(RPostgres)

cfg <- config::get()

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

# Load mart data — optionally filtered to a specific year
load_mart_data <- function(year_filter = NULL) {
  con <- get_con()
  on.exit(dbDisconnect(con))

  query <- "SELECT * FROM marts.mart_epi_analysis"

  # TODO: add year filter when called for initial load
  # if (!is.null(year_filter)) {
  #   query <- paste0(query, " WHERE year = $1")
  #   return(dbGetQuery(con, query, list(year_filter)))
  # }

  dbGetQuery(con, query)
}

# Return most recent available year in the mart
max_available_year <- function() {
  con <- get_con()
  on.exit(dbDisconnect(con))
  # TODO: implement
  # dbGetQuery(con, "SELECT MAX(year) FROM marts.mart_epi_analysis")[[1]]
  2021  # placeholder
}

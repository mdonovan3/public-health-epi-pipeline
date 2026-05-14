# Shared utilities — DB connection, file reading (local or S3), logging
# All ingestion scripts source this file first.

library(config)
library(DBI)
library(RPostgres)

cfg <- config::get()

# ── Database connection ────────────────────────────────────────────────────────

get_con <- function() {
  dbConnect(
    RPostgres::Postgres(),
    host     = cfg$db$host,
    port     = cfg$db$port,
    dbname   = cfg$db$dbname,
    user     = cfg$db$user,
    password = Sys.getenv("DB_PASSWORD")
  )
}

# ── File reading — local or S3 depending on config ────────────────────────────

read_raw_file <- function(filename) {
  if (cfg$data$source == "s3") {
    # TODO: implement S3 read
    # library(aws.s3)
    # key <- paste0(cfg$data$prefix, filename)
    # s3read_using(read.csv, object = key, bucket = cfg$data$bucket)
    stop("S3 read not yet implemented")
  } else {
    path <- file.path(cfg$data$raw_dir, filename)
    if (!file.exists(path)) stop(paste("File not found:", path))
    read.csv(path, stringsAsFactors = FALSE)
  }
}

# ── Idempotency guard ──────────────────────────────────────────────────────────
# Returns TRUE if data for this source + year already exists in raw schema.

already_loaded <- function(con, table, year_col = "year", year_val) {
  # TODO: implement — query raw table for existing year, return TRUE/FALSE
  # Example:
  # res <- dbGetQuery(con, paste0("SELECT COUNT(*) FROM raw.", table,
  #                               " WHERE ", year_col, " = $1"), list(year_val))
  # res[[1]] > 0
  FALSE  # placeholder — always loads until implemented
}

# ── Logging ───────────────────────────────────────────────────────────────────

log_msg <- function(msg) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), msg))
}

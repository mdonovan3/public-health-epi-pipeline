# Shared utilities — DB connection, file reading (local or S3), logging
# All ingestion scripts source this file first.

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
    password = Sys.getenv("DB_PASSWORD_EPI"),
    options  = "-c client_min_messages=warning"
  )
}

# ── File reading — local or S3 depending on config ────────────────────────────

read_raw_file <- function(filename) {
  if (cfg$data$source == "s3") {

    # [PART 2 · STEP 2.2] Implement S3 read
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

already_loaded <- function(con, table, year_col = "year", year_val) {

  # [PART 2 · STEP 2.1] Check if data for this year already exists in raw schema
  # Query raw.<table> for COUNT(*) WHERE <year_col> = year_val
  # Return TRUE if count > 0, FALSE otherwise
  # Use dbGetQuery() with a parameterized query (list(year_val) as params)

  FALSE  # placeholder — always loads until implemented
}

# ── Logging ───────────────────────────────────────────────────────────────────

log_msg <- function(msg) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), msg))
}

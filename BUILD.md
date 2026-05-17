# Build Instructions — Public Health Epi Pipeline

Complete each step in order. Section numbers match comment blocks in the code files.
Format: `[PART X · STEP X.Y]` in both this document and the code.

---

## PART 1 — Environment Setup

Files: `config.yml`, `dbt/profiles.yml`, `~/.Renviron`

### [1.1] Create the database on RDS

Connect to `lhrc-db.ctzgidhxuwis.us-east-1.rds.amazonaws.com` with DataGrip or psql
and run:

```sql
CREATE DATABASE epi_pipeline;
```

Then verify the connection in DataGrip. The user `inventory` already exists on that server.

### [1.2] Add DB_PASSWORD_EPI to ~/.Renviron

Open or create `~/.Renviron` and add:

```
DB_PASSWORD_EPI=your_password_here
```

Then restart R. Verify with `Sys.getenv("DB_PASSWORD_EPI")`.

### [1.3] Verify config.yml

Open `config.yml`. The database name, host, and user are already filled in.
The S3 bucket in the production block is still `TODO_BUCKET_NAME` — leave it for now
unless you're wiring up prod. No changes needed for local development.

### [1.4] Verify dbt profiles.yml

Open `dbt/profiles.yml`. Host, port, dbname, and user are already set.
Password reads from env var `DB_PASSWORD_EPI` — that's handled by step 1.2.
No changes needed.

### [1.5] Install R packages

From an R console in the project root:

```r
install.packages(c(
  "config", "here", "tidyverse", "janitor",
  "DBI", "RPostgres",
  "shiny", "shinydashboard", "reactable", "reactablefmtr",
  "fresh", "future", "promises",
  "gt"
))
```

Install dbt (once, system-level):

```bash
pip install dbt-postgres
```

---

## PART 2 — Ingestion Utilities

File: `ingestion/utils.R`

These are shared helpers used by both ingestion scripts. The DB connection and
logging functions are already implemented. Two stubs remain.

### [2.1] Idempotency guard — already_loaded()

`ingestion/utils.R` → block marked `[PART 2 · STEP 2.1]`

Implement `already_loaded()` to query the raw table and return TRUE if data
for that year already exists. This prevents double-loading when the pipeline reruns.
Use `dbGetQuery()` with a parameterized query checking COUNT(*) WHERE year = year_val.

### [2.2] S3 file read (optional — prod only)

`ingestion/utils.R` → block marked `[PART 2 · STEP 2.2]`

The `stop("S3 read not yet implemented")` line is the stub. Implement using
`aws.s3::s3read_using()` with `read.csv`. Only needed when `cfg$data$source == "s3"`.
Skip for now if not setting up prod.

---

## PART 3 — Ingest CDC PLACES

File: `ingestion/load_places.R`

Reads `data/raw/places_county.csv` (229,299 rows), cleans, and loads to `raw.places_county`.

### [3.1] Select and normalize column names

`ingestion/load_places.R` → block marked `[PART 3 · STEP 3.1]`

Call `clean_names()` on `raw`, then `select()` the columns listed in the comment block.
Source column names are already documented there.

### [3.2] Rename columns to target names

`ingestion/load_places.R` → block marked `[PART 3 · STEP 3.2]`

Use `rename()` to map source names to target names as documented in the comment.
Primary rename: `locationid → county_fips`, `stateabbr → state_abbr`, etc.

### [3.3] Cast types and pad FIPS

`ingestion/load_places.R` → block marked `[PART 3 · STEP 3.3]`

Use `mutate()` to:
- Cast `data_value`, `low_confidence_limit`, `high_confidence_limit` to numeric
- Cast `population_count` to integer, `year` to integer
- Pad `county_fips` to 5 chars: `str_pad(as.character(county_fips), 5, pad = "0")`
- Add `loaded_at = Sys.time()`

### [3.4] Filter null values

`ingestion/load_places.R` → block marked `[PART 3 · STEP 3.4]`

Add `filter(!is.na(data_value))` after the mutate block.

### [3.5] Load to database

`ingestion/load_places.R` → block marked `[PART 3 · STEP 3.5]`

Create schema and write table:

```r
dbExecute(con, "CREATE SCHEMA IF NOT EXISTS raw")
dbWriteTable(con,
  name      = Id(schema = TARGET_SCHEMA, table = TARGET_TABLE),
  value     = cleaned,
  overwrite = TRUE,
  row.names = FALSE
)
```

---

## PART 4 — Ingest EPA PM2.5

File: `ingestion/load_epa_pm25.R`

Reads `data/raw/epa_pm25_annual.csv` (all pollutants), filters to PM2.5 (88101),
Ozone (44201), and NO2 (42602), and loads station-level rows to `raw.epa_pm25`.

### [4.1] Filter to pollutants of interest

`ingestion/load_epa_pm25.R` → block marked `[PART 4 · STEP 4.1]`

`filter(Parameter.Code %in% c(88101, 44201, 42602))` — keeps PM2.5 FRM/FEM, Ozone, and NO2.
The file contains CO, SO2, and other pollutants that are excluded.

### [4.2] Select columns

`ingestion/load_epa_pm25.R` → block marked `[PART 4 · STEP 4.2]`

Use `select()` to keep the columns listed in the comment block:
`state_code`, `county_code`, `year`, `latitude`, `longitude`, `arithmetic_mean`,
`observation_count`, `observation_percent`, `completeness_indicator`,
`parameter_name`, `sample_duration`, `pollutant_standard`.

### [4.3] Build county_fips and cast types

`ingestion/load_epa_pm25.R` → block marked `[PART 4 · STEP 4.3]`

Use `mutate()` to:
- Build `county_fips = paste0(str_pad(state_code, 2, pad="0"), str_pad(county_code, 3, pad="0"))`
- Cast arithmetic_mean, observation_percent to numeric; observation_count to integer
- Cast year to integer; latitude, longitude to numeric
- Add `loaded_at = Sys.time()`

### [4.4] Filter null PM2.5 values

`ingestion/load_epa_pm25.R` → block marked `[PART 4 · STEP 4.4]`

Add `filter(!is.na(arithmetic_mean))` after the mutate block.

### [4.5] Load to database

`ingestion/load_epa_pm25.R` → block marked `[PART 4 · STEP 4.5]`

Same pattern as step 3.5 — create schema if needed, then `dbWriteTable()` with overwrite = TRUE.

---

## PART 5 — dbt Seeds

Files: `dbt/seeds/fips_reference.csv`, `dbt/seeds/places_measures.csv`

Seeds are static CSV reference tables loaded into the database by dbt. They don't change
with the raw data — add them once.

### [5.1] Populate fips_reference.csv

`dbt/seeds/fips_reference.csv` → add rows

Headers are already in the file. Add rows mapping `county_fips` to `state_fips`,
`state_abbr`, `state_name`, `county_name`. Source: Census Bureau FIPS list or
use the data already in raw.places_county after ingestion as a cross-reference.

### [5.2] Populate places_measures.csv

`dbt/seeds/places_measures.csv` → add rows

Headers: `measure_id`, `measure`, `category`, `short_question_text`.
The full list of 39 measure_ids is documented in `mart_epi_analysis.sql`.
Pull the distinct values from the raw data after ingestion, or enter manually.

### [5.3] Run dbt seed

```bash
cd dbt
dbt seed --target dev
```

Verify the tables appear in the `public` schema of the `epi_pipeline` database.

---

## PART 6 — dbt Staging: CDC PLACES

File: `dbt/models/staging/stg_places_county.sql`

### [6.1] Select and cast columns

`dbt/models/staging/stg_places_county.sql` → block marked `[PART 6 · STEP 6.1]`

Replace the `null as placeholder` with the actual column list. Cast:
- `year`, `population_count` → integer
- `data_value`, `ci_low`, `ci_high` → numeric

Column mapping is documented in the comment block above the select.
The `age_adjusted` CTE and `where data_value_type_id = 'AgeAdjPrv'` filter are already in place — leave them.

---

## PART 7 — dbt Staging: EPA PM2.5

File: `dbt/models/staging/stg_epa_pm25.sql`

### [7.1] Select and cast columns

`dbt/models/staging/stg_epa_pm25.sql` → block marked `[PART 7 · STEP 7.1]`

Replace `null as placeholder` with the column list. Rename:
- `arithmetic_mean → pm25_mean`
- `observation_count → obs_count`
- `observation_percent → obs_pct`

Cast all numerics. The `obs_pct >= 75` coverage filter CTE is already in place — leave it.

---

## PART 8 — dbt Intermediate: Join PLACES + PM2.5

File: `dbt/models/intermediate/int_places_epa_join.sql`

### [8.1] Aggregate PM2.5 to county-year

`dbt/models/intermediate/int_places_epa_join.sql` → block marked `[PART 8 · STEP 8.1]`

In the `pm25_county_year` CTE, replace the placeholder with:
- `GROUP BY county_fips, year`
- `avg(pm25_mean) as pm25_annual_mean`
- `count(*) as station_count`
- `avg(obs_pct) as avg_obs_pct`

### [8.2] Left join PLACES to PM2.5

`dbt/models/intermediate/int_places_epa_join.sql` → block marked `[PART 8 · STEP 8.2]`

In the `joined` CTE:
- `p.*` for all PLACES columns
- `e.pm25_annual_mean`, `e.station_count as pm25_station_count`, `e.avg_obs_pct as pm25_avg_coverage`
- `case when e.county_fips is null then true else false end as missing_pm25`
- LEFT JOIN on `p.county_fips = e.county_fips AND p.year = e.year`

Left join preserves all PLACES rows even for counties with no PM2.5 monitor.

---

## PART 9 — dbt Mart: Wide Analysis Table

File: `dbt/models/marts/mart_epi_analysis.sql`

This is the pivot step — long format (one row per measure) → wide (one row per county × year).
Pattern for each measure: `max(case when measure_id = 'OBESITY' then data_value end) as obesity_pct`

### [9.1] Dimension columns

`dbt/models/marts/mart_epi_analysis.sql` → block marked `[PART 9 · STEP 9.1]`

Select: `county_fips`, `state_abbr`, `state_name`, `county_name`, `year`,
`population_count`, `pm25_annual_mean`, `pm25_station_count`, `missing_pm25`.

### [9.2] Pivot health outcomes

`dbt/models/marts/mart_epi_analysis.sql` → block marked `[PART 9 · STEP 9.2]`

Use the CASE WHEN pattern for: `OBESITY`, `DIABETES`, `CHD`, `STROKE`, `COPD`,
`CASTHMA`, `CANCER`, `DEPRESSION`, `HIGHCHOL`, `BPHIGH`.
Name columns with `_pct` suffix (e.g., `obesity_pct`).

### [9.3] Pivot behavioral risk factors

`dbt/models/marts/mart_epi_analysis.sql` → block marked `[PART 9 · STEP 9.3]`

Same pattern for: `CSMOKING → smoking_pct`, `BINGE → binge_drinking_pct`,
`LPA → physical_inactivity_pct`, `SLEEP → short_sleep_pct`.

### [9.4] Pivot social determinants

`dbt/models/marts/mart_epi_analysis.sql` → block marked `[PART 9 · STEP 9.4]`

Same pattern for: `ACCESS2 → no_insurance_pct`, `FOODINSECU → food_insecurity_pct`,
`MHLTH → mental_distress_pct`. Add more from the full list in the comment block as needed.

### [9.5] Confidence intervals and GROUP BY

`dbt/models/marts/mart_epi_analysis.sql` → block marked `[PART 9 · STEP 9.5]`

Add CI columns for your primary pair (e.g., obesity and asthma):
`max(case when measure_id = 'OBESITY' then ci_low end) as obesity_ci_low`

GROUP BY all non-aggregated columns from step 9.1.

---

## PART 10 — dbt Tests

Files: `dbt/tests/assert_fips_format.sql`, `dbt/models/staging/schema.yml` (to create)

### [10.1] FIPS format test (already written)

`dbt/tests/assert_fips_format.sql` is complete — returns rows where `length(county_fips) != 5`.
dbt fails the test if any rows are returned. Run with `dbt test`.

### [10.2] Add schema.yml for column-level tests

Create `dbt/models/staging/schema.yml`. Add `not_null` and `unique` tests for key columns.
Example structure:

```yaml
version: 2
models:
  - name: stg_places_county
    columns:
      - name: county_fips
        tests:
          - not_null
      - name: measure_id
        tests:
          - not_null
```

### [10.3] Run all tests

```bash
cd dbt
dbt test --target dev
```

Fix any failures before moving to the output layer.

---

## PART 11 — Quarto Report

File: `quarto/epi_report.qmd`

The setup chunk (DB connection + mart load) is already written. Fill in the analysis chunks.

### [11.1] Data summary table

`quarto/epi_report.qmd` → chunk `summary-table` marked `[PART 11 · STEP 11.1]`

Build a `gt` table showing: n counties, n states, year range, % counties with PM2.5 data.
The placeholder `summarise()` block is already there — wrap it in `gt()` with column labels.

### [11.2] Prevalence table

`quarto/epi_report.qmd` → chunk `prevalence-table` marked `[PART 11 · STEP 11.2]`

`gt` table with one row per PLACES measure showing national median prevalence + IQR.
Use `pivot_longer()` to reshape the wide mart back to long for this summary.

### [11.3] PM2.5 distribution plot

`quarto/epi_report.qmd` → chunk `pm25-distribution` marked `[PART 11 · STEP 11.3]`

`ggplot` histogram of `pm25_annual_mean` across counties.
Filter to `!is.na(pm25_annual_mean)` first.

### [11.4] Scatter: PM2.5 vs. outcome

`quarto/epi_report.qmd` → chunk `scatter-pm25-outcome` marked `[PART 11 · STEP 11.4]`

`ggplot` scatter — `x = pm25_annual_mean`, `y = obesity_pct` (or your chosen outcome).
Add `geom_smooth(method = "lm")` trend line. This is descriptive only.

### [11.5] County summary table

`quarto/epi_report.qmd` → chunk `county-table` marked `[PART 11 · STEP 11.5]`

Searchable table using `DT::datatable()` or `gt`. Filter to most recent year.
Columns: state, county, year, pm25_annual_mean, obesity_pct, diabetes_pct, smoking_pct.

### [11.6] Render locally

```bash
cd quarto
quarto render epi_report.qmd
```

Opens as `epi_report.html` in the quarto/ folder.

---

## PART 12 — Shiny: Data Functions

File: `shiny/functions.R`

### [12.1] Year filter in load_mart_data()

`shiny/functions.R` → block marked `[PART 12 · STEP 12.1]`

Uncomment and complete the `if (!is.null(year_filter))` block.
Use a parameterized query: `dbGetQuery(con, query, list(year_filter))`.

### [12.2] Implement max_available_year()

`shiny/functions.R` → block marked `[PART 12 · STEP 12.2]`

Replace the `2021` placeholder. Query:
`dbGetQuery(con, "SELECT MAX(year) FROM marts.mart_epi_analysis")[[1]]`

---

## PART 13 — Shiny: Dashboard App

File: `shiny/app.R`

Reference: look at `RestaurantAnalyticsDashboard` in the wlm-shiny project for the
`fresh` theme, skeleton shimmer, and `future`/`promises` async pattern.

### [13.1] Define fresh theme

`shiny/app.R` → block marked `[PART 13 · STEP 13.1]`

Create a `fresh` theme using `create_theme()`. Suggest a clean light/academic feel —
white background, muted blue accent. Apply with `use_theme(your_theme)` in `dashboardBody`.

### [13.2] Sidebar filter controls

`shiny/app.R` → block marked `[PART 13 · STEP 13.2]`

Uncomment and fill in the three `selectInput()` calls: state, year, measure.
Populate choices from `INIT_DATA` (e.g., `sort(unique(INIT_DATA$state_abbr))`).

### [13.3] Reactive filter logic

`shiny/app.R` → block marked `[PART 13 · STEP 13.3]`

Inside `filtered_data <- reactive({...})`, apply filters using `input$state_filter`,
`input$year_filter`, `input$measure_filter`. Return the filtered dataframe.

### [13.4] Background full dataset load

`shiny/app.R` → block marked `[PART 13 · STEP 13.4]`

Uncomment `load_mart_data()` (no year filter) inside `future_promise({...})`.
Update `full_data()` reactiveVal when the promise resolves.

### [13.5] Loading banner

`shiny/app.R` → block marked `[PART 13 · STEP 13.5]`

Render a banner or shimmer in `output$loading_banner` that shows while `full_data()`
is still NULL. Hide once data is loaded. See RestaurantAnalyticsDashboard skeleton pattern.

### [13.6] County table

`shiny/app.R` → block marked `[PART 13 · STEP 13.6]`

Build the `renderReactable()` for `output$county_table` from `filtered_data()`.
Add conditional color formatting on `pm25_annual_mean` and disease rate columns.
Use `reactablefmtr` color scale helpers.

### [13.7] Value boxes

`shiny/app.R` → block marked `[PART 13 · STEP 13.7]`

Uncomment and implement `output$vbox_pm25`, `output$vbox_obesity`, `output$vbox_diabetes`.
Show national median of each measure from `filtered_data()`.

### [13.8] Scatter plot

`shiny/app.R` → block marked `[PART 13 · STEP 13.8]`

Implement `output$scatter_pm25` using `renderPlot()`.
`ggplot` scatter: `x = pm25_annual_mean`, `y` = selected measure from `input$measure_filter`.
Add `geom_smooth(method = "lm")`.

---

## PART 14 — Run and Verify

### [14.1] Full pipeline run

From the project root:

```r
Rscript run_pipeline.R
```

This runs ingestion → dbt seed → dbt run → dbt test → quarto render in sequence.
Watch for errors at each stage. Fix before continuing.

### [14.2] Spot-check the mart

Open DataGrip and query `marts.mart_epi_analysis`. Verify:
- Rows exist (should be ~3,000+ county × year combinations)
- `county_fips` is 5 chars everywhere
- `pm25_annual_mean` is not null for a reasonable share of rows
- Pivoted columns (obesity_pct, diabetes_pct, etc.) have values

### [14.3] Launch Shiny locally

```r
shiny::runApp("shiny/app.R")
```

### [14.4] Commit and push

When everything runs end to end:

```bash
git add -A
git commit -m "Complete pipeline implementation"
git push origin main
```

---

---

## PART 15 — Infrastructure as Code (EC2 Deployment)

Files: `infra/terraform/`

Provisions an EC2 instance on AWS running Airflow natively (not in Docker).
Bootstrap installs R, dbt, Airflow, clones the repo, initializes the Airflow
metadata DB, and starts scheduler + webserver as systemd services.
Source data is dropped into `data/raw/` via SCP; the Airflow DAG handles
ingestion → dbt → archive.

### [15.1] Fill in terraform.tfvars

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` — fill in `key_name`, `ami_id`, `vpc_id`, `subnet_id`,
`db_password`, and `airflow_admin_password`. Look up the current Amazon Linux
2023 AMI for us-east-1:

```bash
aws ec2 describe-images --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" \
  --query 'sort_by(Images,&CreationDate)[-1].ImageId' \
  --output text
```

### [15.2] Configure remote state (optional, recommended)

`infra/terraform/main.tf` → block marked `[PART 15 · STEP 15.2]`

Uncomment the `backend "s3"` block and set `bucket` to an existing S3 bucket.
Skip this for solo use — local state is fine.

### [15.3] Lock down SSH

`infra/terraform/main.tf` → ingress block marked `[PART 15 · STEP 15.3]`

Replace `0.0.0.0/0` with your IP: `["YOUR.IP.HERE/32"]`

### [15.4] Add IAM policies if needed

`infra/terraform/main.tf` → block marked `[PART 15 · STEP 15.4]`

Uncomment the SSM policy attachment if you want Session Manager access instead
of key-pair SSH. Add an S3 read/write policy if the pipeline reads source files
from S3 rather than local disk.

### [15.5] Apply

```bash
cd infra/terraform
terraform init
terraform plan
terraform apply
```

On completion:

```bash
terraform output ssh_command           # SSH into the instance
terraform output airflow_tunnel_command  # open Airflow UI via SSH tunnel
```

### [15.6] Verify bootstrap

Bootstrap takes ~10 minutes (Airflow + R packages). Tail the log:

```bash
sudo tail -f /var/log/user-data.log
```

When complete, verify:

```bash
systemctl status airflow-scheduler    # should be active (running)
systemctl status airflow-webserver    # should be active (running)
Rscript -e "library(RPostgres)"       # confirm R packages
dbt --version                         # confirm dbt
airflow version                       # confirm Airflow
```

### [15.7] Access the Airflow UI

Do not open port 8080 to the internet. Use an SSH tunnel instead:

```bash
# From your local machine (use terraform output airflow_tunnel_command):
ssh -L 8080:localhost:8080 -i ~/.ssh/<key>.pem ec2-user@<instance-ip>

# Then open in browser:
# http://localhost:8080  — login: admin / <airflow_admin_password>
```

Trigger the `epi_pipeline` DAG manually first to confirm it runs end-to-end
before scheduling it on a timer.

### [15.8] Whitelist instance IP in RDS security group

The RDS instance (lhrc-db) has a security group controlling inbound Postgres
access. Add a rule allowing port 5432 from the EC2 instance's public IP (from
`terraform output public_ip`), or preferably from its private IP if they share
a VPC.

---

## Quick reference: section → file map

| Section | File |
|---------|------|
| 1.1–1.5 | config.yml, dbt/profiles.yml, ~/.Renviron |
| 2.1–2.2 | ingestion/utils.R |
| 3.1–3.5 | ingestion/load_places.R |
| 4.1–4.5 | ingestion/load_epa_pm25.R |
| 5.1–5.3 | dbt/seeds/*.csv |
| 6.1     | dbt/models/staging/stg_places_county.sql |
| 7.1     | dbt/models/staging/stg_epa_pm25.sql |
| 8.1–8.2 | dbt/models/intermediate/int_places_epa_join.sql |
| 9.1–9.5 | dbt/models/marts/mart_epi_analysis.sql |
| 10.1–10.3 | dbt/tests/, dbt/models/staging/schema.yml |
| 11.1–11.6 | quarto/epi_report.qmd |
| 12.1–12.2 | shiny/functions.R |
| 13.1–13.8 | shiny/app.R |
| 14.1–14.4 | run_pipeline.R |
| 15.1–15.8 | infra/terraform/ |

# Public Health Epi Pipeline — Resume Notes

## What this is

A portfolio project designed to signal credibility to academic public health labs (Emory/Rollins, GSU, etc.).
Two public datasets, dbt transformation layer, Quarto report output. Modeled after how real epidemiology
pipelines are structured — not a Kaggle demo.

## Goal

Build something that looks like a real biostatistics lab pipeline:
- Exposure → outcome → confounding structure
- Reproducible, documented, county-level grain
- dbt for transformation, Quarto for output
- Targeted at PHPH 7525-style credibility and faculty/lab response

## Datasets

### Primary: CDC PLACES County Data
- URL: https://data.cdc.gov/500-Cities-Places/PLACES-Local-Data-for-Better-Health-County-Data-20/swc5-untb
- Format: county + year + measure + data_value (long/unpivoted)
- Key fields: StateAbbr, CountyName, Year, Measure, Data_Value, Low/High confidence limits
- Use: outcomes layer (chronic disease rates, behavioral risk factors)
- Why county: cleanest join key, standard epidemiology unit, faculty-legible

### Secondary: EPA AirData PM2.5 County Summary
- URL: https://www.epa.gov/outdoor-air-quality-data/download-daily-data
- API (optional): https://aqs.epa.gov/aqsweb/documents/data_api.html
- Format: daily summaries → aggregate to county-year average PM2.5
- Join key: county_fips + year (no spatial joins needed)
- Use: exposure layer (environmental health angle)
- Note: EPA doesn't provide a single clean county-year file — you download daily/annual summaries and aggregate in dbt

### Why NOT other datasets
- 500 Cities: outdated, narrower
- ZCTA/Place level: naming inconsistencies, extra complexity
- NHANES: individual-level microdata, overkill
- 3+ datasets: backfires in academic contexts — "2 sources done well > 5 sources messy"

## Data model (target)

```
Exposure:  county + year + pm25_avg         (stg_epa_pm25.sql)
Outcomes:  county + year + pivoted measures  (stg_places_county.sql)
Join:      int_places_epa_join.sql
Mart:      mart_epi_analysis.sql

county | year | pm25 | obesity_pct | diabetes_pct | smoking_pct
```

## Quarto output framing

- Exposure → outcome structure (PM2.5 → chronic disease)
- Regression models (linear/logistic at county level)
- Stratified epidemiology plots (urban/rural, regional)
- Confounding narrative: socioeconomic factors, urban/rural
- Should read like an MPH submission, not a data engineering demo

## Alternative secondary dataset (if EPA feels too environmental)

USDA Economic Research Service County Typology Data — income, rural/urban classification,
education, poverty rates. Better for "social determinants of health" framing vs. environmental.
Use if targeting social epi labs rather than environmental health labs.

## My observations

**Why this project makes sense for Martin specifically:**

1. dbt is already in the portfolio (demo-only, no public artifact, rated 4/10). This project
   creates a real public dbt artifact with actual staging/mart models and column-level tests.
   The EPA aggregation requirement is a genuine transformation problem, not just renaming columns.

2. R/Quarto is already demonstrated (inventory spot-check). A Quarto epi report shows Quarto
   in a second context — epidemiological rather than operational. That's a stronger signal.

3. County-level public health data is completely different domain from restaurant inventory,
   which shows generalizability of the pipeline skills. Faculty notice when someone can apply
   data infrastructure thinking to their domain.

4. The exposure-outcome-confounding structure is the exact framing needed for Emory/Rollins
   outreach. When reaching out to Ekenga or Chang, a working pipeline using the same data
   structure their lab uses is a much stronger intro than "I know R."

5. PostgreSQL is already running (RDS). Could ingest CDC PLACES + EPA into a new database
   on the same RDS instance. Keeps the infrastructure cost zero.

**Technical considerations when starting:**

- CDC PLACES API is available via Socrata (sodapy in Python or httr2 in R). Can also bulk download.
- EPA PM2.5 requires aggregating station-level readings to county-year. This is the interesting
  dbt step — not trivial, gives the project credibility.
- county_fips is the join key. CDC PLACES has FIPS embedded in LocationID. EPA files have FIPS
  explicitly. Verify format compatibility (leading zeros on state codes).
- Consider scope: start with one year (2020 or 2021) to validate the pipeline, then extend.
- Quarto regression: simple linear regression (county-level PM2.5 ~ obesity rate controlling for
  smoking) is enough. Don't need mixed models or Bayesian inference to make this credible.

**Positioning note:**

This should be framed as "research data infrastructure" not "data science project."
The story: I built the pipeline so a researcher could ask the question — not "I did the analysis."
That's the correct frame for research data support roles.

## Full pipeline scope (confirmed)

**Framing:** Light-to-mid data engineering + lab data support. Not claiming to be a data scientist.
"I built the pipeline, cleaned the data, and handed you a mart you can run a regression on."
Labs have statisticians. They rarely have someone who builds the infrastructure underneath.

**End-to-end demo target:**
Drop data files in a folder → run one script → pipeline runs, DB populates, dbt runs,
staging and marts are built → Quarto report and Shiny dashboard update automatically.

### Layers

**1. Ingestion — R scripts**
- User drops CDC PLACES CSV and EPA PM2.5 CSV into a `/data/raw/` folder
- R scripts read files, clean/normalize, load into PostgreSQL raw schema
- Same idempotent pattern as existing ETL pipelines (guard before insert, dbWithTransaction)
- Should handle re-runs cleanly — drop/reload or upsert

**2. dbt — transformation layer**
- Staging models: `stg_places_county.sql`, `stg_epa_pm25.sql`
- Intermediate: `int_places_epa_join.sql` (join on county_fips + year)
- Mart: `mart_epi_analysis.sql` — wide table: county | year | pm25 | obesity_pct | diabetes_pct | smoking_pct
- Column-level tests: not_null, unique on grain keys, accepted_values on year range, FIPS format check
- dbt docs/lineage as a deliverable in itself

**3. Quarto report — static output**
- Reads from mart (DBI query or dbt-generated CSV artifact)
- Descriptive summary tables (county × measure × year with confidence intervals)
- One simple plot (PM2.5 vs. chronic disease rate, scatter with state labels)
- Reads like a methods section / lab report — not a portfolio demo
- No regression required; the mart proves the pipeline works

**4. Shiny dashboard — interactive layer**
- County explorer: filter by state, year, measure
- Backed by same mart table
- Deploy to shinyapps.io for a shareable link

### Why the dbt tests matter
Data quality enforcement (not_null, unique, FIPS validation) IS the lab data manager artifact.
This is what a research data manager actually does — not the analysis, the infrastructure that
makes the analysis trustworthy.

### Why simple analysis is the right call
"I built the pipeline so a researcher could ask this question" is the correct framing.
Overclaiming on the statistical side would undermine the positioning. Simple descriptive
summary + one plot is enough to prove the mart works and the data flows end to end.

## Shiny reference app

**Path:** `/home/mdonovan/Projects/R/RestaurantAnalyticsDashboard/`
**Uses:** `lhrc_data` + OpenTable databases, DuckDB cache layer

**Advanced patterns to reuse in the epi dashboard:**

- `future` + `promises` (async background load) — loads initial date window synchronously on startup,
  then loads full dataset in background via `future_promise()`. UI stays responsive immediately.
  Pattern: `INIT_DATA` loads fast on startup; full year loads async and replaces when ready.
- `reactable` + `reactablefmtr` — interactive tables with custom theming, row expansion, sorting
- Skeleton shimmer loading state (`sk_reactable()` wrapper) — shows placeholder grid while data loads
- `fresh` package for custom shinydashboard theming (slate dark theme with full color token system)
- `uiOutput("loading_banner")` — conditional banner shown across all tabs during async load
- Three-tab shinydashboard structure (Server / Guest / Sales Metrics) — clean model for
  the epi dashboard (County Overview / Exposure Analysis / Data Quality)

**Why this is the right complexity level:**
Advanced enough to show real Shiny engineering (async, custom theming, skeleton states),
simple enough to be readable and portable. Not using modules — keeps it approachable.
The epi Shiny app should follow this pattern, not exceed it.

## Status

Not started. Notes only.

## When resuming

1. Download CDC PLACES county CSV (bulk) — check column names, confirm FIPS format
2. Download one year of EPA PM2.5 annual summary (pre-generated files at AirData link above)
3. Set up new PostgreSQL database (raw schema) — can use existing RDS instance
4. Build dbt project: stg_places_county, stg_epa_pm25, int_places_epa_join, mart_epi_analysis
5. Write Quarto report: exposure-outcome framing, one regression, one plot
6. Publish Quarto output (quarto publish) and add to portfolio
7. Update profile.json evidence[] and llms.txt

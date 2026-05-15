# TODO — Epi Pipeline

Check off items as completed. Resume from wherever this list is when returning.

## Setup
- [ ] CREATE DATABASE epi_pipeline on lhrc-db RDS server
- [ ] Create `inventory` user access to epi_pipeline database (or use existing creds)
- [ ] Add DB_PASSWORD_EPI to ~/.Renviron
- [ ] Set up S3 bucket for prod raw data (fill in config.yml bucket name)
- [ ] Confirm `dbt` CLI is installed (`dbt --version`)
- [ ] Confirm `config` R package is installed

## Data
- [ ] Download CDC PLACES county CSV from https://data.cdc.gov/500-Cities-Places/PLACES-Local-Data-for-Better-Health-County-Data-20/swc5-untb
- [ ] Download EPA PM2.5 annual summary CSV from https://www.epa.gov/outdoor-air-quality-data/download-daily-data
- [x] Drop both files in data/raw/ and inspect column names
- [ ] Update column names in ingestion/load_places.R — actual cols are lowercase_snake: stateabbr, statedesc, locationname, locationid, year, datasource, category, measure, measureid, data_value, low_confidence_limit, high_confidence_limit, data_value_type, populationcount
- [ ] Update column names in ingestion/load_epa_pm25.R — actual cols have spaces: "State Code", "County Code", "Site Num", "Parameter Code", "POC" etc. — clean_names() will convert to state_code, county_code, site_num, parameter_code
- [ ] Add filter in load_epa_pm25.R: filter(parameter_code == 88101) to isolate PM2.5 FRM/FEM
- [ ] Verify FIPS format (leading zeros) in both files — update pad logic if needed
- [ ] Confirm year column in EPA file (may need to extract from filename)

## dbt Seeds
- [ ] Populate dbt/seeds/fips_reference.csv (use tigris::fips_codes in R)
- [ ] Run initial ingestion, then: SELECT DISTINCT measure_id, measure, category FROM raw.places_county
- [ ] Populate dbt/seeds/places_measures.csv with results

## dbt Models
- [ ] Confirm measure_ids in stg_places_county match actual data (OBESITY, DIABETES, etc.)
- [ ] Add year column to stg_epa_pm25 once EPA file year field confirmed
- [ ] Add year to join key in int_places_epa_join
- [ ] Fill in pivot measure_ids in mart_epi_analysis with confirmed values
- [ ] Add schema.yml files for each model (column descriptions, tests)
- [ ] Run dbt run and fix any errors
- [ ] Run dbt test — fix FIPS format issues if assert_fips_format fails
- [ ] Generate dbt docs (dbt docs generate && dbt docs serve)

## Quarto Report
- [ ] Fill in summary gt table (overview section)
- [ ] Build prevalence table (median + IQR per measure)
- [ ] Build PM2.5 distribution plot
- [ ] Build scatter plot (PM2.5 vs. primary outcome)
- [ ] Build county summary DT/gt table
- [ ] Test render: quarto render quarto/epi_report.qmd
- [ ] Publish: quarto publish quarto/epi_report.qmd

## Shiny Dashboard
- [ ] Implement load_mart_data() in shiny/functions.R
- [ ] Implement max_available_year() 
- [ ] Build filter controls (state, year, measure) in sidebar
- [ ] Implement filtered_data() reactive with filter logic
- [ ] Build county reactable table (Overview tab)
- [ ] Add value boxes (national medians)
- [ ] Build scatter plot (Exposure Analysis tab)
- [ ] Build PM2.5 histogram
- [ ] Build data quality plots (Data Quality tab)
- [ ] Apply fresh theme
- [ ] Test locally: shiny::runApp("shiny/")
- [ ] Deploy to shinyapps.io

## Pipeline Orchestration
- [ ] Test run_pipeline.R end-to-end locally
- [ ] Set up cron/poll_and_run.sh for prod EC2
- [ ] Implement S3 read in ingestion/utils.R read_raw_file()
- [ ] Implement already_loaded() idempotency check in ingestion/utils.R

## Portfolio Integration
- [ ] Add project to profile.json evidence[]
- [ ] Add dbt gist(s) to llms.txt and GistsDbt.jsx
- [ ] Add Shiny live URL to portfolio once deployed
- [ ] Add Quarto report link to portfolio

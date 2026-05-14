-- Mart: wide analysis table — one row per county × year
-- Pivots key PLACES measures from long to wide
-- This is the table Quarto and Shiny both read from
-- Grain: county × year

with base as (
    select * from {{ ref('int_places_epa_join') }}
),

-- Pivot selected PLACES measures to wide format
-- TODO: confirm exact measure_ids from actual data (run SELECT DISTINCT measure_id FROM stg_places_county)
-- Common measure_ids: OBESITY, DIABETES, CSMOKING, BPHIGH, COPD, CHD, STROKE, CASTHMA, DEPRESSION
pivoted as (
    select
        county_fips,
        state_abbr,
        state_name,
        county_name,
        year,
        population_count,
        pm25_annual_mean,
        pm25_station_count,
        missing_pm25,

        -- TODO: fill in actual measure_ids after inspecting the data
        max(case when measure_id = 'OBESITY'   then data_value end) as obesity_pct,
        max(case when measure_id = 'DIABETES'  then data_value end) as diabetes_pct,
        max(case when measure_id = 'CSMOKING'  then data_value end) as smoking_pct,
        max(case when measure_id = 'BPHIGH'    then data_value end) as hypertension_pct,
        max(case when measure_id = 'COPD'      then data_value end) as copd_pct,
        max(case when measure_id = 'CHD'       then data_value end) as heart_disease_pct,
        max(case when measure_id = 'CASTHMA'   then data_value end) as asthma_pct,
        max(case when measure_id = 'DEPRESSION' then data_value end) as depression_pct,

        -- Confidence intervals for primary outcome (obesity as example)
        -- TODO: add CI columns for key measures if needed in Quarto report
        max(case when measure_id = 'OBESITY'   then ci_low end)     as obesity_ci_low,
        max(case when measure_id = 'OBESITY'   then ci_high end)    as obesity_ci_high

    from base
    group by
        county_fips, state_abbr, state_name, county_name,
        year, population_count, pm25_annual_mean, pm25_station_count, missing_pm25
)

select * from pivoted
order by state_abbr, county_name, year

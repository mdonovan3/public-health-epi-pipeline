-- Mart: wide analysis table — one row per county × year
-- Pivots key PLACES measures from long to wide
-- This is the table Quarto and Shiny both read from
-- Grain: county × year
--
-- Base columns from int_places_epa_join:
--
--   From stg_places_county (via p.*):
--     county_fips, year
--     state_abbr, state_name, county_name
--     category, category_id
--     measure, measure_id, short_question_text
--     data_value_type, data_value_type_id
--     data_value, ci_low, ci_high
--     population_count
--     loaded_at
--
--   From stg_epa_pm25 (aggregated to county × year, via e.*):
--     pm25_annual_mean
--     pm25_station_count
--     pm25_avg_coverage
--     missing_pm25  (derived flag: true when no EPA station matched the county-year)

with base as (
    select * from {{ ref('int_places_epa_join') }}
),

pivoted as (
    select

        -- Dimensions
        county_fips,
        state_abbr,
        state_name,
        county_name,
        year,
        max(population_count)       as population_count,
        max(pm25_annual_mean)       as pm25_annual_mean,
        max(pm25_station_count)     as pm25_station_count,
        max(pm25_avg_coverage)      as pm25_avg_coverage,
        bool_or(missing_pm25)       as missing_pm25,

        -- Health outcomes
        max(case when measure_id = 'OBESITY'     then data_value end) as obesity_pct,
        max(case when measure_id = 'DIABETES'    then data_value end) as diabetes_pct,
        max(case when measure_id = 'CHD'         then data_value end) as chd_pct,
        max(case when measure_id = 'STROKE'      then data_value end) as stroke_pct,
        max(case when measure_id = 'COPD'        then data_value end) as copd_pct,
        max(case when measure_id = 'CASTHMA'     then data_value end) as asthma_pct,
        max(case when measure_id = 'CANCER'      then data_value end) as cancer_pct,
        max(case when measure_id = 'DEPRESSION'  then data_value end) as depression_pct,
        max(case when measure_id = 'HIGHCHOL'    then data_value end) as high_cholesterol_pct,
        max(case when measure_id = 'BPHIGH'      then data_value end) as high_bp_pct,

        -- Behavioral risk factors
        max(case when measure_id = 'CSMOKING'    then data_value end) as smoking_pct,
        max(case when measure_id = 'BINGE'       then data_value end) as binge_drinking_pct,
        max(case when measure_id = 'LPA'         then data_value end) as physical_inactivity_pct,
        max(case when measure_id = 'SLEEP'       then data_value end) as short_sleep_pct,

        -- Social determinants
        max(case when measure_id = 'ACCESS2'     then data_value end) as no_insurance_pct,
        max(case when measure_id = 'FOODINSECU'  then data_value end) as food_insecurity_pct,
        max(case when measure_id = 'MHLTH'       then data_value end) as mental_distress_pct,

        -- Confidence intervals for primary exposure-outcome pairs
        max(case when measure_id = 'CASTHMA'     then ci_low  end) as asthma_ci_low,
        max(case when measure_id = 'CASTHMA'     then ci_high end) as asthma_ci_high,
        max(case when measure_id = 'COPD'        then ci_low  end) as copd_ci_low,
        max(case when measure_id = 'COPD'        then ci_high end) as copd_ci_high,
        max(case when measure_id = 'CHD'         then ci_low  end) as chd_ci_low,
        max(case when measure_id = 'CHD'         then ci_high end) as chd_ci_high

    from base
    group by county_fips, state_abbr, state_name, county_name, year
)

select * from pivoted
order by state_abbr, county_name, year

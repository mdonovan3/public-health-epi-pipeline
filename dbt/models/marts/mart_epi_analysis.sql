-- Mart: wide analysis table — one row per county × year
-- Pivots key PLACES measures from long to wide
-- This is the table Quarto and Shiny both read from
-- Grain: county × year

with base as (
    select * from {{ ref('int_places_epa_join') }}
),

pivoted as (
    select

        -- [PART 9 · STEP 9.1] Dimension columns
        -- county_fips, state_abbr, state_name, county_name, year,
        -- population_count, pm25_annual_mean, pm25_station_count, missing_pm25

        -- [PART 9 · STEP 9.2] Health outcomes — pivot long to wide
        -- Pattern: max(case when measure_id = 'OBESITY' then data_value end) as obesity_pct
        -- Measures: OBESITY, DIABETES, CHD, STROKE, COPD,
        --           CASTHMA, CANCER, DEPRESSION, HIGHCHOL, BPHIGH

        -- [PART 9 · STEP 9.3] Behavioral risk factors
        -- CSMOKING → smoking_pct
        -- BINGE    → binge_drinking_pct
        -- LPA      → physical_inactivity_pct
        -- SLEEP    → short_sleep_pct

        -- [PART 9 · STEP 9.4] Social determinants
        -- ACCESS2    → no_insurance_pct
        -- FOODINSECU → food_insecurity_pct
        -- MHLTH      → mental_distress_pct
        -- (add more from the full 39-measure list as needed)

        -- [PART 9 · STEP 9.5] Confidence intervals and GROUP BY
        -- Add ci_low / ci_high for primary exposure-outcome pair, e.g.:
        --   max(case when measure_id = 'OBESITY'  then ci_low  end) as obesity_ci_low
        --   max(case when measure_id = 'OBESITY'  then ci_high end) as obesity_ci_high
        --   max(case when measure_id = 'CASTHMA'  then ci_low  end) as asthma_ci_low
        --   max(case when measure_id = 'CASTHMA'  then ci_high end) as asthma_ci_high
        --
        -- GROUP BY all non-aggregated columns from STEP 9.1

        null as placeholder  -- remove this line when implementing

    from base
)

select * from pivoted
order by state_abbr, county_name, year

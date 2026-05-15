-- Staging: EPA PM2.5 station-level annual data
-- Source: raw.epa_pm25 (loaded by ingestion/load_epa_pm25.R, pre-filtered to parameter_code 88101)
-- Grain: one row per monitoring station × year

with source as (
    select * from {{ source('raw', 'epa_pm25') }}
),

cleaned as (
    select

        -- [PART 7 · STEP 7.1] Select and cast columns from source
        -- Columns to include:
        --   county_fips
        --   cast(year as integer)
        --   cast(state_code as varchar(2))
        --   cast(county_code as varchar(3))
        --   parameter_name, sample_duration, pollutant_standard, units_of_measure
        --   cast(arithmetic_mean as numeric)   as pm25_mean
        --   cast(observation_count as integer) as obs_count
        --   cast(observation_percent as numeric) as obs_pct
        --   completeness_indicator
        --   cast(latitude as numeric)
        --   cast(longitude as numeric)
        --   loaded_at

        null as placeholder  -- remove this line when implementing

    from source
    where arithmetic_mean is not null
),

-- Standard EPA guidance: exclude stations with < 75% valid observations
sufficient_coverage as (
    select *
    from cleaned
    where obs_pct >= 75
)

select * from sufficient_coverage

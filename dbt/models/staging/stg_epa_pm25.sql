-- Staging: EPA PM2.5 station-level annual data
-- Source: raw.epa_pm25 (loaded by ingestion/load_epa_pm25.R)
-- Grain: one row per monitoring station × year
-- NOTE: county-year aggregation happens in intermediate layer, not here

with source as (
    select * from {{ source('raw', 'epa_pm25') }}
),

renamed as (
    select
        county_fips,                                      -- 5-digit FIPS (built in ingestion)
        state_name,
        county_name,

        -- TODO: confirm year column name from actual EPA file
        -- cast(year as integer) as year,
        cast(arithmetic_mean as numeric) as pm25_mean,   -- annual mean µg/m³
        cast(observation_count as integer) as obs_count,
        cast(observation_percent as numeric) as obs_pct, -- % of valid observations
        units_of_measure,
        latitude,
        longitude,
        loaded_at

    from source

    where arithmetic_mean is not null
),

-- Filter to stations with sufficient data coverage
-- TODO: tune threshold — 75% is standard in EPA guidance
sufficient_coverage as (
    select *
    from renamed
    where obs_pct >= 75
)

select * from sufficient_coverage

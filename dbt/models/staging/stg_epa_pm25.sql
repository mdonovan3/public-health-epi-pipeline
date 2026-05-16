-- Staging: EPA PM2.5 station-level annual data
-- Source: raw.epa_pm25 (loaded by ingestion/load_epa_pm25.R, filtered to 88101/44201/42602)
-- Grain: one row per monitoring station × year

with source as (
    select * from {{ source('raw', 'epa_pm25') }}
),

cleaned as (
    select

        lpad("State Code", 2, '0') || lpad("County Code", 3, '0') as county_fips,
        cast("Year" as integer) as year,
        "State Code" as state_code,
        "County Code" as county_code,
        "Parameter Name" as parameter_name,
        "Parameter Code" as parameter_code,
        "Sample Duration" as sample_duration,
        "Pollutant Standard" as pollutant_standard,
        "Units of Measure" as units_of_measure,
        cast("Arithmetic Mean" as numeric) as arithmetic_mean,
        cast("Observation Count" as integer) as obs_count,
        cast("Observation Percent" as numeric) as obs_pct,
        "Completeness Indicator" as completeness_indicator,
        cast("Latitude" as numeric) as latitude,
        cast("Longitude" as numeric) as longitude,
        loaded_at

    from source
    where "Arithmetic Mean" is not null
),

-- Standard EPA guidance: exclude stations with < 75% valid observations
sufficient_coverage as (
    select *
    from cleaned
    where obs_pct >= 75
)

select * from sufficient_coverage

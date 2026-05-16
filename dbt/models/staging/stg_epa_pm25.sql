-- Staging: EPA PM2.5 station-level annual data
-- Source: raw.epa_pm25 (loaded by ingestion/load_epa_pm25.R, filtered to 88101/44201/42602)
-- Grain: one row per monitoring station × year

with source as (
    select * from {{ source('raw', 'epa_pm25') }}
),

cleaned as (
    select

        -- [PART 7 · STEP 7.1] Select and cast columns from source
        -- Raw column names come from read.csv() dot-notation, lowercased by Postgres.
        -- Alias each to snake_case here — this is where normalization happens.
        --   county_fips
        --   cast("year" as integer)                          as year
        --   cast("state.code" as varchar(2))                 as state_code
        --   cast("county.code" as varchar(3))                as county_code
        --   "parameter.name"                                 as parameter_name
        --   "sample.duration"                                as sample_duration
        --   "pollutant.standard"                             as pollutant_standard
        --   "units.of.measure"                               as units_of_measure
        --   cast("arithmetic.mean" as numeric)               as pm25_mean
        --   cast("observation.count" as integer)             as obs_count
        --   cast("observation.percent" as numeric)           as obs_pct
        --   "completeness.indicator"                         as completeness_indicator
        --   cast("latitude" as numeric)                      as latitude
        --   cast("longitude" as numeric)                     as longitude
        --   loaded_at

        null as placeholder  -- remove this line when implementing

    from source
    where "arithmetic.mean" is not null
),

-- Standard EPA guidance: exclude stations with < 75% valid observations
sufficient_coverage as (
    select *
    from cleaned
    where obs_pct >= 75
)

select * from sufficient_coverage

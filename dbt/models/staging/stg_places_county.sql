-- Staging: CDC PLACES county data
-- Source: raw.places_county (loaded by ingestion/load_places.R)
-- Grain: one row per county × year × measure
-- Outputs clean, renamed, typed columns ready for pivoting downstream

with source as (
    select * from {{ source('raw', 'places_county') }}
),

renamed as (
    select
        -- Geography
        location_id         as county_fips,      -- 5-digit FIPS code
        state_abbr,
        state_desc          as state_name,
        location_name       as county_name,

        -- Time
        cast(year as integer) as year,

        -- Measure
        measure_id,
        measure,
        category,
        short_question_text,
        data_value_type,

        -- Values
        cast(data_value as numeric)              as data_value,
        cast(low_confidence_limit as numeric)    as ci_low,
        cast(high_confidence_limit as numeric)   as ci_high,
        cast(population_count as integer)        as population_count,

        -- Metadata
        loaded_at

    from source

    -- TODO: add any additional filters here (e.g., specific data_value_type)
    -- Most analysis should use 'Age-adjusted prevalence' or 'Crude prevalence'
    -- where data_value_type = 'Age-adjusted prevalence'
),

validated as (
    select *
    from renamed
    where
        county_fips is not null
        and year is not null
        and measure_id is not null
        and data_value is not null
        -- TODO: add FIPS format check
        -- and length(county_fips) = 5
)

select * from validated

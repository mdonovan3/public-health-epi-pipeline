-- Staging: CDC PLACES county data
-- Source: raw.places_county (loaded by ingestion/load_places.R)
-- Grain: one row per county × year × measure × data_value_type

with source as (
    select * from {{ source('raw', 'places_county') }}
),

cleaned as (
    select

        lpad(cast(locationid as varchar), 5, '0') as county_fips,
        cast(year as integer) as year,
        stateabbr as state_abbr,
        statedesc as state_name,
        locationname as county_name,
        category,
        categoryid as category_id,
        measure,
        measureid as measure_id,
        short_question_text,
        data_value_type,
        datavaluetypeid as data_value_type_id,
        cast(data_value as numeric) as data_value,
        cast(low_confidence_limit as numeric) as ci_low,
        cast(high_confidence_limit as numeric) as ci_high,
        cast(totalpopulation as integer) as population_count,
        loaded_at

    from source
    where data_value is not null
),

-- Keep age-adjusted prevalence only for comparability across counties
-- Crude prevalence also available — change filter if needed
age_adjusted as (
    select *
    from cleaned
    where data_value_type_id = 'AgeAdjPrv'
    -- use 'CrdPrv' for crude prevalence instead
)

select * from age_adjusted

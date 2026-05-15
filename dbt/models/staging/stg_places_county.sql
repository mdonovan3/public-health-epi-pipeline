-- Staging: CDC PLACES county data
-- Source: raw.places_county (loaded by ingestion/load_places.R)
-- Grain: one row per county × year × measure × data_value_type

with source as (
    select * from {{ source('raw', 'places_county') }}
),

cleaned as (
    select

        -- [PART 6 · STEP 6.1] Select and cast columns from source
        -- Columns to include:
        --   county_fips, state_abbr, state_name, county_name
        --   cast(year as integer)
        --   category, category_id, measure, measure_id, short_question_text
        --   data_value_type, data_value_type_id
        --   cast(data_value as numeric)
        --   cast(ci_low as numeric)        -- source col: low_confidence_limit
        --   cast(ci_high as numeric)       -- source col: high_confidence_limit
        --   cast(population_count as integer)
        --   loaded_at

        null as placeholder  -- remove this line when implementing

    from source
    where data_value is not null
),

-- Keep age-adjusted prevalence only for comparability across counties
-- Crude prevalence also available — change filter if needed
age_adjusted as (
    select *
    from cleaned
    where data_value_type_id = 'AgeAdjPrv'
    -- Use 'CrdPrv' for crude prevalence instead
)

select * from age_adjusted

-- Intermediate: join CDC PLACES outcomes with EPA PM2.5 exposure
-- Aggregates station-level PM2.5 to county-year mean, then joins to PLACES
-- Grain: one row per county × year (all measures still long)

with places as (
    select * from {{ ref('stg_places_county') }}
),

-- Aggregate EPA stations to county-year mean PM2.5
pm25_county_year as (
    select
        county_fips,
        -- TODO: confirm year column
        -- year,
        avg(pm25_mean)      as pm25_annual_mean,
        count(*)            as station_count,    -- how many stations contributed
        avg(obs_pct)        as avg_obs_pct
    from {{ ref('stg_epa_pm25') }}
    group by
        county_fips
        -- , year
),

joined as (
    select
        p.*,
        e.pm25_annual_mean,
        e.station_count     as pm25_station_count,
        e.avg_obs_pct       as pm25_avg_coverage,

        -- Flag counties with no PM2.5 data
        case when e.county_fips is null then true else false end as missing_pm25

    from places p
    left join pm25_county_year e
        on p.county_fips = e.county_fips
        -- TODO: add year join once year column confirmed in EPA data
        -- and p.year = e.year
)

select * from joined

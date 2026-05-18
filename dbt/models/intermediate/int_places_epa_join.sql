-- Intermediate: join CDC PLACES outcomes with EPA PM2.5 exposure
-- Aggregates station-level PM2.5 to county-year mean, then joins to PLACES
-- Grain: one row per county × year × measure (still long)

with places as (
    select * from {{ ref('stg_places_county') }}
),

pm25_county_year as (
    select

        -- [PART 8 · STEP 8.1] Aggregate PM2.5 stations to county-year
        -- Group by: county_fips, year
        county_fips, year, 
        avg(pm25_mean)  as pm25_annual_mean,
        count(*)        as station_count,
        avg(obs_pct)    as avg_obs_pct
	
    from {{ ref('stg_epa_pm25') }}
    group by county_fips, year
),

joined as (
    select

        -- [PART 8 · STEP 8.2] Left join PLACES to PM2.5
         p.*,
         e.pm25_annual_mean,
         e.station_count as pm25_station_count,
         e.avg_obs_pct as pm25_avg_coverage,
         case when e.county_fips is null then true else false end as missing_pm25
    from places p
    left join pm25_county_year e
    on  p.county_fips = e.county_fips
    and p.year = e.year
)

select * from joined

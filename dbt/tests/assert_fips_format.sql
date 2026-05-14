-- Test: all county_fips values should be 5 characters (zero-padded)
-- Fails if any FIPS code is wrong length — usually means leading zero was dropped

select county_fips
from {{ ref('stg_places_county') }}
where length(county_fips) != 5

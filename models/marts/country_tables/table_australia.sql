-- models/marts/country_tables/table_australia.sql
-- ----------------------------------------------------------------------------
-- DELIVERABLE 3: PER-COUNTRY TARGET TABLE (AUSTRALIA)
-- PURPOSE:
--   Curated Gold mart for members whose latest registered country is Australia.
--   Enforces the "latest record wins" rule: members who relocated from Australia
--   to another country will not appear here; members who relocated to Australia
--   will appear here.
-- SOURCE:
--   STAGING.STG_MEMBERS (deduplicated on MEMBER_ID, keeping latest activity)
-- ----------------------------------------------------------------------------

WITH silver_members AS (

    SELECT * FROM {{ ref('stg_members') }}

)

SELECT
    MEMBER_ID,
    MEMBER_NAME,
    ENROLLMENT_DATE,
    LAST_FLIGHT_DATE,
    DOB,
    TIER_CODE,
    COUNTRY,
    IS_ACTIVE,
    AGENT_NAME,
    STATE,
    POST_CODE,
    AGE,
    STALE_MEMBER,
    INGESTION_TIMESTAMP,
    SOURCE_FILE_NAME,
    SOURCE_FILE_ROW_NUMBER,
    CURRENT_TIMESTAMP()                                                         AS MART_LOADED_AT
FROM silver_members
WHERE COUNTRY = 'AUS'

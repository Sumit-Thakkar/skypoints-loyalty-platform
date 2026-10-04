-- models/marts/fct_member_redemptions.sql
-- ----------------------------------------------------------------------------
-- DELIVERABLE 4: JOIN FLATTENED REDEMPTIONS TO MEMBER PROFILE
-- PURPOSE:
--   Curated Gold analytical fact mart combining partner redemption transactions
--   with active member demographics, behavioral tenure, and loyalty status.
--
-- BUSINESS VALUE:
--   Enables multidimensional analytics across:
--     - Partner Type: Internal (SkyPoints) vs. Alliance Partners (AeroLink, etc.)
--     - Member Lifecycle: Tenure at redemption, days since last flight, staleness
--     - Demographics: Member age brackets and friendly tier names
--
-- GRAIN:
--   One row per redemption transaction (TXN_ID).
-- ----------------------------------------------------------------------------

WITH redemptions AS (

    SELECT * FROM {{ ref('stg_redemptions') }}

),

members AS (

    SELECT * FROM {{ ref('stg_members') }}

),

joined AS (

    SELECT
        -- Transaction attributes (Fact)
        r.TXN_ID,
        r.MEMBER_ID,
        r.FEED_DATE,
        r.TXN_DATE,
        r.PARTNER,
        CASE 
            WHEN UPPER(TRIM(r.PARTNER)) = 'SKYPOINTS' THEN 'INTERNAL'
            ELSE 'ALLIANCE_PARTNER'
        END                                                                     AS PARTNER_TYPE,
        r.MILES_REDEEMED,
        r.STATUS                                                                AS REDEMPTION_STATUS,

        -- Member profile attributes (Dimension / Context)
        m.MEMBER_NAME,
        m.TIER_CODE                                                             AS MEMBER_TIER_CODE,
        CASE m.TIER_CODE
            WHEN 'GLD' THEN 'Gold'
            WHEN 'PLT' THEN 'Platinum'
            WHEN 'SLV' THEN 'Silver'
            WHEN 'BRZ' THEN 'Bronze'
            ELSE 'Unknown'
        END                                                                     AS MEMBER_TIER_NAME,
        m.COUNTRY                                                               AS MEMBER_COUNTRY,
        m.STATE                                                                 AS MEMBER_STATE,
        m.IS_ACTIVE                                                             AS MEMBER_IS_ACTIVE,
        m.AGE                                                                   AS MEMBER_AGE,
        CASE 
            WHEN m.AGE < 25 THEN 'Under 25'
            WHEN m.AGE BETWEEN 25 AND 39 THEN '25-39'
            WHEN m.AGE BETWEEN 40 AND 59 THEN '40-59'
            ELSE '60+'
        END                                                                     AS MEMBER_AGE_GROUP,
        m.ENROLLMENT_DATE                                                       AS MEMBER_ENROLLMENT_DATE,
        m.LAST_FLIGHT_DATE                                                      AS MEMBER_LAST_FLIGHT_DATE,

        -- Behavioral & Recency Metrics at Transaction Time
        DATEDIFF('day', m.ENROLLMENT_DATE, r.TXN_DATE)                          AS MEMBER_TENURE_DAYS_AT_TXN,
        DATEDIFF('day', m.LAST_FLIGHT_DATE, r.TXN_DATE)                         AS DAYS_SINCE_LAST_FLIGHT_AT_TXN,
        CASE 
            WHEN m.LAST_FLIGHT_DATE IS NULL THEN NULL
            WHEN DATEDIFF('day', m.LAST_FLIGHT_DATE, r.TXN_DATE) > 90 THEN 'Y'
            ELSE 'N'
        END                                                                     AS WAS_STALE_AT_REDEMPTION,

        -- Lineage & Audit
        r.INGESTION_TIMESTAMP                                                   AS REDEMPTION_INGESTION_TIMESTAMP,
        CURRENT_TIMESTAMP()                                                     AS MART_LOADED_AT

    FROM redemptions r
    INNER JOIN members m
        ON r.MEMBER_ID = m.MEMBER_ID

)

SELECT * FROM joined

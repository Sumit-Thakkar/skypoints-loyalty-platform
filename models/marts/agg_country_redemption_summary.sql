-- models/marts/agg_country_redemption_summary.sql
-- ----------------------------------------------------------------------------
-- PURPOSE:
--   Curated Gold aggregate fact mart summarizing mileage redemption metrics
--   by member country, airline partner, partner type, and redemption status.
--
-- BUSINESS VALUE:
--   Optimized for executive reporting and BI dashboard performance on large-scale
--   data. Enables instantaneous queries without full-table scans over millions
--   of raw transactional records.
--
-- GRAIN:
--   One row per MEMBER_COUNTRY + PARTNER + PARTNER_TYPE + REDEMPTION_STATUS.
-- ----------------------------------------------------------------------------

WITH fact_redemptions AS (

    SELECT * FROM {{ ref('fct_member_redemptions') }}

),

aggregated AS (

    SELECT
        MEMBER_COUNTRY,
        PARTNER,
        PARTNER_TYPE,
        REDEMPTION_STATUS,

        -- Aggregated Measures
        COUNT(DISTINCT TXN_ID)                                                  AS TOTAL_TRANSACTIONS,
        COUNT(DISTINCT MEMBER_ID)                                               AS UNIQUE_REDEEMING_MEMBERS,
        SUM(MILES_REDEEMED)                                                     AS TOTAL_MILES_REDEEMED,
        ROUND(AVG(MILES_REDEEMED), 2)                                           AS AVG_MILES_PER_TXN,
        MIN(MILES_REDEEMED)                                                     AS MIN_MILES_REDEEMED,
        MAX(MILES_REDEEMED)                                                     AS MAX_MILES_REDEEMED,

        -- Stale Member Redemptions (Dormant cash-outs)
        COUNT_IF(WAS_STALE_AT_REDEMPTION = 'Y')                                 AS STALE_MEMBER_TXN_COUNT,
        SUM(CASE WHEN WAS_STALE_AT_REDEMPTION = 'Y' THEN MILES_REDEEMED ELSE 0 END) AS STALE_MEMBER_MILES_REDEEMED,

        MIN(TXN_DATE)                                                           AS EARLIEST_TXN_DATE,
        MAX(TXN_DATE)                                                           AS LATEST_TXN_DATE,

        CURRENT_TIMESTAMP()                                                     AS MART_LOADED_AT

    FROM fact_redemptions
    GROUP BY
        MEMBER_COUNTRY,
        PARTNER,
        PARTNER_TYPE,
        REDEMPTION_STATUS

)

SELECT * FROM aggregated

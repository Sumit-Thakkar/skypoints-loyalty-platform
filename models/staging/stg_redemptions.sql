-- models/staging/stg_redemptions.sql
-- -------------------------------------------------------
-- PURPOSE:
--   Silver cleansed redemptions table. Reads from
--   RAW.RAW_REDEMPTION_FEED (Bronze flat table) and applies:
--     1. TYPE CASTING    — TXN_DATE / FEED_DATE → DATE (YYYYMMDD)
--                          MILES_REDEEMED → NUMBER
--     2. STANDARDISATION — UPPER/TRIM on categorical fields
--     3. DQ FILTERING    — rows failing any rule are excluded
--     4. DEDUPLICATION   — one row per TXN_ID (latest DBT_UPDATED_AT wins)
--
-- DQ RULES (record excluded if any fails):
--   R01 — TXN_ID is not null/empty
--   R02 — MEMBER_ID is not null/empty
--   R03 — TXN_DATE is a parseable YYYYMMDD date
--   R04 — MILES_REDEEMED is numeric and > 0
--   R05 — STATUS is a known value
--
-- TARGET DATA TYPES (Silver):
--   TXN_ID          VARCHAR      — transaction identifier
--   MEMBER_ID       VARCHAR      — loyalty member ID (FK to stg_members)
--   FEED_DATE       DATE         — batch feed date (YYYYMMDD)
--   TXN_DATE        DATE         — transaction date (YYYYMMDD)
--   PARTNER         VARCHAR      — partner airline name
--   MILES_REDEEMED  NUMBER       — miles redeemed (cast from VARCHAR)
--   STATUS          VARCHAR      — COMPLETED / PENDING / CANCELLED
-- -------------------------------------------------------

WITH bronze AS (

    SELECT * FROM {{ ref('raw_redemption_feed') }}

),

parsed AS (

    SELECT
        -- Identifiers
        TRIM(TXN_ID)                                                        AS TXN_ID,
        TRIM(MEMBER_ID)                                                     AS MEMBER_ID,

        -- Dates: source format YYYYMMDD
        TRY_TO_DATE(TRIM(FEED_DATE), 'YYYYMMDD')                           AS FEED_DATE,
        TRY_TO_DATE(TRIM(TXN_DATE), 'YYYYMMDD')                            AS TXN_DATE,

        -- Standardised categoricals
        UPPER(TRIM(STATUS))                                                 AS STATUS,
        TRIM(PARTNER)                                                       AS PARTNER,

        -- Type cast: miles_redeemed VARCHAR → NUMBER
        TRY_TO_NUMBER(TRIM(MILES_REDEEMED))                                AS MILES_REDEEMED,

        -- Audit
        INGESTION_TIMESTAMP,
        SOURCE_FILE_NAME,

        -- DQ check helpers (internal)
        TRY_TO_DATE(TRIM(TXN_DATE), 'YYYYMMDD')                            AS _txn_date_check,
        TRY_TO_NUMBER(TRIM(MILES_REDEEMED))                                AS _miles_numeric

    FROM bronze

),

valid_records AS (

    SELECT
        TXN_ID,
        MEMBER_ID,
        FEED_DATE,
        TXN_DATE,
        PARTNER,
        MILES_REDEEMED,
        STATUS,
        INGESTION_TIMESTAMP,
        SOURCE_FILE_NAME

    FROM parsed

    WHERE
        -- R01: TXN_ID must be present
        TXN_ID IS NOT NULL
        AND TXN_ID != ''

        -- R02: MEMBER_ID must be present
        AND MEMBER_ID IS NOT NULL
        AND MEMBER_ID != ''

        -- R03: TXN_DATE must be a parseable YYYYMMDD date
        AND _txn_date_check IS NOT NULL

        -- R04: MILES_REDEEMED must be numeric and positive
        AND _miles_numeric IS NOT NULL
        AND _miles_numeric > 0

        -- R05: STATUS must be a known value
        AND UPPER(TRIM(STATUS)) IN ('COMPLETED', 'PENDING', 'CANCELLED')

        -- Referential integrity: member must exist in clean Silver members
        -- Unmatched / quarantined member transactions are routed to quarantine.orphan_redemptions
        AND MEMBER_ID IN (SELECT MEMBER_ID FROM {{ ref('stg_members') }})

),

deduplicated AS (

    SELECT *
    FROM valid_records

    -- DEDUPLICATION: one row per TXN_ID
    -- If the same TXN_ID arrives in multiple batches (e.g. status update),
    -- keep the most recently ingested version (latest INGESTION_TIMESTAMP).
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY TXN_ID
        ORDER BY INGESTION_TIMESTAMP DESC NULLS LAST
    ) = 1

)

SELECT * FROM deduplicated

-- models/quarantine/orphan_redemptions.sql
-- -------------------------------------------------------
-- PURPOSE:
--   Captures ORPHAN redemption transactions.
--   These are transactions that are syntactically valid,
--   BUT whose MEMBER_ID does not exist in STAGING.STG_MEMBERS
--   (because the member has not enrolled yet, or because the
--   member profile was corrupted and routed to QUARANTINE_MEMBERS).
--
-- LAYER: QUARANTINE (Dead Letter Queue & Exception Management)
--   Writes to the QUARANTINE schema.
--
-- MATERIALISATION: incremental (append-only)
--   Unique key: composite of SOURCE_FILE_NAME + TXN_ID.
--   Allows re-processing/replaying once the member is enrolled
--   or resolved in QUARANTINE_MEMBERS.
-- -------------------------------------------------------

{{ config(
    materialized         = 'incremental',
    unique_key           = ['SOURCE_FILE_NAME', 'TXN_ID'],
    schema               = 'QUARANTINE',
    incremental_strategy = 'merge'
) }}

WITH bronze AS (

    SELECT * FROM {{ ref('raw_redemption_feed') }}

    {% if is_incremental() %}
    -- Process new batches ingested after the latest detected orphan timestamp
    WHERE INGESTION_TIMESTAMP > (
        SELECT COALESCE(MAX(INGESTION_TIMESTAMP), '1970-01-01'::TIMESTAMP_NTZ)
        FROM {{ this }}
    )
    {% endif %}

),

parsed AS (

    SELECT
        TRIM(TXN_ID)                                                        AS TXN_ID,
        TRIM(MEMBER_ID)                                                     AS MEMBER_ID,
        TRY_TO_DATE(TRIM(FEED_DATE), 'YYYYMMDD')                           AS FEED_DATE,
        TRY_TO_DATE(TRIM(TXN_DATE), 'YYYYMMDD')                            AS TXN_DATE,
        TRIM(PARTNER)                                                       AS PARTNER,
        TRY_TO_NUMBER(TRIM(MILES_REDEEMED))                                AS MILES_REDEEMED,
        UPPER(TRIM(STATUS))                                                 AS STATUS,
        INGESTION_TIMESTAMP,
        SOURCE_FILE_NAME,

        -- DQ check helpers
        TRY_TO_DATE(TRIM(TXN_DATE), 'YYYYMMDD')                            AS _txn_date_check,
        TRY_TO_NUMBER(TRIM(MILES_REDEEMED))                                AS _miles_numeric

    FROM bronze

),

valid_syntax_txns AS (

    -- Only consider transactions that are syntactically valid
    -- (malformed transactions go to quarantine_redemptions instead)
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
        TXN_ID IS NOT NULL AND TXN_ID != ''
        AND MEMBER_ID IS NOT NULL AND MEMBER_ID != ''
        AND _txn_date_check IS NOT NULL
        AND _miles_numeric IS NOT NULL AND _miles_numeric > 0
        AND STATUS IN ('COMPLETED', 'PENDING', 'CANCELLED')

),

orphan_records AS (

    SELECT
        r.TXN_ID,
        r.MEMBER_ID,
        r.FEED_DATE,
        r.TXN_DATE,
        r.PARTNER,
        r.MILES_REDEEMED,
        r.STATUS,
        r.INGESTION_TIMESTAMP,
        r.SOURCE_FILE_NAME,

        -- Distinguish why the member is missing:
        -- Did they fail member DQ (quarantined) or were they never received?
        CASE 
            WHEN qm.MEMBER_ID_RAW IS NOT NULL 
            THEN 'MEMBER_EXISTS_BUT_CURRENTLY_QUARANTINED'
            ELSE 'MEMBER_NOT_ENROLLED_OR_UNKNOWN'
        END                                                                 AS ORPHAN_REASON,

        CURRENT_TIMESTAMP()                                                 AS DETECTED_AT

    FROM valid_syntax_txns r
    LEFT JOIN {{ ref('stg_members') }} m 
        ON r.MEMBER_ID = m.MEMBER_ID
    LEFT JOIN {{ ref('quarantine_members') }} qm
        ON r.MEMBER_ID = qm.MEMBER_ID_RAW

    -- Only transactions whose member is NOT in clean stg_members
    WHERE m.MEMBER_ID IS NULL

)

SELECT * FROM orphan_records

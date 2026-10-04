-- models/quarantine/quarantine_redemptions.sql
-- -------------------------------------------------------
-- PURPOSE:
--   Dead Letter Queue (DLQ) / Quarantine table for redemptions.
--   Captures all Bronze records from RAW.RAW_REDEMPTION_FEED
--   that fail ANY DQ rule, preserving raw values and logging
--   the reason(s) for failure.
--
-- LAYER: LOGS (Observability & Governance)
--   Writes to the LOGS schema (isolated from STAGING/MARTS).
--
-- MATERIALISATION: incremental (append-only)
--   Captures failing records across ingestion runs for audit
--   and investigation.
--
-- DQ RULES CHECKED:
--   R01 — TXN_ID is null or empty
--   R02 — MEMBER_ID is null or empty
--   R03 — TXN_DATE is not a parseable YYYYMMDD date
--   R04 — MILES_REDEEMED is null, non-numeric, or <= 0
--   R05 — STATUS is not in ('COMPLETED', 'PENDING', 'CANCELLED')
-- -------------------------------------------------------

{{ config(
    materialized         = 'incremental',
    unique_key           = 'QUARANTINE_RECORD_ID',
    schema               = 'LOGS',
    incremental_strategy = 'merge'
) }}

WITH bronze AS (

    SELECT * FROM {{ ref('raw_redemption_feed') }}

    {% if is_incremental() %}
    -- In incremental runs, process records from batches ingested after the latest quarantined timestamp
    WHERE INGESTION_TIMESTAMP > (
        SELECT COALESCE(MAX(INGESTION_TIMESTAMP), '1970-01-01'::TIMESTAMP_NTZ)
        FROM {{ this }}
    )
    {% endif %}

),

dq_check AS (

    SELECT
        -- Raw strings preserved as-is
        TXN_ID                                                              AS TXN_ID_RAW,
        MEMBER_ID                                                           AS MEMBER_ID_RAW,
        FEED_DATE                                                           AS FEED_DATE_RAW,
        TXN_DATE                                                            AS TXN_DATE_RAW,
        PARTNER,
        MILES_REDEEMED                                                      AS MILES_REDEEMED_RAW,
        STATUS                                                              AS STATUS_RAW,

        -- Audit / Lineage Metadata
        INGESTION_TIMESTAMP,
        SOURCE_FILE_NAME,

        -- Pre-compute parse checks
        TRY_TO_DATE(TRIM(TXN_DATE), 'YYYYMMDD')                            AS _txn_date_check,
        TRY_TO_NUMBER(TRIM(MILES_REDEEMED))                                AS _miles_numeric,

        -- ── Individual rule failure flags ─────────────────────────────────

        -- R01: TXN_ID null or empty
        CASE WHEN TRIM(TXN_ID) IS NULL OR TRIM(TXN_ID) = ''
             THEN 'R01:TXN_ID_NULL_OR_EMPTY'                    END         AS _r01,

        -- R02: MEMBER_ID null or empty
        CASE WHEN TRIM(MEMBER_ID) IS NULL OR TRIM(MEMBER_ID) = ''
             THEN 'R02:MEMBER_ID_NULL_OR_EMPTY'                  END         AS _r02,

        -- R03: TXN_DATE unparseable
        CASE WHEN TRY_TO_DATE(TRIM(TXN_DATE), 'YYYYMMDD') IS NULL
             THEN 'R03:TXN_DATE_UNPARSEABLE'                    END         AS _r03,

        -- R04: MILES_REDEEMED invalid or non-positive
        CASE WHEN TRY_TO_NUMBER(TRIM(MILES_REDEEMED)) IS NULL
               OR TRY_TO_NUMBER(TRIM(MILES_REDEEMED)) <= 0
             THEN 'R04:MILES_REDEEMED_INVALID_OR_NON_POSITIVE'  END         AS _r04,

        -- R05: STATUS not in expected domain
        CASE WHEN UPPER(TRIM(STATUS)) NOT IN ('COMPLETED', 'PENDING', 'CANCELLED')
             THEN 'R05:INVALID_STATUS'                          END         AS _r05

    FROM bronze

),

failed_records AS (

    SELECT
        MD5(CONCAT_WS('|', COALESCE(TXN_ID_RAW, ''), COALESCE(MEMBER_ID_RAW, ''), COALESCE(TXN_DATE_RAW, ''), SOURCE_FILE_NAME, INGESTION_TIMESTAMP::VARCHAR)) AS QUARANTINE_RECORD_ID,
        TXN_ID_RAW,
        MEMBER_ID_RAW,
        FEED_DATE_RAW,
        TXN_DATE_RAW,
        PARTNER,
        MILES_REDEEMED_RAW,
        STATUS_RAW,
        INGESTION_TIMESTAMP,
        SOURCE_FILE_NAME,

        -- Concatenate all triggered rule codes into one reason string
        RTRIM(
            COALESCE(_r01 || ' | ', '')
            || COALESCE(_r02 || ' | ', '')
            || COALESCE(_r03 || ' | ', '')
            || COALESCE(_r04 || ' | ', '')
            || COALESCE(_r05 || ' | ', ''),
            ' | '
        )                                                                   AS QUARANTINE_REASON,

        CURRENT_TIMESTAMP()                                                 AS QUARANTINED_AT

    FROM dq_check

    -- Only rows with at least one DQ failure
    WHERE
        _r01 IS NOT NULL
        OR _r02 IS NOT NULL
        OR _r03 IS NOT NULL
        OR _r04 IS NOT NULL
        OR _r05 IS NOT NULL

)

SELECT * FROM failed_records

-- models/quarantine/quarantine_members.sql
-- -------------------------------------------------------
-- PURPOSE:
--   Dead Letter Queue (DLQ) / Quarantine table for members.
--   Captures all Bronze records from RAW.RAW_MEMBER_FEED
--   that fail ANY DQ rule, logging the reason(s) for failure
--   and preserving the exact line number from the source file.
--
-- LAYER: LOGS (Observability & Governance)
--   Writes to the LOGS schema (isolated from STAGING/MARTS).
--
-- MATERIALISATION: incremental (append-only)
--   Captures failing records across ingestion runs for audit
--   and investigation. Unique key: composite of
--   SOURCE_FILE_NAME + SOURCE_FILE_ROW_NUMBER.
--
-- DQ RULES CHECKED:
--   R01 — MEMBER_ID is not null/empty
--   R02 — MEMBER_NAME is not null/empty
--   R03 — ENROLLMENT_DATE is parseable YYYYMMDD date
--   R04 — COUNTRY is one of 5 known values
--   R05 — TIER_CODE is one of the known tier values (GLD/SLV/PLT/BRZ)
--   R06 — DOB is parseable MMDDYYYY date and not in the future
--   R07 — IS_ACTIVE is 'A' or 'I'
--   R08 — POST_CODE is NULL or castable to integer
-- -------------------------------------------------------

{{ config(
    materialized         = 'incremental',
    unique_key           = ['SOURCE_FILE_NAME', 'SOURCE_FILE_ROW_NUMBER'],
    schema               = 'QUARANTINE',
    incremental_strategy = 'merge'
) }}

WITH bronze AS (

    SELECT * FROM {{ source('raw', 'raw_member_feed') }}

    {% if is_incremental() %}
    -- Only process records from batches ingested after the latest quarantined timestamp
    WHERE INGESTION_TIMESTAMP > (
        SELECT COALESCE(MAX(INGESTION_TIMESTAMP), '1970-01-01'::TIMESTAMP_NTZ)
        FROM {{ this }}
    )
    {% endif %}

),

dq_check AS (

    SELECT
        -- Raw strings preserved as-is
        MEMBER_ID                                                               AS MEMBER_ID_RAW,
        MEMBER_NAME,
        ENROLLMENT_DATE                                                         AS ENROLLMENT_DATE_RAW,
        LAST_FLIGHT_DATE                                                        AS LAST_FLIGHT_DATE_RAW,
        DOB                                                                     AS DOB_RAW,
        TIER_CODE,
        COUNTRY,
        IS_ACTIVE,
        AGENT_NAME,
        STATE,
        POST_CODE                                                               AS POST_CODE_RAW,

        -- Audit / Lineage Metadata
        INGESTION_TIMESTAMP,
        SOURCE_FILE_NAME,
        SOURCE_FILE_ROW_NUMBER,

        -- Pre-compute parse checks
        TRY_TO_DATE(TRIM(ENROLLMENT_DATE), 'YYYYMMDD')                         AS _enrollment_date_check,
        TRY_TO_DATE(LPAD(TRIM(DOB), 8, '0'), 'MMDDYYYY')                       AS _dob_check,

        -- ── Individual rule failure flags ─────────────────────────────────

        -- R01: MEMBER_ID null or empty
        CASE WHEN TRIM(MEMBER_ID) IS NULL OR TRIM(MEMBER_ID) = ''
             THEN 'R01:MEMBER_ID_NULL_OR_EMPTY'                 END             AS _r01,

        -- R02: MEMBER_NAME null or empty
        CASE WHEN TRIM(MEMBER_NAME) IS NULL OR TRIM(MEMBER_NAME) = ''
             THEN 'R02:MEMBER_NAME_NULL_OR_EMPTY'               END             AS _r02,

        -- R03: ENROLLMENT_DATE not parseable as YYYYMMDD (mandatory)
        CASE WHEN TRY_TO_DATE(TRIM(ENROLLMENT_DATE), 'YYYYMMDD') IS NULL
             THEN 'R03:ENROLLMENT_DATE_UNPARSEABLE'             END             AS _r03,

        -- R04: COUNTRY not in allowed set
        CASE WHEN UPPER(TRIM(COUNTRY)) NOT IN ('USA','IND','CAN','AU','PHIL')
             THEN 'R04:INVALID_COUNTRY'                         END             AS _r04,

        -- R05: TIER_CODE not in allowed set (abbreviated source codes)
        CASE WHEN UPPER(TRIM(TIER_CODE)) NOT IN ('GLD','SLV','PLT','BRZ')
             THEN 'R05:INVALID_TIER_CODE'                       END             AS _r05,

        -- R06: DOB not parseable as MMDDYYYY or is a future date
        CASE WHEN TRY_TO_DATE(LPAD(TRIM(DOB), 8, '0'), 'MMDDYYYY') IS NULL
              OR TRY_TO_DATE(LPAD(TRIM(DOB), 8, '0'), 'MMDDYYYY') > CURRENT_DATE()
             THEN 'R06:DOB_INVALID_OR_FUTURE'                   END             AS _r06,

        -- R07: IS_ACTIVE not a known flag
        CASE WHEN UPPER(TRIM(IS_ACTIVE)) NOT IN ('A','I')
             THEN 'R07:INVALID_IS_ACTIVE_FLAG'                  END             AS _r07,

        -- R08: POST_CODE is present but cannot be cast to integer
        CASE WHEN TRIM(POST_CODE::VARCHAR) IS NOT NULL
              AND TRIM(POST_CODE::VARCHAR) != ''
              AND TRY_TO_NUMBER(TRIM(POST_CODE::VARCHAR)) IS NULL
             THEN 'R08:POST_CODE_NON_NUMERIC'                   END             AS _r08

    FROM bronze

),

failed_records AS (

    SELECT
        MEMBER_ID_RAW,
        MEMBER_NAME,
        ENROLLMENT_DATE_RAW,
        LAST_FLIGHT_DATE_RAW,
        DOB_RAW,
        TIER_CODE,
        COUNTRY,
        IS_ACTIVE,
        AGENT_NAME,
        STATE,
        POST_CODE_RAW,
        INGESTION_TIMESTAMP,
        SOURCE_FILE_NAME,
        SOURCE_FILE_ROW_NUMBER,

        -- Concatenate all triggered rule codes into one reason string
        RTRIM(
            COALESCE(_r01 || ' | ', '')
            || COALESCE(_r02 || ' | ', '')
            || COALESCE(_r03 || ' | ', '')
            || COALESCE(_r04 || ' | ', '')
            || COALESCE(_r05 || ' | ', '')
            || COALESCE(_r06 || ' | ', '')
            || COALESCE(_r07 || ' | ', '')
            || COALESCE(_r08 || ' | ', ''),
            ' | '
        )                                                                       AS QUARANTINE_REASON,

        CURRENT_TIMESTAMP()                                                     AS QUARANTINED_AT

    FROM dq_check

    -- Only rows with at least one DQ failure
    WHERE
        _r01 IS NOT NULL
        OR _r02 IS NOT NULL
        OR _r03 IS NOT NULL
        OR _r04 IS NOT NULL
        OR _r05 IS NOT NULL
        OR _r06 IS NOT NULL
        OR _r07 IS NOT NULL
        OR _r08 IS NOT NULL

)

SELECT * FROM failed_records

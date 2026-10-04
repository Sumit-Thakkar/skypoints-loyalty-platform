-- models/staging/stg_members.sql
-- -------------------------------------------------------
-- PURPOSE:
--   Silver cleansed member table. Reads from Bronze
--   RAW.RAW_MEMBER_FEED and applies:
--     1. TYPE CASTING   — parse VARCHAR dates to DATE,
--                         POST_CODE VARCHAR → NUMBER (INT)
--     2. STANDARDISATION— UPPER/TRIM on categorical fields
--     3. DEDUPLICATION  — Latest record per MEMBER_ID
--                         (QUALIFY ROW_NUMBER = 1 ordered
--                          by LAST_FLIGHT_DATE DESC, then
--                          INGESTION_TIMESTAMP DESC as tie-breaker)
--     4. DERIVED COLUMNS— Age (from DOB), Stale_Member flag
--     5. VALID RECORDS  — Rows that pass all DQ rules land
--                         here. Failing rows → stg_quarantine_members
--
-- TARGET DATA TYPES (per DE Assessment column spec):
--   MEMBER_ID        VARCHAR(18)   — stays string (source spec)
--   MEMBER_NAME      VARCHAR(255)
--   ENROLLMENT_DATE  DATE          — source format YYYYMMDD
--   LAST_FLIGHT_DATE DATE          — source format YYYYMMDD
--   TIER_CODE        VARCHAR(5)    — source values: GLD/SLV/PLT/BRZ
--   AGENT_NAME       VARCHAR(255)
--   STATE            VARCHAR(5)
--   COUNTRY          VARCHAR(5)    — USA/IND/CAN/AU/PHIL
--   POST_CODE        NUMBER        — INT in spec; cast from VARCHAR in Silver
--   DOB              DATE          — source format MMDDYYYY (leading zero fix)
--   IS_ACTIVE        VARCHAR(1)    — A / I
--
-- DQ RULES (must ALL pass to be a clean record):
--   R01 — MEMBER_ID is not null/empty
--   R02 — MEMBER_NAME is not null/empty
--   R03 — ENROLLMENT_DATE is a parseable YYYYMMDD date (mandatory)
--   R04 — COUNTRY is one of the 5 known values
--   R05 — TIER_CODE is one of the known tier values
--   R06 — DOB is a parseable MMDDYYYY date and not in the future
--   R07 — IS_ACTIVE is 'A' or 'I'
--   R08 — POST_CODE is NULL or castable to integer
-- -------------------------------------------------------

WITH bronze AS (

    SELECT * FROM {{ source('raw', 'raw_member_feed') }}

),

parsed AS (

    SELECT
        -- Identifiers (VARCHAR per spec — NOT cast to NUMBER)
        TRIM(MEMBER_ID)                                                         AS MEMBER_ID,
        TRIM(MEMBER_NAME)                                                       AS MEMBER_NAME,

        -- Parsed dates
        -- ENROLLMENT_DATE & LAST_FLIGHT_DATE: source format YYYYMMDD (e.g. 20101012)
        TRY_TO_DATE(TRIM(ENROLLMENT_DATE), 'YYYYMMDD')                         AS ENROLLMENT_DATE,
        TRY_TO_DATE(TRIM(LAST_FLIGHT_DATE), 'YYYYMMDD')                        AS LAST_FLIGHT_DATE,
        -- DOB: source format MMDDYYYY with possible missing leading zero (e.g. 3051985 → 03051985)
        TRY_TO_DATE(LPAD(TRIM(DOB), 8, '0'), 'MMDDYYYY')                       AS DOB,

        -- POST_CODE: cast VARCHAR → NUMBER in Silver (INT per spec)
        -- TRY_TO_NUMBER returns NULL if non-numeric; R08 catches this
        TRY_TO_NUMBER(TRIM(POST_CODE::VARCHAR))                                 AS POST_CODE,

        -- Standardised categoricals (UPPER + TRIM)
        UPPER(TRIM(TIER_CODE))                                                  AS TIER_CODE,
        UPPER(TRIM(COUNTRY))                                                    AS COUNTRY,
        UPPER(TRIM(IS_ACTIVE))                                                  AS IS_ACTIVE,
        TRIM(AGENT_NAME)                                                        AS AGENT_NAME,
        TRIM(STATE)                                                             AS STATE,

        -- Derived columns via macros
        {{ calculate_age('DOB') }}                                              AS AGE,
        {{ is_stale_member('LAST_FLIGHT_DATE') }}                               AS STALE_MEMBER,

        -- Audit
        INGESTION_TIMESTAMP,
        SOURCE_FILE_NAME,

        -- DQ check helpers (kept internal to this CTE)
        TRY_TO_DATE(TRIM(ENROLLMENT_DATE), 'YYYYMMDD')                         AS _enrollment_date_check,
        TRY_TO_DATE(LPAD(TRIM(DOB), 8, '0'), 'MMDDYYYY')                       AS _dob_check,
        -- R08: POST_CODE source value exists but cannot be cast to number
        CASE
            WHEN TRIM(POST_CODE::VARCHAR) IS NOT NULL
             AND TRIM(POST_CODE::VARCHAR) != ''
             AND TRY_TO_NUMBER(TRIM(POST_CODE::VARCHAR)) IS NULL
            THEN TRUE
            ELSE FALSE
        END                                                                     AS _post_code_invalid

    FROM bronze

),

valid_records AS (

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
        SOURCE_FILE_NAME

    FROM parsed

    WHERE
        -- R01: MEMBER_ID is not null/empty
        MEMBER_ID IS NOT NULL
        AND MEMBER_ID != ''

        -- R02: MEMBER_NAME is not null/empty
        AND MEMBER_NAME IS NOT NULL
        AND MEMBER_NAME != ''

        -- R03: ENROLLMENT_DATE is a parseable date (mandatory per spec)
        AND _enrollment_date_check IS NOT NULL

        -- R04: COUNTRY is one of 5 known values
        AND COUNTRY IN ('USA', 'IND', 'CAN', 'AU', 'PHIL')

        -- R05: TIER_CODE is a known value (abbreviated codes from source)
        AND TIER_CODE IN ('GLD', 'SLV', 'PLT', 'BRZ')

        -- R06: DOB is parseable and not a future date
        AND _dob_check IS NOT NULL
        AND _dob_check <= CURRENT_DATE()

        -- R07: IS_ACTIVE is a known flag
        AND IS_ACTIVE IN ('A', 'I')

        -- R08: POST_CODE is either absent or castable to integer
        AND _post_code_invalid = FALSE

),

deduplicated AS (

    SELECT *
    FROM valid_records

    -- DEDUPLICATION: latest record per MEMBER_ID wins
    -- Primary order: LAST_FLIGHT_DATE DESC (most recent activity)
    -- Tie-breaker: INGESTION_TIMESTAMP DESC (most recently ingested batch)
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY MEMBER_ID
        ORDER BY LAST_FLIGHT_DATE DESC NULLS LAST, INGESTION_TIMESTAMP DESC
    ) = 1

)

SELECT * FROM deduplicated

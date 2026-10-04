-- ============================================================================
-- SCRIPT: 02_raw_ingestion.sql
-- PURPOSE: Ingest staged feeds into RAW tables and audit COPY metrics.
--          (Flattening, transformations, and deduplication will be handled by dbt)
-- LAYER: Bronze (Raw Landing & Audit Ingestion)
-- ============================================================================

USE WAREHOUSE SKYPOINTS_WH;
USE DATABASE SKYPOINTS_DB;
USE SCHEMA RAW;

-- ============================================================================
-- 1. INGEST MEMBER PROFILE FLAT FILE INTO RAW.RAW_MEMBER_FEED
-- ============================================================================
-- Design Notes:
-- - The flat file uses leading pipe delimiters: $1 is empty, $2 is Record_Type ('D'/'H').
-- - SKIP_HEADER = 1 skips the header row (|H|...) at the file format level
--   (Snowflake COPY INTO prohibits WHERE clauses in transformation queries).
-- - POST_CODE is supplied as NULL (contract column omitted from physical feed).
-- - ON_ERROR = 'CONTINUE' bypasses corrupted lines so valid data loads seamlessly.
-- ============================================================================

COPY INTO RAW.RAW_MEMBER_FEED (
    MEMBER_NAME,
    MEMBER_ID,
    ENROLLMENT_DATE,
    LAST_FLIGHT_DATE,
    TIER_CODE,
    AGENT_NAME,
    STATE,
    COUNTRY,
    POST_CODE,
    DOB,
    IS_ACTIVE,
    INGESTION_TIMESTAMP,
    SOURCE_FILE_NAME,
    SOURCE_FILE_ROW_NUMBER
)
FROM (
    SELECT
        TRIM($3)::VARCHAR                                           AS MEMBER_NAME,
        TRIM($4)::VARCHAR                                           AS MEMBER_ID,
        TRIM($5)::VARCHAR                                           AS ENROLLMENT_DATE,
        TRIM($6)::VARCHAR                                           AS LAST_FLIGHT_DATE,
        TRIM($7)::VARCHAR                                           AS TIER_CODE,
        TRIM($8)::VARCHAR                                           AS AGENT_NAME,
        TRIM($9)::VARCHAR                                           AS STATE,
        TRIM($10)::VARCHAR                                          AS COUNTRY,
        NULL::VARCHAR                                               AS POST_CODE,
        TRIM($11)::VARCHAR                                          AS DOB,
        TRIM($12)::VARCHAR                                          AS IS_ACTIVE,
        CURRENT_TIMESTAMP()                                         AS INGESTION_TIMESTAMP,
        METADATA$FILENAME                                           AS SOURCE_FILE_NAME,
        METADATA$FILE_ROW_NUMBER                                    AS SOURCE_FILE_ROW_NUMBER
    FROM @RAW.STAGE_MEMBER_FEED
)
FILE_FORMAT = (FORMAT_NAME = 'RAW.FF_PIPE_DELIMITED')
ON_ERROR = 'CONTINUE';

-- Capture member feed ingestion metrics into audit log
INSERT INTO LOGS.INGESTION_LOGS (
    BATCH_ID,
    TARGET_TABLE,
    SOURCE_FILE_NAME,
    STAGE_NAME,
    STATUS,
    ROWS_PARSED,
    ROWS_LOADED,
    ERRORS_SEEN,
    FIRST_ERROR_MESSAGE,
    FIRST_ERROR_LINE,
    LOAD_TIMESTAMP,
    LOADED_BY
)
SELECT
    'BATCH_MBR_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD_HH24MISS'),
    'RAW.RAW_MEMBER_FEED',
    $1,     -- file
    '@RAW.STAGE_MEMBER_FEED',
    $2,     -- status
    $3,     -- rows_parsed
    $4,     -- rows_loaded
    $6,     -- errors_seen
    $7,     -- first_error
    $8,     -- first_error_line
    CURRENT_TIMESTAMP(),
    CURRENT_USER()
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));


-- ============================================================================
-- 2. INGEST JSON REDEMPTION FEED INTO RAW.RAW_REDEMPTION_FEED_HIST
-- ============================================================================
-- Design Notes:
-- - Ingests complete NDJSON payload into VARIANT column for immutable auditing.
-- - Promotes member_id to a top-level column for micro-partition pruning.
-- ============================================================================

COPY INTO RAW.RAW_REDEMPTION_FEED_HIST (
    MEMBER_ID,
    RAW_PAYLOAD,
    INGESTION_TIMESTAMP,
    SOURCE_FILE_NAME
)
FROM (
    SELECT
        $1:member_id::VARCHAR       AS MEMBER_ID,
        $1                          AS RAW_PAYLOAD,
        CURRENT_TIMESTAMP()         AS INGESTION_TIMESTAMP,
        METADATA$FILENAME           AS SOURCE_FILE_NAME
    FROM @RAW.STAGE_REDEMPTION_FEED
)
FILE_FORMAT = (FORMAT_NAME = 'RAW.FF_JSON')
ON_ERROR = 'CONTINUE';

-- Capture redemption feed ingestion metrics into audit log
INSERT INTO LOGS.INGESTION_LOGS (
    BATCH_ID,
    TARGET_TABLE,
    SOURCE_FILE_NAME,
    STAGE_NAME,
    STATUS,
    ROWS_PARSED,
    ROWS_LOADED,
    ERRORS_SEEN,
    FIRST_ERROR_MESSAGE,
    FIRST_ERROR_LINE,
    LOAD_TIMESTAMP,
    LOADED_BY
)
SELECT
    'BATCH_RED_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD_HH24MISS'),
    'RAW.RAW_REDEMPTION_FEED_HIST',
    $1,     -- file
    '@RAW.STAGE_REDEMPTION_FEED',
    $2,     -- status
    $3,     -- rows_parsed
    $4,     -- rows_loaded
    $6,     -- errors_seen
    $7,     -- first_error
    $8,     -- first_error_line
    CURRENT_TIMESTAMP(),
    CURRENT_USER()
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));


-- ============================================================================
-- 3. VERIFICATION / AUDIT QUERIES
-- ============================================================================
-- Check row counts across raw landing tables
SELECT 'RAW_MEMBER_FEED' AS TABLE_NAME, COUNT(*) AS RECORD_COUNT FROM RAW.RAW_MEMBER_FEED
UNION ALL
SELECT 'RAW_REDEMPTION_FEED_HIST', COUNT(*) FROM RAW.RAW_REDEMPTION_FEED_HIST;

-- Inspect ingestion audit log entries
SELECT * FROM LOGS.INGESTION_LOGS ORDER BY LOAD_TIMESTAMP DESC;

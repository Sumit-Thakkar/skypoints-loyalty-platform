-- ============================================================================
-- SCRIPT: 01_raw_landing_ddl.sql
-- PURPOSE: Deliverable 1 - DDL for Raw/Landing Tables
-- LAYER: Bronze (Raw Landing Zone)
-- ============================================================================

USE DATABASE SKYPOINTS_DB;
USE SCHEMA RAW;

-- ============================================================================
-- 1. RAW MEMBER FLAT FILE LANDING TABLE
-- 11-column specification layout (Page 2) with Snowflake native data types
-- ============================================================================

-- Lenient Bronze Architecture Notes:
-- 1. In a Medallion Architecture, Bronze landing is maximally permissive (lenient)
--    so that corrupted, oversized, or malformed data (e.g. 'UNKNOWN_LONG_COUNTRY')
--    lands successfully without ingestion aborts.
-- 2. Silver (dbt) applies strict validation rules and routes corrupted rows to
--    STG_QUARANTINE_MEMBERS (Dead Letter Queue).
-- 3. Record Type ('D'/'H') is filtered out at file format level (SKIP_HEADER = 1).
-- 4. POST_CODE is included as NULLABLE to satisfy the written contract column.
CREATE OR REPLACE TABLE RAW.RAW_MEMBER_FEED (
    MEMBER_NAME             VARCHAR,                    -- Position 1: Unconstrained VARCHAR
    MEMBER_ID               VARCHAR,                    -- Position 2: Unconstrained VARCHAR
    ENROLLMENT_DATE         VARCHAR,                    -- Position 3: Raw string as received (e.g. YYYYMMDD)
    LAST_FLIGHT_DATE        VARCHAR,                    -- Position 4: Raw string as received (e.g. YYYYMMDD)
    TIER_CODE               VARCHAR,                    -- Position 5: Unconstrained VARCHAR
    AGENT_NAME              VARCHAR,                    -- Position 6: Unconstrained VARCHAR
    STATE                   VARCHAR,                    -- Position 7: Unconstrained VARCHAR
    COUNTRY                 VARCHAR,                    -- Position 8: Unconstrained VARCHAR to allow any dirty codes
    POST_CODE               VARCHAR DEFAULT NULL,        -- Position 9: Unconstrained NUMBER contract column
    DOB                     VARCHAR,                    -- Position 10: Raw string as received (e.g. MMDDYYYY)
    IS_ACTIVE               VARCHAR,                    -- Position 11: Unconstrained VARCHAR
    
    -- Audit / Lineage Metadata Columns
    INGESTION_TIMESTAMP     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SOURCE_FILE_NAME        VARCHAR
)
COMMENT = 'Lenient Bronze all-string landing table for daily member feeds preserving raw source fidelity for Silver quarantine';

-- ============================================================================
-- 2. RAW JSON REDEMPTION DOCUMENT STORE (HISTORY TABLE)
-- Stores complete inbound JSON payloads with MEMBER_ID extracted for partition pruning
-- ============================================================================
CREATE OR REPLACE TABLE RAW.RAW_REDEMPTION_FEED_HIST (
    MEMBER_ID               VARCHAR,            -- Extracted from RAW_PAYLOAD:member_id
    RAW_PAYLOAD             VARIANT,            -- Complete raw nested JSON document
    -- Audit Metadata Columns
    INGESTION_TIMESTAMP     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SOURCE_FILE_NAME        VARCHAR
)
COMMENT = 'Raw immutable document store for daily partner airline JSON feeds';

-- ============================================================================
-- 3. RAW FLATTENED REDEMPTION TABLE
-- Flattens nested transactions in RAW
-- ============================================================================
CREATE OR REPLACE TABLE RAW.RAW_REDEMPTION_FEED (
    MEMBER_ID               VARCHAR,
    FEED_DATE               VARCHAR,
    TXN_ID                  VARCHAR,
    TXN_DATE                VARCHAR,
    PARTNER                 VARCHAR,
    MILES_REDEEMED          VARCHAR,
    STATUS                  VARCHAR,
    -- Audit Metadata Columns
    INGESTION_TIMESTAMP     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SOURCE_FILE_NAME        VARCHAR
)
COMMENT = 'Flattened raw transactions parsed from JSON feeds';

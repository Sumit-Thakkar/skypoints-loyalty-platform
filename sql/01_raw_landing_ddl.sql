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

-- Data Craftsmanship Notes:
-- 1. Record Type ('D'/'H') is used during file ingestion to filter out header rows
--    and is omitted from the table schema to preserve exact 1-to-1 spec alignment.
-- 2. POST_CODE is included as NULLABLE to satisfy the written data contract,
--    while safely handling the physical feed which omitted it.
CREATE OR REPLACE TABLE RAW.RAW_MEMBER_FEED (
    MEMBER_NAME             VARCHAR(255),               -- Position 1: VARCHAR(255)
    MEMBER_ID               VARCHAR(18),                -- Position 2: VARCHAR(18)
    ENROLLMENT_DATE         DATE,                       -- Position 3: DATE (YYYYMMDD)
    LAST_FLIGHT_DATE        DATE,                       -- Position 4: DATE (YYYYMMDD)
    TIER_CODE               CHAR(5),                    -- Position 5: CHAR(5)
    AGENT_NAME              VARCHAR(255),               -- Position 6: CHAR(255)
    STATE                   CHAR(5),                    -- Position 7: CHAR(5)
    COUNTRY                 CHAR(5),                    -- Position 8: CHAR(5)
    POST_CODE               NUMBER(5,0) DEFAULT NULL,   -- Position 9: INT(5) contract column
    DOB                     DATE,                       -- Position 10: DATE (MMDDYYYY)
    IS_ACTIVE               CHAR(1),                    -- Position 11: CHAR(1)
    
    -- Audit / Lineage Metadata Columns
    INGESTION_TIMESTAMP     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SOURCE_FILE_NAME        VARCHAR(255)
)
COMMENT = 'Raw landing table for daily member profile feeds adhering to specification data types';

-- ============================================================================
-- 2. RAW JSON REDEMPTION DOCUMENT STORE (HISTORY TABLE)
-- Stores complete inbound JSON payloads with MEMBER_ID extracted for partition pruning
-- ============================================================================
CREATE OR REPLACE TABLE RAW.RAW_REDEMPTION_FEED_HIST (
    MEMBER_ID               VARCHAR(18),        -- Extracted from RAW_PAYLOAD:member_id
    RAW_PAYLOAD             VARIANT,            -- Complete raw nested JSON document
    -- Audit Metadata Columns
    INGESTION_TIMESTAMP     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SOURCE_FILE_NAME        VARCHAR(255)
)
COMMENT = 'Raw immutable document store for daily partner airline JSON feeds';

-- ============================================================================
-- 3. RAW FLATTENED REDEMPTION TABLE
-- Flattens nested transactions in RAW
-- ============================================================================
CREATE OR REPLACE TABLE RAW.RAW_REDEMPTION_FEED (
    MEMBER_ID               VARCHAR(18),
    FEED_DATE               DATE,
    TXN_ID                  VARCHAR(50),
    TXN_DATE                DATE,
    PARTNER                 VARCHAR(100),
    MILES_REDEEMED          NUMBER(10,0),
    STATUS                  VARCHAR(20),
    -- Audit Metadata Columns
    INGESTION_TIMESTAMP     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SOURCE_FILE_NAME        VARCHAR(255)
)
COMMENT = 'Flattened raw transactions parsed from JSON feeds';

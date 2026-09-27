-- ============================================================================
-- SCRIPT: 00_logs_ddl.sql
-- PURPOSE: Provision Operational Audit & Ingestion Logging Tables
-- LAYER: Observability & Governance
-- ============================================================================

USE DATABASE SKYPOINTS_DB;
USE SCHEMA LOGS;

-- ============================================================================
-- 1. INGESTION AUDIT LOG TABLE
-- Captures metadata, record metrics, and error diagnostics from COPY commands
-- ============================================================================
CREATE OR REPLACE TABLE LOGS.INGESTION_LOGS (
    LOG_ID                  NUMBER AUTOINCREMENT,
    BATCH_ID                VARCHAR(50),                -- Unique batch/execution ID
    TARGET_TABLE            VARCHAR(100),               -- e.g. 'RAW.RAW_MEMBER_FEED'
    SOURCE_FILE_NAME        VARCHAR(255),               -- Name of file in stage
    STAGE_NAME              VARCHAR(100),               -- e.g. '@RAW.STAGE_MEMBER_FEED'
    STATUS                  VARCHAR(50),                -- 'LOADED', 'PARTIALLY_LOADED', 'FAILED'
    ROWS_PARSED             NUMBER,                     -- Total rows evaluated from file
    ROWS_LOADED             NUMBER,                     -- Total rows successfully loaded
    ERRORS_SEEN             NUMBER,                     -- Corrupted rows skipped
    FIRST_ERROR_MESSAGE     VARCHAR(1000),              -- Diagnostic error message
    FIRST_ERROR_LINE        NUMBER,                     -- Line number where first error occurred
    LOAD_TIMESTAMP          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    LOADED_BY               VARCHAR(100) DEFAULT CURRENT_USER()
)
COMMENT = 'Audit trail tracking all stage-to-raw copy operations and file metrics';\n
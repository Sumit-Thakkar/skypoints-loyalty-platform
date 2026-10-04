-- ============================================================================
-- SCRIPT: 00_setup.sql
-- PURPOSE: Provision Snowflake Database, RAW Schema, Stages & File Formats
-- NOTE: STAGING and MARTS schemas are created automatically by dbt
-- ============================================================================

-- 1. Create Dedicated Virtual Warehouse
CREATE WAREHOUSE IF NOT EXISTS SKYPOINTS_WH
    WITH 
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Virtual warehouse for SkyPoints loyalty data processing';

USE WAREHOUSE SKYPOINTS_WH;

-- 2. Create Database
CREATE DATABASE IF NOT EXISTS SKYPOINTS_DB
    COMMENT = 'Enterprise Database for SkyPoints Airline Loyalty Program';

USE DATABASE SKYPOINTS_DB;

-- 3. Create Schemas
CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Raw landing zone: immutable, append-only source feeds';

CREATE SCHEMA IF NOT EXISTS LOGS
    COMMENT = 'Operational metadata, audit logs, and quarantine Dead Letter Queue (DLQ) zone';

-- 4. Create Ingestion File Formats inside RAW
CREATE OR REPLACE FILE FORMAT RAW.FF_PIPE_DELIMITED
    TYPE = 'CSV'
    FIELD_DELIMITER = '|'
    SKIP_HEADER = 1
    TRIM_SPACE = TRUE
    EMPTY_FIELD_AS_NULL = TRUE
    NULL_IF = ('', 'NULL', 'null')
    COMMENT = 'File format for pipe-delimited member profile flat files';

CREATE OR REPLACE FILE FORMAT RAW.FF_JSON
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = FALSE
    COMMENT = 'File format for partner airline JSON redemption transaction feeds (NDJSON — one object per line)';

-- 5. Create Snowflake Internal Stages for File Uploads inside RAW
CREATE OR REPLACE STAGE RAW.STAGE_MEMBER_FEED
    FILE_FORMAT = RAW.FF_PIPE_DELIMITED
    COMMENT = 'Internal stage for daily member profile flat files';

CREATE OR REPLACE STAGE RAW.STAGE_REDEMPTION_FEED
    FILE_FORMAT = RAW.FF_JSON
    COMMENT = 'Internal stage for daily partner airline JSON redemption feeds';

-- ============================================================================
-- GIT INTEGRATION SETUP (Enables Snowflake Git Workspaces & dbt Projects)
-- ============================================================================

-- 6. Authorize Snowflake to connect to GitHub via HTTPS
-- Note: ALLOWED_AUTHENTICATION_SECRETS = all allows Snowflake to use GitHub Personal Access Tokens
CREATE OR REPLACE API INTEGRATION git_api_integration
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/Sumit-Thakkar')
    ALLOWED_AUTHENTICATION_SECRETS = all
    ENABLED = TRUE
    COMMENT = 'Git API integration for SkyPoints loyalty platform repository';

-- 7. Optional Git Secret Template (Required for private repos or 2-way push authentication)
-- In Snowflake UI: Created via 'Create secret' modal under SKYPOINTS_DB.RAW
/*
CREATE OR REPLACE SECRET RAW.github_secret
    TYPE = password
    USERNAME = 'Sumit-Thakkar'
    PASSWORD = '<YOUR_GITHUB_PERSONAL_ACCESS_TOKEN>'
    COMMENT = 'GitHub Personal Access Token for Git workspace synchronization';
*/

-- 8. Create Git Repository Stage inside SKYPOINTS_DB.RAW
-- Connects Snowflake directly to the GitHub repository to sync dbt models and scripts
CREATE OR REPLACE GIT REPOSITORY SKYPOINTS_DB.RAW.skypoints_repo
    API_INTEGRATION = git_api_integration
    ORIGIN = 'https://github.com/Sumit-Thakkar/skypoints-loyalty-platform.git'
    COMMENT = 'Snowflake Git Repository stage mirroring GitHub main branch';

-- 9. Fetch latest commits and files from GitHub
ALTER GIT REPOSITORY SKYPOINTS_DB.RAW.skypoints_repo FETCH;


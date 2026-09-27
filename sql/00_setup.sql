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

-- 3. Create RAW Schema (Landing Layer)
CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Raw landing zone: immutable, append-only source feeds';

-- 4. Create Ingestion File Formats inside RAW
CREATE OR REPLACE FILE FORMAT RAW.FF_PIPE_DELIMITED
    TYPE = 'CSV'
    FIELD_DELIMITER = '|'
    SKIP_HEADER = 0
    TRIM_SPACE = TRUE
    EMPTY_FIELD_AS_NULL = TRUE
    NULL_IF = ('', 'NULL', 'null')
    COMMENT = 'File format for pipe-delimited member profile flat files';

CREATE OR REPLACE FILE FORMAT RAW.FF_JSON
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = TRUE
    COMMENT = 'File format for partner airline JSON redemption transaction feeds';

-- 5. Create Snowflake Internal Stages for File Uploads inside RAW
CREATE OR REPLACE STAGE RAW.STAGE_MEMBER_FEED
    FILE_FORMAT = RAW.FF_PIPE_DELIMITED
    COMMENT = 'Internal stage for daily member profile flat files';

CREATE OR REPLACE STAGE RAW.STAGE_REDEMPTION_FEED
    FILE_FORMAT = RAW.FF_JSON
    COMMENT = 'Internal stage for daily partner airline JSON redemption feeds';

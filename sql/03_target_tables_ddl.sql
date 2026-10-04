-- ============================================================================
-- SCRIPT: 03_target_tables_ddl.sql
-- PURPOSE: Deliverable 1 - DDL for Staging and Country-Specific Target Tables
-- LAYER: Silver (Staging) & Gold (Country Marts + Fact Table)
-- NOTE: In production, these tables are materialized and updated via dbt models.
--       This script provides the underlying Snowflake DDL specifications.
-- ============================================================================

USE DATABASE SKYPOINTS_DB;

-- ============================================================================
-- 1. SILVER STAGING TABLES (STAGING SCHEMA)
-- ============================================================================
USE SCHEMA STAGING;

-- Cleaned, typed, and deduplicated member profiles
CREATE OR REPLACE TABLE STAGING.STG_MEMBERS (
    MEMBER_ID               VARCHAR(18)   NOT NULL,
    MEMBER_NAME             VARCHAR(255)  NOT NULL,
    ENROLLMENT_DATE         DATE          NOT NULL,
    LAST_FLIGHT_DATE        DATE,
    DOB                     DATE,
    TIER_CODE               VARCHAR(5)    NOT NULL,
    COUNTRY                 VARCHAR(3)    NOT NULL,
    IS_ACTIVE               VARCHAR(1)    NOT NULL,
    AGENT_NAME              VARCHAR(255),
    STATE                   VARCHAR(5),
    POST_CODE               NUMBER,
    AGE                     NUMBER,
    STALE_MEMBER            VARCHAR(1),
    INGESTION_TIMESTAMP     TIMESTAMP_NTZ NOT NULL,
    SOURCE_FILE_NAME        VARCHAR       NOT NULL,
    SOURCE_FILE_ROW_NUMBER  NUMBER        NOT NULL,
    CONSTRAINT PK_STG_MEMBERS PRIMARY KEY (MEMBER_ID)
)
COMMENT = 'Silver cleansed, typed, and deduplicated member profile table';

-- Cleaned, typed, and validated redemption transactions
CREATE OR REPLACE TABLE STAGING.STG_REDEMPTIONS (
    TXN_ID                  VARCHAR       NOT NULL,
    MEMBER_ID               VARCHAR(18)   NOT NULL,
    FEED_DATE               DATE,
    TXN_DATE                DATE          NOT NULL,
    PARTNER                 VARCHAR,
    MILES_REDEEMED          NUMBER        NOT NULL,
    STATUS                  VARCHAR       NOT NULL,
    INGESTION_TIMESTAMP     TIMESTAMP_NTZ NOT NULL,
    SOURCE_FILE_NAME        VARCHAR       NOT NULL,
    CONSTRAINT PK_STG_REDEMPTIONS PRIMARY KEY (TXN_ID),
    CONSTRAINT FK_STG_REDEMPTIONS_MEMBER FOREIGN KEY (MEMBER_ID) REFERENCES STAGING.STG_MEMBERS(MEMBER_ID)
)
COMMENT = 'Silver cleansed redemption transaction table with referential integrity to stg_members';


-- ============================================================================
-- 2. GOLD COUNTRY-SPECIFIC TARGET TABLES (MARTS SCHEMA)
-- Deliverable 3: Per-country target tables enforcing "latest record wins"
-- ============================================================================
USE SCHEMA MARTS;

-- Target Table: India
CREATE OR REPLACE TABLE MARTS.TABLE_INDIA (
    MEMBER_ID               VARCHAR(18)   NOT NULL,
    MEMBER_NAME             VARCHAR(255)  NOT NULL,
    ENROLLMENT_DATE         DATE          NOT NULL,
    LAST_FLIGHT_DATE        DATE,
    DOB                     DATE,
    TIER_CODE               VARCHAR(5)    NOT NULL,
    COUNTRY                 VARCHAR(3)    NOT NULL,
    IS_ACTIVE               VARCHAR(1)    NOT NULL,
    AGENT_NAME              VARCHAR(255),
    STATE                   VARCHAR(5),
    POST_CODE               NUMBER,
    AGE                     NUMBER,
    STALE_MEMBER            VARCHAR(1),
    INGESTION_TIMESTAMP     TIMESTAMP_NTZ NOT NULL,
    SOURCE_FILE_NAME        VARCHAR       NOT NULL,
    SOURCE_FILE_ROW_NUMBER  NUMBER        NOT NULL,
    MART_LOADED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_TABLE_INDIA PRIMARY KEY (MEMBER_ID)
)
COMMENT = 'Gold mart for members residing in India (Deliverable 3)';

-- Target Table: USA
CREATE OR REPLACE TABLE MARTS.TABLE_USA (
    MEMBER_ID               VARCHAR(18)   NOT NULL,
    MEMBER_NAME             VARCHAR(255)  NOT NULL,
    ENROLLMENT_DATE         DATE          NOT NULL,
    LAST_FLIGHT_DATE        DATE,
    DOB                     DATE,
    TIER_CODE               VARCHAR(5)    NOT NULL,
    COUNTRY                 VARCHAR(3)    NOT NULL,
    IS_ACTIVE               VARCHAR(1)    NOT NULL,
    AGENT_NAME              VARCHAR(255),
    STATE                   VARCHAR(5),
    POST_CODE               NUMBER,
    AGE                     NUMBER,
    STALE_MEMBER            VARCHAR(1),
    INGESTION_TIMESTAMP     TIMESTAMP_NTZ NOT NULL,
    SOURCE_FILE_NAME        VARCHAR       NOT NULL,
    SOURCE_FILE_ROW_NUMBER  NUMBER        NOT NULL,
    MART_LOADED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_TABLE_USA PRIMARY KEY (MEMBER_ID)
)
COMMENT = 'Gold mart for members residing in USA (Deliverable 3)';

-- Target Table: Canada
CREATE OR REPLACE TABLE MARTS.TABLE_CANADA (
    MEMBER_ID               VARCHAR(18)   NOT NULL,
    MEMBER_NAME             VARCHAR(255)  NOT NULL,
    ENROLLMENT_DATE         DATE          NOT NULL,
    LAST_FLIGHT_DATE        DATE,
    DOB                     DATE,
    TIER_CODE               VARCHAR(5)    NOT NULL,
    COUNTRY                 VARCHAR(3)    NOT NULL,
    IS_ACTIVE               VARCHAR(1)    NOT NULL,
    AGENT_NAME              VARCHAR(255),
    STATE                   VARCHAR(5),
    POST_CODE               NUMBER,
    AGE                     NUMBER,
    STALE_MEMBER            VARCHAR(1),
    INGESTION_TIMESTAMP     TIMESTAMP_NTZ NOT NULL,
    SOURCE_FILE_NAME        VARCHAR       NOT NULL,
    SOURCE_FILE_ROW_NUMBER  NUMBER        NOT NULL,
    MART_LOADED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_TABLE_CANADA PRIMARY KEY (MEMBER_ID)
)
COMMENT = 'Gold mart for members residing in Canada (Deliverable 3)';

-- Target Table: Australia
CREATE OR REPLACE TABLE MARTS.TABLE_AUSTRALIA (
    MEMBER_ID               VARCHAR(18)   NOT NULL,
    MEMBER_NAME             VARCHAR(255)  NOT NULL,
    ENROLLMENT_DATE         DATE          NOT NULL,
    LAST_FLIGHT_DATE        DATE,
    DOB                     DATE,
    TIER_CODE               VARCHAR(5)    NOT NULL,
    COUNTRY                 VARCHAR(3)    NOT NULL,
    IS_ACTIVE               VARCHAR(1)    NOT NULL,
    AGENT_NAME              VARCHAR(255),
    STATE                   VARCHAR(5),
    POST_CODE               NUMBER,
    AGE                     NUMBER,
    STALE_MEMBER            VARCHAR(1),
    INGESTION_TIMESTAMP     TIMESTAMP_NTZ NOT NULL,
    SOURCE_FILE_NAME        VARCHAR       NOT NULL,
    SOURCE_FILE_ROW_NUMBER  NUMBER        NOT NULL,
    MART_LOADED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_TABLE_AUSTRALIA PRIMARY KEY (MEMBER_ID)
)
COMMENT = 'Gold mart for members residing in Australia (Deliverable 3)';

-- Target Table: Philippines
CREATE OR REPLACE TABLE MARTS.TABLE_PHILIPPINES (
    MEMBER_ID               VARCHAR(18)   NOT NULL,
    MEMBER_NAME             VARCHAR(255)  NOT NULL,
    ENROLLMENT_DATE         DATE          NOT NULL,
    LAST_FLIGHT_DATE        DATE,
    DOB                     DATE,
    TIER_CODE               VARCHAR(5)    NOT NULL,
    COUNTRY                 VARCHAR(3)    NOT NULL,
    IS_ACTIVE               VARCHAR(1)    NOT NULL,
    AGENT_NAME              VARCHAR(255),
    STATE                   VARCHAR(5),
    POST_CODE               NUMBER,
    AGE                     NUMBER,
    STALE_MEMBER            VARCHAR(1),
    INGESTION_TIMESTAMP     TIMESTAMP_NTZ NOT NULL,
    SOURCE_FILE_NAME        VARCHAR       NOT NULL,
    SOURCE_FILE_ROW_NUMBER  NUMBER        NOT NULL,
    MART_LOADED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_TABLE_PHILIPPINES PRIMARY KEY (MEMBER_ID)
)
COMMENT = 'Gold mart for members residing in Philippines (Deliverable 3)';



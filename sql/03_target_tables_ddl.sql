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

-- ============================================================================
-- 3. GOLD ANALYTICAL FACT TABLE (MARTS SCHEMA)
-- Deliverable 4: Redemptions joined back to Member Profiles with behavioral & demographic enrichment
-- ============================================================================
CREATE OR REPLACE TABLE MARTS.FCT_MEMBER_REDEMPTIONS (
    TXN_ID                  VARCHAR       NOT NULL,
    MEMBER_ID               VARCHAR(18)   NOT NULL,
    FEED_DATE               DATE,
    TXN_DATE                DATE          NOT NULL,
    PARTNER                 VARCHAR       NOT NULL,
    PARTNER_TYPE            VARCHAR       NOT NULL,     -- INTERNAL vs ALLIANCE_PARTNER
    MILES_REDEEMED          NUMBER        NOT NULL,
    REDEMPTION_STATUS       VARCHAR       NOT NULL,
    MEMBER_NAME             VARCHAR(255)  NOT NULL,
    MEMBER_TIER_CODE        VARCHAR(5)    NOT NULL,
    MEMBER_TIER_NAME        VARCHAR(20)   NOT NULL,     -- Gold, Platinum, Silver, Bronze
    MEMBER_COUNTRY          VARCHAR(3)    NOT NULL,
    MEMBER_STATE            VARCHAR(5),
    MEMBER_IS_ACTIVE        VARCHAR(1)    NOT NULL,
    MEMBER_AGE              NUMBER,
    MEMBER_AGE_GROUP        VARCHAR(20),                -- Under 25, 25-39, 40-59, 60+
    MEMBER_ENROLLMENT_DATE  DATE          NOT NULL,
    MEMBER_LAST_FLIGHT_DATE DATE,
    MEMBER_TENURE_DAYS_AT_TXN NUMBER,                   -- Days enrolled before transaction
    DAYS_SINCE_LAST_FLIGHT_AT_TXN NUMBER,               -- Flight recency at transaction date
    WAS_STALE_AT_REDEMPTION VARCHAR(1),                 -- Inactivity flag (>90 days) at transaction date
    REDEMPTION_INGESTION_TIMESTAMP TIMESTAMP_NTZ NOT NULL,
    MART_LOADED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_FCT_MEMBER_REDEMPTIONS PRIMARY KEY (TXN_ID),
    CONSTRAINT FK_FCT_MEMBER FOREIGN KEY (MEMBER_ID) REFERENCES STAGING.STG_MEMBERS(MEMBER_ID)
)
COMMENT = 'Gold analytical fact mart joining flattened redemptions with enriched member profiles (Deliverable 4)';

-- ============================================================================
-- 4. GOLD AGGREGATED SUMMARY FACT TABLE (MARTS SCHEMA)
-- Pre-aggregated metrics for executive and dashboard consumption
-- ============================================================================
CREATE OR REPLACE TABLE MARTS.AGG_COUNTRY_REDEMPTION_SUMMARY (
    MEMBER_COUNTRY          VARCHAR(3)    NOT NULL,
    PARTNER                 VARCHAR       NOT NULL,
    PARTNER_TYPE            VARCHAR       NOT NULL,
    REDEMPTION_STATUS       VARCHAR       NOT NULL,
    TOTAL_TRANSACTIONS      NUMBER        NOT NULL,
    UNIQUE_REDEEMING_MEMBERS NUMBER       NOT NULL,
    TOTAL_MILES_REDEEMED    NUMBER        NOT NULL,
    AVG_MILES_PER_TXN       NUMBER(10, 2) NOT NULL,
    MIN_MILES_REDEEMED      NUMBER        NOT NULL,
    MAX_MILES_REDEEMED      NUMBER        NOT NULL,
    STALE_MEMBER_TXN_COUNT  NUMBER        NOT NULL,
    STALE_MEMBER_MILES_REDEEMED NUMBER    NOT NULL,
    EARLIEST_TXN_DATE       DATE,
    LATEST_TXN_DATE         DATE,
    MART_LOADED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_AGG_COUNTRY_REDEMPTIONS PRIMARY KEY (MEMBER_COUNTRY, PARTNER, PARTNER_TYPE, REDEMPTION_STATUS)
)
COMMENT = 'Gold aggregated mart summarizing mileage redemptions by country, partner, and status for O(1) executive reporting';




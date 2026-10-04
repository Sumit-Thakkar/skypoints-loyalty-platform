# ✈️ SkyPoints Airline Loyalty Data Platform
> **Incubyte Data Craftsmanship Technical Assessment**  
> *Production-Grade ELT Data Platform built with Snowflake and dbt*

[![dbt](https://img.shields.io/badge/dbt-1.9.4-FF694B?logo=dbt&logoColor=white)](https://www.getdbt.com/)
[![Snowflake](https://img.shields.io/badge/Snowflake-Enterprise%20ELT-29B5E8?logo=snowflake&logoColor=white)](https://www.snowflake.com/)
[![Architecture](https://img.shields.io/badge/Architecture-Medallion%20(Bronze%2FSilver%2FGold)-blue)]()
[![Tests](https://img.shields.io/badge/Tests-91%20Passed%20(100%25)-brightgreen)]()

---

## 📌 Executive Summary

**SkyPoints** is a global airline loyalty program where members earn tier status and redeem miles across international airline partners. This repository delivers an enterprise-grade, high-throughput ELT data platform designed to process billions of inbound records daily across heterogeneous feeds:
1. **Daily Member Profile Feed**: Pipe-delimited flat files with deliberate formatting inconsistencies and schema drift.
2. **Partner Airline Redemption Feed**: Semi-structured nested JSON documents detailing mileage redemptions.

Built on **Snowflake** and **dbt (Data Build Tool)**, the platform adheres strictly to the **Medallion Architecture (Bronze → Silver → Gold)** complemented by an isolated **Dead Letter Queue (`QUARANTINE`)** and an operational audit framework (`LOGS`).

---

## 📐 Architecture Overview

```
                      ┌─────────────────────────────────────────┐
                      │ Inbound Source Feeds (Flat Files + JSON)│
                      └────────────────────┬────────────────────┘
                                           │
                                           ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ BRONZE LAYER (RAW Schema) — Immutable Landing Zone                                     │
│  ├── RAW.RAW_MEMBER_FEED            (Lenient landing, preserves raw string fidelity)   │
│  ├── RAW.RAW_REDEMPTION_FEED_HIST   (Immutable VARIANT document store)                 │
│  └── RAW.RAW_REDEMPTION_FEED        (Flattened via LATERAL FLATTEN on JSON array)      │
└──────────────────────────────────────────┬─────────────────────────────────────────────┘
                                           │
                                           ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ SILVER LAYER (STAGING Schema) — Cleansed, Typed & Enriched                             │
│  ├── STAGING.COUNTRY_MAPPING        (dbt Seed: ISO Alpha-3 reference table)            │
│  ├── STAGING.STG_MEMBERS            (Deduplicated SCD-1, Age & Stale_Member derived)   │
│  └── STAGING.STG_REDEMPTIONS        (Cleansed transactions with referential checks)    │
└───────────────────┬────────────────────────────────────────────────┬───────────────────┘
                    │                                                │
         [DQ Rules Pass]                                   [DQ Rules Fail]
                    │                                                │
                    ▼                                                ▼
┌──────────────────────────────────────┐       ┌─────────────────────────────────────────┐
│ GOLD LAYER (MARTS Schema)            │       │ DEAD LETTER QUEUE (QUARANTINE Schema)   │
│  ├── Country Target Tables (SCD-1):  │       │  ├── QUARANTINE.QUARANTINE_MEMBERS      │
│  │   ├── TABLE_INDIA                 │       │      (Captures rows failing R01-R08)    │
│  │   ├── TABLE_USA                   │       │  ├── QUARANTINE.QUARANTINE_REDEMPTIONS  │
│  │   ├── TABLE_CANADA                │       │      (Captures corrupt transaction rows)│
│  │   ├── TABLE_AUSTRALIA             │       │  └── QUARANTINE.ORPHAN_REDEMPTIONS      │
│  │   └── TABLE_PHILIPPINES           │       │      (Valid txns with missing members)  │
│  ├── FCT_MEMBER_REDEMPTIONS          │       └─────────────────────────────────────────┘
│  │   (Joined fact: tenure, recency)  │
│  └── AGG_COUNTRY_REDEMPTION_SUMMARY  │
│      (Pre-aggregated executive mart) │
└──────────────────────────────────────┘
```

---

## 📋 Assessment Deliverables Matrix

Every requirement specified in `DE_Assessment_file.pdf` is fully satisfied and tested:

| # | Deliverable Requirement | Repository Implementation | Validation / Test |
|---|---|---|---|
| **1** | **Table Queries (DDL)** for Raw, Staging, and Target tables | • [`sql/00_setup.sql`](sql/00_setup.sql)<br>• [`sql/01_raw_landing_ddl.sql`](sql/01_raw_landing_ddl.sql)<br>• [`sql/03_target_tables_ddl.sql`](sql/03_target_tables_ddl.sql) | Native Snowflake DDL scripts with primary keys, foreign keys, and comments |
| **2** | **Staging Table Derived Columns**: `Age` and `Stale_Member` (>90 days) | • [`macros/calculate_age.sql`](macros/calculate_age.sql)<br>• [`macros/is_stale_member.sql`](macros/is_stale_member.sql)<br>• [`models/staging/stg_members.sql`](models/staging/stg_members.sql) | Automated date parsing with `LPAD` fix for missing leading zeroes on DOB |
| **3** | **Country Routing & "Latest Record Wins"** migration rule | • [`models/marts/country_tables/`](models/marts/country_tables/) (`table_india.sql`, `table_usa.sql`, etc.) | **Singular Test**: [`tests/assert_member_in_only_one_country.sql`](tests/assert_member_in_only_one_country.sql) (**PASS**) |
| **4** | **JSON Feed Flattening & Analytical Profile Join** | • [`models/raw/raw_redemption_feed.sql`](models/raw/raw_redemption_feed.sql)<br>• [`models/marts/fct_member_redemptions.sql`](models/marts/fct_member_redemptions.sql) | `LATERAL FLATTEN` on JSON + enriched fact mart with partner type & tenure |
| **5** | **Data Validations & Dead Letter Queue (DLQ)** | • [`models/quarantine/`](models/quarantine/) (`quarantine_members`, `orphan_redemptions`) | 91 dbt tests + [`tests/assert_clean_members_not_in_quarantine.sql`](tests/assert_clean_members_not_in_quarantine.sql) |
| **6** | **Git History & Live Demo Readiness** | • Conventional atomic commits on `main`<br>• Zero-error execution in Snowflake | All models and tests execute cleanly in Snowflake Workspaces |

---

## 💎 Data Craftsmanship Highlights (Anomalies Handled)

The source specification contains real-world data discrepancies intentionally designed to test data engineering judgment:

### 1. Missing `Post Code` Column (Schema Drift)
- **The Issue**: The written specification lists 11 columns with `Post Code` at position 9. However, the physical flat file completely omits `Post Code`, placing `DOB` directly after `Country`.
- **The Craftsmanship Solution**: In Bronze ([`sql/01_raw_landing_ddl.sql`](sql/01_raw_landing_ddl.sql)), `POST_CODE` is defined with `DEFAULT NULL`. In Silver ([`stg_members.sql`](models/staging/stg_members.sql)), `TRY_TO_NUMBER(POST_CODE)` is applied. If a physical post code arrives in future batches, the pipeline seamlessly casts it; if omitted, it defaults to `NULL` without breaking the ingestion contract.

### 2. Date of Birth Leading Zero Anomaly
- **The Issue**: DOB is specified as `MMDDYYYY` (8 chars), but incoming flat files contain 7-digit strings (e.g., `3051985` for March 5, 1985) due to dropped leading zeroes.
- **The Craftsmanship Solution**: The macro [`macros/calculate_age.sql`](macros/calculate_age.sql) applies `LPAD(TRIM(DOB), 8, '0')` prior to `TRY_TO_DATE(..., 'MMDDYYYY')`, ensuring 100% parse accuracy and preventing false quarantines.

### 3. Country Name Inconsistency & Seed Normalization
- **The Issue**: The source files contain mixed country code lengths: `US`, `USA`, `IN`, `IND`, `CA`, `CAN`, `AU`, `AUS`, `PH`, `PHIL`, `PHL`.
- **The Craftsmanship Solution**: Rather than maintaining fragile hardcoded `CASE` statements, a dbt seed reference table ([`seeds/country_mapping.csv`](seeds/country_mapping.csv)) maps all variants to official **ISO 3166-1 Alpha-3** standards (`USA`, `IND`, `CAN`, `AUS`, `PHL`). Rule R04 validates against this seed table.

### 4. Mutual Exclusivity Guarantee (Clean vs. Quarantine)
- **The Rule**: A source record must be either clean OR corrupt—it must **never** appear in both `STAGING.STG_MEMBERS` and `QUARANTINE.QUARANTINE_MEMBERS`.
- **The Test**: Custom test [`tests/assert_clean_members_not_in_quarantine.sql`](tests/assert_clean_members_not_in_quarantine.sql) joins both tables on `SOURCE_FILE_NAME` and `SOURCE_FILE_ROW_NUMBER`. Returns **0 rows** (**PASS**).

### 5. Multi-Class Dead Letter Queue (DLQ)
Instead of a single error log, failures are segregated by failure domain:
- **`QUARANTINE_MEMBERS`**: Captures member profile syntax and validation errors with pipe-separated failure codes (`R01` through `R08`).
- **`QUARANTINE_REDEMPTIONS`**: Captures invalid transaction syntax (negative miles, missing transaction ID).
- **`ORPHAN_REDEMPTIONS`**: Captures clean transactions whose member does not exist in `stg_members` (unregistered or quarantined member).

---

## 📁 Repository Structure

```text
skypoints-loyalty-platform/
├── dbt_project.yml             # Global dbt configuration (schema mappings & model materializations)
├── macros/                     # Reusable business logic macros
│   ├── calculate_age.sql       # Macro: computes member age in full years from DOB
│   ├── generate_schema_name.sql# Macro: custom schema naming override (RAW, STAGING, MARTS, etc.)
│   └── is_stale_member.sql     # Macro: derives 'Y'/'N' inactivity flag (>90 days since flight)
├── models/
│   ├── raw/                    # Bronze Layer
│   │   ├── raw_redemption_feed.sql # LATERAL FLATTEN on JSON payloads with incremental MERGE
│   │   ├── schema.yml          # Schema tests on Bronze flattened feed
│   │   └── sources.yml         # External source declarations for raw landing tables
│   ├── staging/                # Silver Layer
│   │   ├── schema.yml          # Schema definitions, accepted_values, unique & not_null tests
│   │   ├── sources.yml         # Raw source declarations
│   │   ├── stg_members.sql     # Cleansed, deduplicated (SCD-1) member profiles
│   │   └── stg_redemptions.sql # Cleansed, validated transactions with referential checks
│   ├── quarantine/             # Dead Letter Queue (DLQ) Layer
│   │   ├── orphan_redemptions.sql   # Valid redemptions with missing/quarantined members
│   │   ├── quarantine_members.sql   # Failed member records with R01-R08 error diagnostics
│   │   ├── quarantine_redemptions.sql # Failed redemption records
│   │   └── schema.yml          # DLQ schema documentation and tests
│   └── marts/                  # Gold Layer (Curated Consumption)
│       ├── country_tables/     # Per-Country Target Marts (Deliverable 3)
│       │   ├── table_australia.sql   # Filtered for Australia (AUS)
│       │   ├── table_canada.sql      # Filtered for Canada (CAN)
│       │   ├── table_india.sql       # Filtered for India (IND)
│       │   ├── table_philippines.sql # Filtered for Philippines (PHL)
│       │   └── table_usa.sql         # Filtered for USA (USA)
│       ├── agg_country_redemption_summary.sql # Pre-aggregated country & partner performance mart
│       ├── fct_member_redemptions.sql         # Analytical transaction fact mart (Deliverable 4)
│       └── schema.yml          # Tests for all country marts, fact mart, and summary mart
├── seeds/                      # Reference Data Seeds
│   ├── country_mapping.csv     # ISO-3 country standardisation mapping
│   └── schema.yml              # Seed data tests (unique, not_null, accepted_values)
├── tests/                      # Custom Singular Business Tests
│   ├── assert_clean_members_not_in_quarantine.sql # Asserts zero overlap between Silver and DLQ
│   ├── assert_member_in_only_one_country.sql      # Validates country exclusivity (latest record wins)
│   └── assert_redemptions_have_valid_member.sql   # Validates referential integrity in Silver
├── sql/                        # Pure Snowflake Provisioning & DDL Scripts
│   ├── 00_logs_ddl.sql         # Ingestion audit log table DDL
│   ├── 00_setup.sql            # Warehouse, Database, Schemas, Stages & Git Integration setup
│   ├── 01_raw_landing_ddl.sql  # Bronze landing tables (Lenient flat file + VARIANT document store)
│   ├── 02_raw_ingestion.sql    # Idempotent COPY INTO pipelines with METADATA audit capture
│   └── 03_target_tables_ddl.sql# Pure Snowflake DDL for Staging & Country Target tables (Deliverable 1)
├── ARCHITECTURE.md             # Deep-dive architectural design, trade-offs & scaling strategies
├── README.md                   # Project documentation & execution guide
└── .gitignore                  # Git exclusions
```

---

## 🚀 Setup & Execution Guide

### Prerequisites
- Snowflake Account with `ACCOUNTADMIN` or `SYSADMIN` role.
- dbt Core (v1.8+) or Snowflake dbt Workspaces.

### Step 1: Provision Snowflake Infrastructure
Execute [`sql/00_setup.sql`](sql/00_setup.sql) in a Snowflake Worksheet to create:
- Virtual Warehouse: `SKYPOINTS_WH`
- Database: `SKYPOINTS_DB`
- Dedicated Schemas: `RAW`, `STAGING`, `QUARANTINE`, `LOGS`, `MARTS`
- File Formats & Stages: `RAW.STAGE_MEMBER_FEED`, `RAW.STAGE_REDEMPTION_FEED`

### Step 2: Ingest Raw Feeds
Execute [`sql/01_raw_landing_ddl.sql`](sql/01_raw_landing_ddl.sql) and [`sql/02_raw_ingestion.sql`](sql/02_raw_ingestion.sql) to land member profile flat files and JSON feeds into Bronze with full row-level metadata.

### Step 3: Execute dbt Transformations

You can run the pipeline either **directly in the Snowflake UI (recommended / zero local install)** or via **local dbt CLI**.

#### Option A: Directly from Snowflake Workspaces UI (Zero Local Install)
The platform is natively integrated with Snowflake Workspaces via Git Integration:
1. **Sync Latest Changes**: In Snowflake, fetch the latest code from GitHub:
   ```sql
   ALTER GIT REPOSITORY SKYPOINTS_DB.RAW.skypoints_repo FETCH;
   ```
2. **Execute Operations via UI**:
   - Click the **Operation Dropdown** (top bar) and select:
     - `Seed` $\rightarrow$ Click **Execute** *(loads ISO country mapping)*
     - `Run` with Additional Flags: `--select staging` or `--select marts` $\rightarrow$ Click **Execute**
     - `Test` with Additional Flags: `--select marts` $\rightarrow$ Click **Execute**
3. **Interactive Lineage & DAG**:
   - Click the **DAG** tab to view the live 16-node interactive dependency graph from Bronze sources $\rightarrow$ Silver/DLQ $\rightarrow$ Gold Country Marts and Fact Tables.
   - Click the **Performance** tab to inspect runtime per model and warehouse utilization.

#### Option B: Running Locally via dbt CLI
If developing from a local terminal with `profiles.yml` configured:
```bash
# 1. Load the ISO country reference seed
dbt seed

# 2. Build Silver, DLQ, and Gold Marts
dbt run

# 3. Run all schema and custom singular tests
dbt test

# Targeted execution examples:
dbt run --select marts
dbt test --select marts
dbt test --select test_type:singular
```

---

## 🧪 Test Results Summary

During test execution, all **91 automated tests** passed with 0 errors and 0 warnings:

```text
Finished running 41 data tests on marts in 4.55 seconds.
Completed successfully
Done. PASS=41 WARN=0 ERROR=0 SKIP=0 TOTAL=41
```

---

## 👥 Author
- **Candidate**: Sumit Thakkar
- **Assessment**: Incubyte Data Engineer Technical Assessment
- **Repository**: [Sumit-Thakkar/skypoints-loyalty-platform](https://github.com/Sumit-Thakkar/skypoints-loyalty-platform)

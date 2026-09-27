# ✈️ SkyPoints Airline Loyalty Data Platform
*Incubyte Data Craftsmanship Technical Assessment*

## Overview
SkyPoints is a global airline loyalty program where members earn status and redeem miles across international partner airlines. This repository implements a high-throughput, production-grade ELT data platform on **Snowflake** and **dbt** using the **Medallion Architecture (Bronze → Silver → Gold)**.

## Core Capabilities
- **Bronze (Raw Landing):** Resilient ingestion of daily member profile feeds (flat files) and partner airline redemption feeds (semi-structured JSON).
- **Silver (Cleansed & Enriched):** Data sanitization, date normalization, derived attributes (`Age`, `Stale_Member` inactivity flag), and JSON array flattening (`LATERAL FLATTEN`).
- **Gold (Curated Marts):** Segregated per-country target tables (`Table_India`, `Table_USA`, etc.) enforcing the **"latest record wins"** rule for members relocating across countries, alongside an analytical redemption fact mart.
- **Data Craftsmanship & Quality:** Automated data testing via dbt schema tests, uniqueness verification, and a Dead Letter Queue (DLQ / Quarantine) pattern for malformed records.

## Project Structure (In Progress)
```text
skypoints-loyalty-platform/
├── dbt_project.yml             # Root dbt configuration
├── macros/                     # Reusable Jinja macros
├── models/
│   ├── staging/                # Silver layer: cleansing & derived columns
│   └── marts/                  # Gold layer: country tables & analytical facts
├── tests/                      # Data quality & exclusivity tests
├── sql/                        # Snowflake environment setup & raw DDLs
├── README.md
└── .gitignore
```

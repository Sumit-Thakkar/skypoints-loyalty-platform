-- models/raw/raw_redemption_feed.sql
-- -------------------------------------------------------
-- PURPOSE:
--   Flatten RAW.RAW_REDEMPTION_FEED_HIST (one VARIANT row
--   per JSON batch) into RAW.RAW_REDEMPTION_FEED
--   (one row per transaction).
--
-- LAYER: RAW (Bronze) — writes to the RAW schema.
--   No type enforcement or cleansing applied here;
--   all values remain VARCHAR (lenient Bronze pattern).
--
-- SOURCE JSON STRUCTURE (per assessment + data generator):
--   {
--     "member_id": "223457",
--     "feed_date": "20240115",
--     "redemptions": [
--       { "txn_id": "RX10091", "txn_date": "20240110",
--         "partner": "AeroLink", "miles_redeemed": 12000,
--         "status": "COMPLETED" }
--     ]
--   }
--
-- MERGE STRATEGY:
--   unique_key = TXN_ID (transaction identifier).
--   - New TXN_ID         → INSERT
--   - Same TXN_ID, field changed → UPDATE
--   - Same TXN_ID, unchanged    → skip (Snowflake MERGE handles this)
--
-- NOTE: No additional is_incremental() file-level filter needed.
--   The MERGE on TXN_ID is already idempotent. Re-processing
--   the same file simply results in no-op updates for unchanged rows.
-- -------------------------------------------------------

{{ config(
    materialized         = 'incremental',
    unique_key           = 'TXN_ID',
    schema               = 'RAW',
    incremental_strategy = 'merge',
    on_schema_change     = 'sync_all_columns'
) }}

WITH flattened AS (

    SELECT
        -- Transaction identifier (merge key)
        f.value:txn_id::VARCHAR                     AS TXN_ID,

        -- Member reference (from parent JSON object)
        src.RAW_PAYLOAD:member_id::VARCHAR           AS MEMBER_ID,

        -- Feed-level date (from parent JSON object)
        src.RAW_PAYLOAD:feed_date::VARCHAR           AS FEED_DATE,

        -- Transaction-level fields — all VARCHAR (lenient Bronze)
        f.value:txn_date::VARCHAR                   AS TXN_DATE,
        f.value:partner::VARCHAR                    AS PARTNER,
        f.value:miles_redeemed::VARCHAR             AS MILES_REDEEMED,
        f.value:status::VARCHAR                     AS STATUS,

        -- Audit columns
        src.INGESTION_TIMESTAMP                     AS INGESTION_TIMESTAMP,
        src.SOURCE_FILE_NAME                        AS SOURCE_FILE_NAME

    FROM {{ source('raw', 'raw_redemption_feed_hist') }} AS src,
         LATERAL FLATTEN(input => src.RAW_PAYLOAD:redemptions) AS f

)

SELECT * FROM flattened

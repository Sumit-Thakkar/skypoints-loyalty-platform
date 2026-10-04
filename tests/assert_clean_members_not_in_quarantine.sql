-- tests/assert_clean_members_not_in_quarantine.sql
-- ----------------------------------------------------------------------------
-- TEST 2: CLEAN VS. QUARANTINE OVERLAP CHECK
-- PURPOSE:
--   Asserts that STAGING.STG_MEMBERS and QUARANTINE.QUARANTINE_MEMBERS have
--   zero overlap.
--
-- BUSINESS RULE:
--   A raw feed row is either clean OR corrupt — it must NEVER appear in both
--   the clean table and the quarantine table simultaneously.
--
-- SUCCESS CRITERIA:
--   Returns 0 rows. Any rows returned indicate a routing logic defect where a
--   single source file line landed in both tables.
-- ----------------------------------------------------------------------------

SELECT 
    m.SOURCE_FILE_NAME,
    m.SOURCE_FILE_ROW_NUMBER,
    m.MEMBER_ID,
    q.QUARANTINE_REASON
FROM {{ ref('stg_members') }} AS m
INNER JOIN {{ ref('quarantine_members') }} AS q
    ON m.SOURCE_FILE_NAME = q.SOURCE_FILE_NAME
   AND m.SOURCE_FILE_ROW_NUMBER = q.SOURCE_FILE_ROW_NUMBER

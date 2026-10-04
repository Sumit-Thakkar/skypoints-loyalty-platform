-- tests/assert_redemptions_have_valid_member.sql
-- ----------------------------------------------------------------------------
-- TEST 1: REFERENTIAL INTEGRITY CHECK
-- PURPOSE:
--   Asserts that every transaction in STAGING.STG_REDEMPTIONS maps to an
--   existing, verified member in STAGING.STG_MEMBERS.
--
-- BUSINESS RULE:
--   Orphan transactions (unmatched or quarantined members) must be filtered
--   into QUARANTINE.ORPHAN_REDEMPTIONS and must NEVER appear in clean Silver.
--
-- SUCCESS CRITERIA:
--   Returns 0 rows. Any rows returned indicate a referential integrity breach.
-- ----------------------------------------------------------------------------

SELECT 
    r.TXN_ID,
    r.MEMBER_ID,
    r.TXN_DATE,
    r.MILES_REDEEMED,
    r.PARTNER
FROM {{ ref('stg_redemptions') }} AS r
LEFT JOIN {{ ref('stg_members') }} AS m
    ON r.MEMBER_ID = m.MEMBER_ID
WHERE m.MEMBER_ID IS NULL

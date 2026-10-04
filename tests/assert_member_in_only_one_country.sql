-- tests/assert_member_in_only_one_country.sql
-- ----------------------------------------------------------------------------
-- TEST 3: COUNTRY EXCLUSIVITY & "LATEST RECORD WINS" VALIDATION
-- PURPOSE:
--   Asserts that a member exists in at most ONE country mart table.
--   Enforces Deliverable 3: when a member moves countries, the latest record
--   wins and the member must never appear across multiple country marts.
--
-- SUCCESS CRITERIA:
--   Returns 0 rows. Any rows returned indicate a duplicate member across countries.
-- ----------------------------------------------------------------------------

WITH combined AS (

    SELECT MEMBER_ID, 'INDIA' AS COUNTRY_MART FROM {{ ref('table_india') }}
    UNION ALL
    SELECT MEMBER_ID, 'USA' AS COUNTRY_MART FROM {{ ref('table_usa') }}
    UNION ALL
    SELECT MEMBER_ID, 'CANADA' AS COUNTRY_MART FROM {{ ref('table_canada') }}
    UNION ALL
    SELECT MEMBER_ID, 'AUSTRALIA' AS COUNTRY_MART FROM {{ ref('table_australia') }}
    UNION ALL
    SELECT MEMBER_ID, 'PHILIPPINES' AS COUNTRY_MART FROM {{ ref('table_philippines') }}

)

SELECT
    MEMBER_ID,
    COUNT(*) AS COUNTRY_OCCURRENCE_COUNT
FROM combined
GROUP BY MEMBER_ID
HAVING COUNT(*) > 1

-- macros/is_stale_member.sql
-- -------------------------------------------------------
-- Returns 'Y' if the member has had no flight activity
-- for more than 90 days, 'N' otherwise.
--
-- LAST_FLIGHT_DATE lands as VARCHAR in Bronze.
-- Source format: YYYYMMDD (e.g. '20121013').
-- No LPAD needed — always 8 digits.
--
-- Returns NULL if LAST_FLIGHT_DATE cannot be parsed.
-- -------------------------------------------------------
{% macro is_stale_member(last_flight_date_column) %}
    CASE
        WHEN TRY_TO_DATE(TRIM({{ last_flight_date_column }}), 'YYYYMMDD') IS NULL
            THEN NULL
        WHEN DATEDIFF(
                 'day',
                 TRY_TO_DATE(TRIM({{ last_flight_date_column }}), 'YYYYMMDD'),
                 CURRENT_DATE()
             ) > 90
            THEN 'Y'
        ELSE 'N'
    END
{% endmacro %}

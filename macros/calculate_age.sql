-- macros/calculate_age.sql
-- -------------------------------------------------------
-- Calculates a member's age in years from a raw DOB string.
--
-- The Bronze layer stores DOB as VARCHAR (e.g. '3051985'
-- with a missing leading zero, or '03051985').
-- We LPAD to 8 chars then parse with MMDDYYYY format.
--
-- Returns NULL if DOB is NULL, empty, or unparseable.
-- -------------------------------------------------------
{% macro calculate_age(dob_column) %}
    DATEDIFF(
        'year',
        TRY_TO_DATE(LPAD(TRIM({{ dob_column }}), 8, '0'), 'MMDDYYYY'),
        CURRENT_DATE()
    )
{% endmacro %}

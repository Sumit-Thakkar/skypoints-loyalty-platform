-- macros/generate_schema_name.sql
-- -------------------------------------------------------
-- Overrides dbt's default schema naming behaviour.
--
-- By default dbt appends the target.schema prefix to every
-- custom schema, producing names like:
--   <target_schema>_STAGING  →  SUMIT_STAGING  (wrong)
--
-- This override makes models write to the *exact* schema
-- declared in dbt_project.yml (STAGING, MARTS, RAW), which
-- is what enterprise Snowflake projects expect.
-- -------------------------------------------------------
{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}

    {%- if custom_schema_name is none -%}
        {{ default_schema }}

    {%- else -%}
        {# Use the custom schema name exactly as declared — no prefix #}
        {{ custom_schema_name | upper | trim }}

    {%- endif -%}

{%- endmacro %}

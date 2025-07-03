{# --- Macro created 20250703 Paul Burden --- #}

{% macro generate_source_yaml_with_variant_recursive(
    source_schema,
    source_table,
    sample_size=100,
    max_depth=3,
    source_database=None
) %}
{%- set source_database = source_database or target.database %}
{%- set relation = adapter.get_relation(
    database=source_database,
    schema=source_schema,
    identifier=source_table
) -%}

{%- if relation is none %}
  {{ exceptions.raise_compiler_error("Table " ~ source_database ~ "." ~ source_schema ~ "." ~ source_table ~ " not found.") }}
{%- endif %}

{%- set columns = adapter.get_columns_in_relation(relation) -%}
{%- set date_generated = modules.datetime.datetime.now().strftime("%Y-%m-%d") %}
{%- set type_map = {
    'CHARACTER VARYING': 'VARCHAR',
    'CHAR VARYING': 'VARCHAR',
    'TEXT': 'VARCHAR',
    'DOUBLE PRECISION': 'FLOAT',
    'DEC': 'DECIMAL',
    'NUMERIC': 'DECIMAL'
} %}

{# --- YAML content builder --- #}
{%- set yaml_lines = [] %}
{%- do yaml_lines.append("# --------------------------------------------------------------------") %}
{%- do yaml_lines.append("# Auto-generated source YAML") %}
{%- do yaml_lines.append("# date_generated: " ~ date_generated) %}
{%- do yaml_lines.append("# generated_by: generate_source_yaml_with_variant_recursive") %}
{%- do yaml_lines.append("# source: " ~ source_database ~ "." ~ source_schema ~ "." ~ source_table) %}
{%- do yaml_lines.append("# sample_size: " ~ sample_size) %}
{%- do yaml_lines.append("# max_depth: " ~ max_depth) %}
{%- do yaml_lines.append("# --------------------------------------------------------------------") %}
{%- do yaml_lines.append("version: 2") %}
{%- do yaml_lines.append("sources:") %}
{%- do yaml_lines.append("  - name: " ~ source_schema | upper) %}
{%- do yaml_lines.append("    database: " ~ source_database | upper) %}
{%- do yaml_lines.append("    tables:") %}
{%- do yaml_lines.append("      - name: " ~ source_table | upper) %}
{%- do yaml_lines.append("        description: \"\"") %}
{%- do yaml_lines.append("        columns:") %}

{%- for col in columns %}
{%- set raw_type = col.data_type.upper().split('(')[0] | trim %}
{%- set dtype = type_map.get(raw_type, raw_type) %}
{%- do yaml_lines.append("          - name: " ~ col.name | upper) %}
{%- do yaml_lines.append("            description: \"\"") %}
{%- do yaml_lines.append("            meta:") %}
{%- do yaml_lines.append("              data_type: " ~ dtype) %}
{%- do yaml_lines.append("              is_data_column: Y") %}
{%- endfor %}

{# --- Recursive flattening of VARIANT columns --- #}
{%- for col in columns if col.data_type.upper() == 'VARIANT' %}
{%- set base_query %}
    WITH sample AS (
        SELECT {{ col.name }} AS variant_data
        FROM {{ relation }}
        WHERE IS_OBJECT({{ col.name }})
        LIMIT {{ sample_size }}
    ),
    recursive_keys AS (
        SELECT
            '' AS path,
            variant_data,
            OBJECT_KEYS(variant_data) AS key_name,
            variant_data:key_name AS value,
            1 AS depth
        FROM sample
        WHERE IS_OBJECT(variant_data)

        UNION ALL

        SELECT
            rk.path || CASE WHEN rk.path = '' THEN '' ELSE '.' END || rk.key_name,
            rk.value,
            OBJECT_KEYS(rk.value) AS key_name,
            rk.value:key_name AS value,
            rk.depth + 1
        FROM recursive_keys rk
        WHERE IS_OBJECT(rk.value)
          AND rk.depth < {{ max_depth }}
    )
    SELECT DISTINCT
        '{{ col.name }}:' || path || CASE WHEN path = '' THEN '' ELSE '.' END || key_name AS full_key
    FROM recursive_keys
{%- endset %}

{%- set flat_keys = run_query(base_query) %}
{%- if execute and flat_keys %}
{%- set keys = flat_keys.columns[0].values() %}
{%- for key in keys %}
{%- do yaml_lines.append("          - name: " ~ key) %}
{%- do yaml_lines.append("            description: \"Extracted nested JSON key '" ~ key.split(':', 1)[1] ~ "' from " ~ col.name ~ "\"") %}
{%- do yaml_lines.append("            meta:") %}
{%- do yaml_lines.append("              data_type: " ~ col.data_type.upper()) %}
{%- do yaml_lines.append("              is_data_column: Y") %}
{%- endfor %}
{%- endif %}
{%- endfor %}

{# --- Standard columns --- #}
{%- do yaml_lines.append("          - name: SYSTEM_ADF_LOADDATE") %}
{%- do yaml_lines.append("            description: \"Date file was landed by ADF\"") %}
{%- do yaml_lines.append("            meta:") %}
{%- do yaml_lines.append("              data_type: DATE") %}
{%- do yaml_lines.append("              is_system_column: Y") %}

{%- do yaml_lines.append("          - name: SYSTEM_SF_LOADDATE") %}
{%- do yaml_lines.append("            description: \"Date Time file loaded into Snowflake\"") %}
{%- do yaml_lines.append("            meta:") %}
{%- do yaml_lines.append("              data_type: TIMESTAMP_LTZ") %}
{%- do yaml_lines.append("              is_system_column: Y") %}

{%- do yaml_lines.append("          - name: SYSTEM_ADF_FILENAME") %}
{%- do yaml_lines.append("            description: \"Source filename the data was loaded from\"") %}
{%- do yaml_lines.append("            meta:") %}
{%- do yaml_lines.append("              data_type: VARCHAR(50)") %}
{%- do yaml_lines.append("              is_system_column: Y") %}

{%- do yaml_lines.append("          - name: SYSTEM_CREATE_DATE") %}
{%- do yaml_lines.append("            description: \"Timestamp when the record was first created\"") %}
{%- do yaml_lines.append("            meta:") %}
{%- do yaml_lines.append("              data_type: TIMESTAMP_LTZ") %}
{%- do yaml_lines.append("              is_system_column: Y") %}

{%- do yaml_lines.append("          - name: SYSTEM_UPDATE_DATE") %}
{%- do yaml_lines.append("            description: \"Timestamp when the record was last updated\"") %}
{%- do yaml_lines.append("            meta:") %}
{%- do yaml_lines.append("              data_type: TIMESTAMP_LTZ") %}
{%- do yaml_lines.append("              is_system_column: Y") %}

{# --- list standard metadata --- #}
{%- do yaml_lines.append("# ") %}
{%- do yaml_lines.append("# --- example list of standard metadata --- #") %}
{%- do yaml_lines.append("#            meta:") %}
{%- do yaml_lines.append("#              data_type: VARCHAR") %}
{%- do yaml_lines.append("#              is_key_column: Y") %}
{%- do yaml_lines.append("#              key_order: 1") %}
{%- do yaml_lines.append("#              is_rowhash_column: Y") %}
{%- do yaml_lines.append("#              rowhash_order: 1") %}
{%- do yaml_lines.append("#              is_data_column: Y") %}
{%- do yaml_lines.append("#              is_system_column: Y") %}
{%- do yaml_lines.append("#              column_alias: ") %}
{%- do yaml_lines.append("#              column_transform: \"\"") %}
{%- do yaml_lines.append("# ") %}


{%- set yaml_output = yaml_lines | join('\n') %}

{# --- Output YAML to terminal --- #}
{{ log(yaml_output, info=True) }}

{# --- Return the full string (for use in external scripts) --- #}
{{ return(yaml_output) }}
{% endmacro %}

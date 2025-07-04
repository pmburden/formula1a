{% macro generate_model_sql_from_yaml(yaml_path, prefix='stg_', include_source=True) %}

{%- set yaml_data = load_yaml(yaml_path) %}
{% if not yaml_data %}
  {{ exceptions.raise_compiler_error("YAML file not found or invalid at path: " ~ yaml_path) }}
{% endif %}

{%- set output_models = [] %}

{%- for source in yaml_data.get('sources', []) %}
  {%- set source_name = source['name'] %}
  {%- for table in source.get('tables', []) %}
    {%- set table_name = table['name'] %}
    {%- set columns = table.get('columns', []) %}
    {%- set model_name = prefix ~ source_name ~ '__' ~ table_name %}

    {%- set sql_lines = [] %}
    {%- set regular_cols = [] %}
    {%- set system_cols = [] %}
    {%- set key_cols = [] %}
    {%- set rowhash_cols = [] %}

    {# Loop through columns and collect info #}
    {%- for col in columns %}
      {%- set name = col['name'] %}
      {%- set meta = col.get('meta', {}) %}
      {%- set is_system = meta.get('is_system_column', 'N') == 'Y' %}
      {%- set transform = meta.get('column_transform') %}
      {%- set data_type = meta.get('data_type') %}
      {%- set alias = meta.get('column_alias') %}
      {%- set comment = meta.get('comment') %}
      {%- set is_key = meta.get('is_key_column', False) %}
      {%- set key_order = meta.get('key_order', 0) %}
      {%- set is_rowhash = meta.get('is_rowhash_column', False) %}
      {%- set rowhash_order = meta.get('rowhash_order', 0) %}

      {# Special timestamp logic #}
      {%- if name in ['SYSTEM_CREATE_DATE', 'SYSTEM_UPDATE_DATE'] %}
        {%- set expr = "CURRENT_TIMESTAMP()" %}
      {%- elif transform %}
        {%- set expr = transform %}
      {%- else %}
        {%- set expr = name %}
        {%- if data_type %}
          {%- set expr = "cast(" ~ expr ~ " as " ~ data_type ~ ")" %}
        {%- endif %}
      {%- endif %}

      {%- if alias %}
        {%- set expr = expr ~ " as " ~ alias %}
      {%- endif %}

      {%- set line = "    " ~ expr ~ "," %}
      {%- if comment %}
        {%- set line = line ~ " -- " ~ comment %}
      {%- endif %}

      {%- if is_system %}
        {%- do system_cols.append(line) %}
      {%- else %}
        {%- do regular_cols.append(line) %}
      {%- endif %}

      {# Track keys and rowhash inputs #}
      {%- if is_key %}
        {%- do key_cols.append({'name': alias or name, 'order': key_order}) %}
      {%- endif %}
      {%- if is_rowhash %}
        {%- do rowhash_cols.append({'name': alias or name, 'order': rowhash_order}) %}
      {%- endif %}
    {%- endfor %}

    {# Sort key and rowhash columns and generate surrogate expressions #}
    {%- set col_exprs = [] %}
    {%- set sorted_keys = key_cols | sort(attribute='order') %}
    {%- set key_names = sorted_keys | map(attribute='name') | list %}
    {%- if key_names %}
      {%- set key_expr = "    dbt_utils.generate_surrogate_key([" ~ key_names | join(", ") ~ "]) as table_key," %}
      {%- do col_exprs.append(key_expr) %}
    {%- endif %}

    {%- set sorted_hashes = rowhash_cols | sort(attribute='order') %}
    {%- set hash_names = sorted_hashes | map(attribute='name') | list %}
    {%- if hash_names %}
      {%- set hash_expr = "    dbt_utils.generate_surrogate_key([" ~ hash_names | join(", ") ~ "]) as system_rowhash," %}
      {%- do col_exprs.append(hash_expr) %}
    {%- endif %}

    {%- do col_exprs.extend(regular_cols) %}
    {%- do col_exprs.extend(system_cols) %}

    {# Final SQL assembly #}
    {%- do sql_lines.append("-- Auto-generated model for " ~ source_name ~ "." ~ table_name) %}
    {%- do sql_lines.append("select") %}
    {%- for line in col_exprs %}
      {%- do sql_lines.append(line) %}
    {%- endfor %}
    {# Clean last comma #}
    {%- set sql_lines = sql_lines[:-1] + [sql_lines[-1].rstrip(',')] %}

    {%- if include_source %}
      {%- do sql_lines.append("from {{ source('" ~ source_name ~ "', '" ~ table_name ~ "') }}") %}
    {%- else %}
      {%- do sql_lines.append("from " ~ source_name ~ "." ~ table_name) %}
    {%- endif %}

    {%- set full_sql = sql_lines | join('\n') %}
    {{ log("--------- " ~ model_name ~ " ---------", info=True) }}
    {{ log(full_sql, info=True) }}
    {%- do output_models.append(model_name ~ ":\n" ~ full_sql) %}
  {%- endfor %}
{%- endfor %}

{{ return(output_models | join('\n\n')) }}
{% endmacro %}


generate_model_sql_from_yaml('models/generated/generated_circuits.yml')

{% set raw_yaml = load_file('models/generated/generated_circuits.yml') %}
{% set yaml_data = fromyaml(raw_yaml) %}


{%- set columns_yml = model.columns.values() -%} {# read model.yml #}
{%- for col in columns_yml -%}
  "_CREATED_AT"
{%- endfor -%}

xyz

        {%- for col in columns_yml -%}
      
            "{{col.name}}"

        {%- endfor -%}


abc



{# In a macro #}
{% macro generate_select_statement(model_name) %}
  SELECT
    {% for column in model.columns.values() -%}
      {{ column.name }}
      {%- if not loop.last %},{% endif %}
    {%- endfor %}
  FROM {{ ref(model_name) }}
{% endmacro %}

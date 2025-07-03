{% macro test_load_yaml() %}
  {% set data = load_yaml('models/core/dim_circuits.yml') %}
  {{ log(data, info=True) }}
  {{ return(data) }}
{% endmacro %}
{% macro test_load_yaml() %}
  {% set data = load_yaml('models/generated/generated_circuits.yml.yml') %}
  {{ log(data, info=True) }}
  {{ return(data) }}
{% endmacro %}
{% macro get_tables_in_schema(schema_name, database_name=target.database, table_pattern='%', exclude='') %}
{# usage:
    dbt run-operation generate_model_yaml --args '{"database_name": "DEV_LANDING_JUN", "schema_name": "ASCENDER","table_names":["NZP_LOCATION", "POSITION_TYPE"]}'
    or 
    complie selection: 

    for migrate or mixed case in column name:
    {{generate_model_yaml(schema_name='ods_agresso', database_name='kea_landing', table_names=["afxdfa_approval"], case_sensitive_cols=True)}}
 
    for new object or all upper cases in column name:
    {{generate_model_yaml(schema_name='CYBERSYN', database_name='SHARE_FINANCE__ECONOMICS', table_names=["COMPANY_INDEX"])}} 

SHARE_FINANCE__ECONOMICS
CYBERSYN
COMPANY_INDEX

#}
    {% set tables=dbt_utils.get_relations_by_pattern(
        schema_pattern=schema_name,
        database=database_name,
        table_pattern=table_pattern,
        exclude=exclude
    ) %}

    {% set table_list= tables | map(attribute='identifier') %}

    {{ return(table_list | sort) }}

{% endmacro %}

{% macro generate_model_yaml2(schema_name, database_name=target.database, generate_columns=True, include_descriptions=True, include_data_types=True, table_pattern='%', exclude='', name=schema_name, table_names=None, include_database=False, include_schema=False, case_sensitive_databases=False, case_sensitive_schemas=False, case_sensitive_tables=False, case_sensitive_cols=False) %}
    {{ return(adapter.dispatch('generate_model_yaml', 'codegen')(schema_name, database_name, generate_columns, include_descriptions, include_data_types, table_pattern, exclude, name, table_names, include_database, include_schema, case_sensitive_databases, case_sensitive_schemas, case_sensitive_tables, case_sensitive_cols)) }}
{% endmacro %}

{% macro default__generate_model_yaml(schema_name, database_name, generate_columns, include_descriptions, include_data_types, table_pattern, exclude, name, table_names, include_database, include_schema, case_sensitive_databases, case_sensitive_schemas, case_sensitive_tables, case_sensitive_cols) %}

{% set sources_yaml=[] %}
{% do sources_yaml.append('version: 2') %}
{% do sources_yaml.append('') %}
{% do sources_yaml.append('models:') %}

{% if table_names is none %}
{% set tables=codegen.get_tables_in_schema(schema_name, database_name, table_pattern, exclude) %}
{% else %}
{% set tables = table_names %}
{% endif %}

{% for table in tables %}
    {% do sources_yaml.append('    - name: ' ~ (table if case_sensitive_tables else table | lower) ) %}
    {% if include_descriptions %}
        {% do sources_yaml.append('      description: ""' ) %}
    {% endif %}
    {% if generate_columns %}
    {% do sources_yaml.append('      columns:') %}

        {% set table_relation=api.Relation.create(
            database=database_name,
            schema=schema_name,
            identifier=table
        ) %}
        {%- if 'S3RAW' in determine_source(database_name|upper|replace('REFINED','RAW'), schema_name|upper, table|upper) -%}
            {% set data_column = '_data' %}        
        {%- elif 'PIPE' in determine_source(database_name|upper|replace('REFINED','RAW'), schema_name|upper, table|upper) -%}
            {% set data_column = 'record_content' %}
        {% endif %}    
        {% set columns=adapter.get_columns_in_relation(table_relation) %}

        {% for column in columns %}
            {% do sources_yaml.append('        - name: ' ~ (column.name if case_sensitive_cols else column.name | lower)) %}
            {% if include_descriptions %}
                {% do sources_yaml.append('          description: ""' ) %}            
            {% if include_data_types %}
                {% do sources_yaml.append('          meta:' ) %}
                {% do sources_yaml.append('            data_type: ' ~ codegen.data_type_format_source(column)) %}
                {% if column.name in system_column_list()[26:] %}
                    {% do sources_yaml.append('            source_column_name: RECORD_METADATA:"' ~ (column.name) ~ '"') %} 
                {% endif %}                      
                {% if column.name not in system_column_list() %}
                    {% do sources_yaml.append('            is_data_column: yes' ) %}
                    {% if data_column == '_data' %}
                        {% do sources_yaml.append('            source_column_name: _DATA:"' ~ (column.name) ~ '"') %}
                    {% elif data_column == 'record_content' %}
                        {% do sources_yaml.append('            source_column_name: RECORD_CONTENT:"' ~ (column.name) ~ '"') %}                     
                    {% endif %}  
                    {% do sources_yaml.append('            transformation: ""' ) %}                         
                {% endif %}
                {% if case_sensitive_cols %}
                {% do sources_yaml.append('            case_sensitive: yes' ) %}    
                {% endif %}            
            {% endif %}

    
            {% endif %}
        {% endfor %}
            {% do sources_yaml.append('') %}

    {% endif %}

{% endfor %}

{% if execute %}

    {% set joined = sources_yaml | join ('\n') %}
    {{ print(joined) }}
    {% do return(joined) %}

{% endif %}

{% endmacro %}
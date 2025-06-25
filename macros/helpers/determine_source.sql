{%- macro determine_source(source_database_name, schema_name, table_name) -%}
    {%- set s3raw_pipe_landing = 'LANDING' -%}
    {%- set _source_database_name = source_database_name -%}
    {%- set _schema_name = schema_name -%}
    {%- set _table_name = table_name -%}
    {%- if 'LANDING' in _source_database_name|upper -%}
        {% do return(s3raw_pipe_landing) %}
    {%- else -%}
        {%- call statement('determine_raw_column', fetch_result=True) -%}
            select 1 
            where exists (
                select * from {{_source_database_name}}.information_schema.columns 
                where upper(table_name) = '{{_table_name}}' 
                and  upper(table_schema) = '{{_schema_name}}' 
                and upper(column_name) = 'RECORD_CONTENT'
            );
        {%- endcall -%}
        {%- set condition_data_column = load_result("determine_raw_column")["data"] -%}
        {%- if 1 in condition_data_column| first -%}
            {%- set s3raw_pipe_landing = 'PIPE' -%}
            {% do return(s3raw_pipe_landing) %}
        {%- else -%}
            {%- call statement('determine_DATA', fetch_result=True) -%}
                select 1 
                where exists (
                    select * from {{_source_database_name}}.information_schema.columns 
                    where upper(table_name) = '{{_table_name}}' 
                    and  upper(table_schema) = '{{_schema_name}}' 
                    and upper(column_name) = '_DATA'
                );
            {%- endcall -%}    
            {%- set condition_data_column = load_result("determine_DATA")["data"] -%}      
            {%- if 1 in condition_data_column| first -%}                     
                {%- set s3raw_pipe_landing = 'S3RAW' -%}
                {% do return(s3raw_pipe_landing) %}
            {%- else -%}
                {%- set s3raw_pipe_landing = 'NONE' -%}
                {% do return(s3raw_pipe_landing) %}     
            {%- endif -%}               
        {%- endif -%}
    {%- endif -%}        
  
{%- endmacro -%} 
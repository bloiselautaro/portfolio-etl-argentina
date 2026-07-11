{{ config(materialized='view') }}

select *
from {{ ref('fct_dolar') }}
qualify row_number() over (partition by tipo_dolar order by fecha desc) = 1
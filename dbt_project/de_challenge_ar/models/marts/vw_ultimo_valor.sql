{{ config(materialized='view') }}

select 'riesgo_pais' as indicador, fecha, cast(riesgo_pais as float64) as valor
from {{ ref('fct_riesgo_pais') }}
qualify row_number() over (order by fecha desc) = 1

union all

select 'brecha_cambiaria_pct', fecha, brecha_cambiaria_pct
from {{ ref('mart_brecha_cambiaria') }}
qualify row_number() over (order by fecha desc) = 1

union all

select 'inflacion_mensual_pct', fecha, inflacion_mensual_pct
from {{ ref('fct_inflacion') }}
qualify row_number() over (order by fecha desc) = 1

union all

select 'reservas_millones_usd', fecha, reservas_millones_usd
from {{ ref('fct_reservas_bcra') }}
qualify row_number() over (order by fecha desc) = 1

union all

select 'tasa_politica_monetaria_pct', fecha, tasa_politica_monetaria_pct
from {{ ref('fct_tasa_politica_monetaria') }}
qualify row_number() over (order by fecha desc) = 1

union all

select concat('dolar_', tipo_dolar) as indicador, fecha, precio_venta as valor
from {{ ref('stg_dolar') }}
qualify row_number() over (partition by tipo_dolar order by fecha desc) = 1
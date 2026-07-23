{{ config(materialized='view') }}

with ultimo_dolar as (

    select
        tipo_dolar,
        fecha,
        precio_venta,
        variacion_desde_ultimo_cambio_pct
    from {{ ref('fct_dolar') }}
    qualify row_number() over (partition by tipo_dolar order by fecha desc) = 1

)

select 'riesgo_pais' as indicador, fecha, cast(riesgo_pais as float64) as valor
from {{ ref('fct_riesgo_pais') }}
qualify row_number() over (order by fecha desc) = 1

union all

select 'inflacion_mensual_pct', fecha, inflacion_mensual_pct
from {{ ref('fct_inflacion') }}
qualify row_number() over (order by fecha desc) = 1

union all

select 'inflacion_acumulada_12m_pct', fecha, inflacion_acumulada_12m_pct
from {{ ref('fct_inflacion') }}
qualify row_number() over (order by fecha desc) = 1

union all

select 'reservas_millones_usd', fecha, reservas_millones_usd
from {{ ref('fct_reservas_bcra') }}
qualify row_number() over (order by fecha desc) = 1

union all

select 'reservas_variacion_pct', fecha, variacion_desde_ultimo_cambio_pct
from {{ ref('fct_reservas_bcra') }}
qualify row_number() over (order by fecha desc) = 1

union all

select 'dolar_oficial_precio', fecha, precio_venta
from ultimo_dolar where tipo_dolar = 'oficial'

union all

select 'dolar_oficial_variacion_pct', fecha, variacion_desde_ultimo_cambio_pct
from ultimo_dolar where tipo_dolar = 'oficial'

union all

select 'dolar_blue_precio', fecha, precio_venta
from ultimo_dolar where tipo_dolar = 'blue'

union all

select 'dolar_blue_variacion_pct', fecha, variacion_desde_ultimo_cambio_pct
from ultimo_dolar where tipo_dolar = 'blue'

union all

select 'dolar_ccl_precio', fecha, precio_venta
from ultimo_dolar where tipo_dolar = 'contadoconliqui'

union all

select 'dolar_ccl_variacion_pct', fecha, variacion_desde_ultimo_cambio_pct
from ultimo_dolar where tipo_dolar = 'contadoconliqui'

union all

select 'dolar_mep_precio', fecha, precio_venta
from ultimo_dolar where tipo_dolar = 'bolsa'

union all

select 'dolar_mep_variacion_pct', fecha, variacion_desde_ultimo_cambio_pct
from ultimo_dolar where tipo_dolar = 'bolsa'

union all

select 'dolar_mayorista_precio', fecha, precio_venta
from ultimo_dolar where tipo_dolar = 'mayorista'

union all

select 'dolar_mayorista_variacion_pct', fecha, variacion_desde_ultimo_cambio_pct
from ultimo_dolar where tipo_dolar = 'mayorista'
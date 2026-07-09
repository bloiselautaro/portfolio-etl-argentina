with oficial as (
    select fecha, precio_venta as dolar_oficial
    from {{ ref('stg_dolar') }}
    where tipo_dolar = 'oficial'
),
blue as (
    select fecha, precio_venta as dolar_blue
    from {{ ref('stg_dolar') }}
    where tipo_dolar = 'blue'
)
select
    oficial.fecha,
    oficial.dolar_oficial,
    blue.dolar_blue,
    round(safe_divide(blue.dolar_blue - oficial.dolar_oficial, oficial.dolar_oficial) * 100, 2) as brecha_cambiaria_pct
from oficial
inner join blue on oficial.fecha = blue.fecha
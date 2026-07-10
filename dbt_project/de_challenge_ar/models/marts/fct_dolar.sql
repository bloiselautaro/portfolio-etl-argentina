select
    fecha,
    tipo_dolar,
    precio_compra,
    precio_venta,
    precio_venta - lag(precio_venta) over (partition by tipo_dolar order by fecha) as variacion_diaria,
    round(safe_divide(
        precio_venta - lag(precio_venta) over (partition by tipo_dolar order by fecha),
        lag(precio_venta) over (partition by tipo_dolar order by fecha)
    ) * 100, 2) as variacion_diaria_pct
from {{ ref('stg_dolar') }}
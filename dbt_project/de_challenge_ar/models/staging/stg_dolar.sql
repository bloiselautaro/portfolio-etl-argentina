select
    cast(fecha as date) as fecha,
    casa as tipo_dolar,
    cast(compra as float64) as precio_compra,
    cast(venta as float64) as precio_venta
from {{ source('raw_economy', 'raw_dolar') }}
where fecha is not null
    and casa is not null
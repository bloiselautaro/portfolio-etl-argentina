select
    cast(fecha as date) as fecha,
    cast(valor as float64) as inflacion_mensual_pct
from {{ source('raw_economy', 'raw_inflacion') }}
where fecha is not null
    and valor is not null
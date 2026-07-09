select
    cast(fecha as date) as fecha,
    cast(valor as float64) as reservas_millones_usd
from {{ source('raw_economy', 'raw_reservas_bcra') }}
where fecha is not null
    and valor is not null
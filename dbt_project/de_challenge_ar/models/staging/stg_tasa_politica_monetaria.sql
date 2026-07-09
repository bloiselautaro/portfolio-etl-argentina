select
    cast(fecha as date) as fecha,
    cast(valor as float64) as tasa_politica_monetaria_pct
from {{ source('raw_economy', 'raw_tasa_politica_monetaria') }}
where fecha is not null
    and valor is not null
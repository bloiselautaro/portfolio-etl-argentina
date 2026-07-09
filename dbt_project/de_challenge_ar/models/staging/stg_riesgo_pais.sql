select
    cast(fecha as date) as fecha,
    cast(valor as int64) as riesgo_pais
from {{ source('raw_economy', 'raw_riesgo_pais') }}
where fecha is not null
    and valor is not null
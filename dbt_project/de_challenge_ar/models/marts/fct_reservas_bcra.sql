select
    fecha,
    reservas_millones_usd,
    reservas_millones_usd - lag(reservas_millones_usd) over (order by fecha) as variacion_diaria_millones_usd,
    round(safe_divide(
        reservas_millones_usd - lag(reservas_millones_usd) over (order by fecha),
        lag(reservas_millones_usd) over (order by fecha)
    ) * 100, 2) as variacion_diaria_pct
from {{ ref('stg_reservas_bcra') }}
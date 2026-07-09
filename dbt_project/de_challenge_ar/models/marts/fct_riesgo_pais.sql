select
    fecha,
    riesgo_pais,
    riesgo_pais - lag(riesgo_pais) over (order by fecha) as variacion_diaria,
    round(safe_divide(
        riesgo_pais - lag(riesgo_pais) over (order by fecha),
        lag(riesgo_pais) over (order by fecha)
    ) * 100, 2) as variacion_diaria_pct
from {{ ref('stg_riesgo_pais') }}
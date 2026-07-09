select
    fecha,
    inflacion_mensual_pct,
    round(
        (exp(sum(ln(1 + inflacion_mensual_pct / 100)) over (
            order by fecha rows between 11 preceding and current row
        )) - 1) * 100
    , 2) as inflacion_acumulada_12m_pct
from {{ ref('stg_inflacion') }}
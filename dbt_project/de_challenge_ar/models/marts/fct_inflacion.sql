with acumulado as (

    select
        fecha,
        inflacion_mensual_pct,
        round(
            (exp(sum(ln(1 + inflacion_mensual_pct / 100)) over (
                order by fecha rows between 11 preceding and current row
            )) - 1) * 100
        , 2) as inflacion_acumulada_12m_pct
    from {{ ref('stg_inflacion') }}

)

-- se calcula el acumulado 12m con la serie completa (necesita historia
-- previa para promediar bien), y recién acá se recorta el rango que se
-- expone: la fuente trae datos reales desde 1943, pero para un dashboard
-- de indicadores "actuales" no tiene sentido arrastrar 80 años de historia
-- (incluida la hiperinflación del 89-90) y aplasta cualquier gráfico
select
    fecha,
    inflacion_mensual_pct,
    inflacion_acumulada_12m_pct
from acumulado
where fecha >= '2015-01-01'
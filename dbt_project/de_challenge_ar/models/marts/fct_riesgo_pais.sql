with base as (

    select
        fecha,
        riesgo_pais
    from {{ ref('stg_riesgo_pais') }}

),

-- marca con 1 cada fila donde el valor realmente cambió respecto al
-- día anterior (o es la primera fila de la serie)
marca_cambios as (

    select
        fecha,
        riesgo_pais,
        case
            when riesgo_pais != lag(riesgo_pais) over (order by fecha)
                or lag(riesgo_pais) over (order by fecha) is null
            then 1
            else 0
        end as es_cambio
    from base

),

-- contador que sube 1 en cada cambio real y se mantiene igual mientras
-- el valor no cambie: agrupa cada "racha" de valor plano bajo un mismo id
con_streak as (

    select
        fecha,
        riesgo_pais,
        sum(es_cambio) over (
            order by fecha
            rows unbounded preceding
        ) as streak_id
    from marca_cambios

),

-- un valor único por cada racha (todas las filas de una racha comparten
-- el mismo riesgo_pais, así que min/max/any da lo mismo)
valor_por_streak as (

    select
        streak_id,
        min(riesgo_pais) as riesgo_pais_streak
    from con_streak
    group by streak_id

),

-- cada fila se compara contra el valor de la racha ANTERIOR (streak_id - 1),
-- sin importar cuántos días lleve "planchado" el valor actual
comparado as (

    select
        c.fecha,
        c.riesgo_pais,
        c.streak_id,
        v_prev.riesgo_pais_streak as valor_ultimo_valor_distinto
    from con_streak c
    left join valor_por_streak v_prev
        on c.streak_id - 1 = v_prev.streak_id

)

select
    fecha,
    riesgo_pais,

    -- variación día a día tal cual viene la fuente (puede dar 0.00%
    -- varios días seguidos si la fuente no actualizó el dato)
    riesgo_pais - lag(riesgo_pais) over (order by fecha) as variacion_diaria,
    round(safe_divide(
        riesgo_pais - lag(riesgo_pais) over (order by fecha),
        lag(riesgo_pais) over (order by fecha)
    ) * 100, 2) as variacion_diaria_pct,

    -- variación respecto al último valor realmente distinto (streak anterior);
    -- soluciona el bug de porcentajes disparatados cuando pasan 2+ días
    -- sin cambio (ej. fines de semana)
    riesgo_pais - valor_ultimo_valor_distinto as variacion_desde_ultimo_cambio,
    round(safe_divide(
        riesgo_pais - valor_ultimo_valor_distinto,
        valor_ultimo_valor_distinto
    ) * 100, 2) as variacion_desde_ultimo_cambio_pct

from comparado
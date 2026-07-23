with base as (

    select
        fecha,
        reservas_millones_usd
    from {{ ref('stg_reservas_bcra') }}

),

-- marca con 1 cada fila donde el valor realmente cambió respecto al
-- día anterior (o es la primera fila de la serie)
marca_cambios as (

    select
        fecha,
        reservas_millones_usd,
        case
            when reservas_millones_usd != lag(reservas_millones_usd) over (order by fecha)
                or lag(reservas_millones_usd) over (order by fecha) is null
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
        reservas_millones_usd,
        sum(es_cambio) over (
            order by fecha
            rows unbounded preceding
        ) as streak_id
    from marca_cambios

),

-- un valor único por cada racha (todas las filas de una racha comparten
-- el mismo reservas_millones_usd, así que min/max/any da lo mismo)
valor_por_streak as (

    select
        streak_id,
        min(reservas_millones_usd) as reservas_streak
    from con_streak
    group by streak_id

),

-- cada fila se compara contra el valor de la racha ANTERIOR (streak_id - 1),
-- sin importar cuántos días lleve "planchado" el valor actual
comparado as (

    select
        c.fecha,
        c.reservas_millones_usd,
        c.streak_id,
        v_prev.reservas_streak as valor_ultimo_valor_distinto
    from con_streak c
    left join valor_por_streak v_prev
        on c.streak_id - 1 = v_prev.streak_id

)

select
    fecha,
    reservas_millones_usd,

    -- variación día a día tal cual viene la fuente (puede dar 0.00%
    -- varios días seguidos si la fuente no actualizó el dato)
    reservas_millones_usd - lag(reservas_millones_usd) over (order by fecha) as variacion_diaria_millones_usd,
    round(safe_divide(
        reservas_millones_usd - lag(reservas_millones_usd) over (order by fecha),
        lag(reservas_millones_usd) over (order by fecha)
    ) * 100, 2) as variacion_diaria_pct,

    -- variación respecto al último valor realmente distinto (streak anterior);
    -- soluciona el bug de porcentajes disparatados cuando pasan varios días
    -- hábiles seguidos sin publicación (rezago real de BCRA)
    reservas_millones_usd - valor_ultimo_valor_distinto as variacion_desde_ultimo_cambio_millones_usd,
    round(safe_divide(
        reservas_millones_usd - valor_ultimo_valor_distinto,
        valor_ultimo_valor_distinto
    ) * 100, 2) as variacion_desde_ultimo_cambio_pct

from comparado
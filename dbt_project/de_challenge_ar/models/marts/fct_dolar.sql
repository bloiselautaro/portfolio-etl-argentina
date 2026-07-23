with base as (

    select
        fecha,
        tipo_dolar,
        precio_venta
    from {{ ref('stg_dolar') }}

),

-- marca con 1 cada fila donde el precio realmente cambió respecto al
-- día anterior (o es la primera fila de esa serie de tipo_dolar)
marca_cambios as (

    select
        fecha,
        tipo_dolar,
        precio_venta,
        case
            when precio_venta != lag(precio_venta) over (partition by tipo_dolar order by fecha)
                or lag(precio_venta) over (partition by tipo_dolar order by fecha) is null
            then 1
            else 0
        end as es_cambio
    from base

),

-- contador que sube 1 en cada cambio real y se mantiene igual mientras
-- el precio no cambie: agrupa cada "racha" de precio plano bajo un mismo id
con_streak as (

    select
        fecha,
        tipo_dolar,
        precio_venta,
        sum(es_cambio) over (
            partition by tipo_dolar
            order by fecha
            rows unbounded preceding
        ) as streak_id
    from marca_cambios

),

-- un valor único de venta por cada racha (todas las filas de una racha
-- comparten el mismo precio_venta, así que min/max/any da lo mismo)
valor_por_streak as (

    select
        tipo_dolar,
        streak_id,
        min(precio_venta) as precio_venta_streak
    from con_streak
    group by tipo_dolar, streak_id

),

-- cada fila se compara contra el valor de la racha ANTERIOR (streak_id - 1),
-- sin importar cuántos días lleve "planchado" el valor actual
comparado as (

    select
        c.fecha,
        c.tipo_dolar,
        c.precio_venta,
        c.streak_id,
        v_prev.precio_venta_streak as precio_ultimo_valor_distinto
    from con_streak c
    left join valor_por_streak v_prev
        on c.tipo_dolar = v_prev.tipo_dolar
        and c.streak_id - 1 = v_prev.streak_id

)

select
    fecha,
    tipo_dolar,
    precio_venta,

    -- variación respecto al último valor realmente distinto (streak anterior);
    -- soluciona el bug de porcentajes disparatados cuando pasan 2+ días
    -- sin cambio (ej. fines de semana)
    round(safe_divide(
        precio_venta - precio_ultimo_valor_distinto,
        precio_ultimo_valor_distinto
    ) * 100, 2) as variacion_desde_ultimo_cambio_pct

from comparado
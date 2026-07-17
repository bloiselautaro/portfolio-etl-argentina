with base as (

    select
        fecha,
        reservas_millones_usd
    from {{ ref('stg_reservas_bcra') }}

),

-- marca el valor solo en las filas donde realmente cambió respecto
-- al día anterior (o es la primera fila de la serie)
cambios as (

    select
        fecha,
        reservas_millones_usd,
        case
            when reservas_millones_usd != lag(reservas_millones_usd) over (order by fecha)
                or lag(reservas_millones_usd) over (order by fecha) is null
            then reservas_millones_usd
        end as valor_en_dia_de_cambio
    from base

),

-- para cada fila, busca el último valor distinto anterior (saltea
-- los días donde la fuente repitió el mismo valor sin actualizar)
con_ultimo_valor_distinto as (

    select
        fecha,
        reservas_millones_usd,
        last_value(valor_en_dia_de_cambio ignore nulls) over (
            order by fecha
            rows between unbounded preceding and 1 preceding
        ) as valor_ultimo_valor_distinto
    from cambios

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

    -- variación respecto al último valor realmente distinto (ignora
    -- días "planchados" por falta de actualización de la fuente)
    reservas_millones_usd - valor_ultimo_valor_distinto as variacion_desde_ultimo_cambio_millones_usd,
    round(safe_divide(
        reservas_millones_usd - valor_ultimo_valor_distinto,
        valor_ultimo_valor_distinto
    ) * 100, 2) as variacion_desde_ultimo_cambio_pct

from con_ultimo_valor_distinto
with base as (

    select
        fecha,
        tipo_dolar,
        precio_compra,
        precio_venta
    from {{ ref('stg_dolar') }}

),

-- marca el precio solo en las filas donde realmente cambió respecto
-- al día anterior (o es la primera fila de esa serie)
cambios as (

    select
        fecha,
        tipo_dolar,
        precio_compra,
        precio_venta,
        case
            when precio_venta != lag(precio_venta) over (partition by tipo_dolar order by fecha)
                or lag(precio_venta) over (partition by tipo_dolar order by fecha) is null
            then precio_venta
        end as precio_en_dia_de_cambio
    from base

),

-- para cada fila, busca el último precio distinto anterior (saltea
-- los días donde la fuente repitió el mismo valor sin actualizar)
con_ultimo_valor_distinto as (

    select
        fecha,
        tipo_dolar,
        precio_compra,
        precio_venta,
        last_value(precio_en_dia_de_cambio ignore nulls) over (
            partition by tipo_dolar
            order by fecha
            rows between unbounded preceding and 1 preceding
        ) as precio_ultimo_valor_distinto
    from cambios

)

select
    fecha,
    tipo_dolar,
    precio_compra,
    precio_venta,

    -- variación día a día tal cual viene la fuente (puede dar 0.00%
    -- varios días seguidos si la fuente no actualizó ese tipo de dólar)
    precio_venta - lag(precio_venta) over (partition by tipo_dolar order by fecha) as variacion_diaria,
    round(safe_divide(
        precio_venta - lag(precio_venta) over (partition by tipo_dolar order by fecha),
        lag(precio_venta) over (partition by tipo_dolar order by fecha)
    ) * 100, 2) as variacion_diaria_pct,

    -- variación respecto al último valor realmente distinto (ignora
    -- días "planchados" por falta de actualización de la fuente)
    precio_venta - precio_ultimo_valor_distinto as variacion_desde_ultimo_cambio,
    round(safe_divide(
        precio_venta - precio_ultimo_valor_distinto,
        precio_ultimo_valor_distinto
    ) * 100, 2) as variacion_desde_ultimo_cambio_pct

from con_ultimo_valor_distinto
select
    fecha,
    tasa_politica_monetaria_pct
from {{ ref('stg_tasa_politica_monetaria') }}
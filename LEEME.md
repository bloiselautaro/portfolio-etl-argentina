# Indicadores Económicos Argentina — ETL Serverless

[🇬🇧 English](README.md) | 🇦🇷 Español

![Python](https://img.shields.io/badge/Python-3.13-3776AB?logo=python&logoColor=white)
![dbt](https://img.shields.io/badge/dbt--core-1.7.9-FF694B?logo=dbt&logoColor=white)
![BigQuery](https://img.shields.io/badge/BigQuery-4285F4?logo=googlebigquery&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?logo=githubactions&logoColor=white)
![Looker Studio](https://img.shields.io/badge/Looker_Studio-4285F4?logo=looker&logoColor=white)

Pipeline de datos que extrae, transforma y expone en un dashboard los principales
indicadores económicos de Argentina: cotizaciones del dólar (oficial, blue, CCL,
MEP, mayorista), inflación, riesgo país, reservas del BCRA y brecha cambiaria.

El pipeline corre solo, sin servidores propios: extractores en Python corriendo
en GitHub Actions, transformaciones en dbt, almacenamiento y consultas en
BigQuery, y visualización en Looker Studio.

**Dashboard en vivo:** https://datastudio.google.com/reporting/007d28ae-b55d-4fab-95ff-7f996d7387d5

## Qué muestra el dashboard

- **Página 1 — Dólares**: precio y variación de oficial, blue, CCL, MEP y
  mayorista, más un histórico de líneas comparativo.
- **Página 2 — Inflación y Riesgo País**: inflación mensual e interanual,
  riesgo país y su evolución histórica.
- **Página 3 — Reservas BCRA y Brecha Cambiaria**: reservas actuales y su
  histórico, más un análisis de dispersión entre nivel de reservas y brecha
  cambiaria.

## Stack

| Capa | Tecnología |
|---|---|
| Extracción | Python 3.13 (`requests`, `google-cloud-bigquery`) |
| Orquestación | GitHub Actions (cron, 6 corridas diarias L-V) |
| Almacenamiento y cómputo | BigQuery |
| Transformación | dbt-core 1.7.9 + dbt-bigquery |
| Visualización | Looker Studio |

## Fuentes de datos

- [ArgentinaDatos](https://argentinadatos.com) — histórico de dólar, inflación
  y riesgo país.
- [DolarAPI](https://dolarapi.com) — cotización de dólar intradía, para
  mantener el precio actualizado entre publicaciones de ArgentinaDatos.
- [API del BCRA v4.0](https://api.bcra.gob.ar) — reservas internacionales.

## Arquitectura

```
Extractores (Python)
        ↓
BigQuery — raw_economy (datos crudos, tal cual llegan de la fuente)
        ↓
dbt — staging (limpieza y tipado)
        ↓
dbt — marts (fct_*, cálculos de variación, series unificadas)
        ↓
Looker Studio (dashboard)
```

Todo el proceso corre automáticamente 6 veces al día, de lunes a viernes,
disparado por GitHub Actions — no depende de que nadie lo ejecute a mano.

## Sobre la frescura de los datos

El dashboard se actualiza automáticamente varias veces al día, pero **no es
un sistema de tiempo real**: es un pipeline batch. El techo real de frescura
lo pone cada fuente pública — por ejemplo, el dólar oficial/mayorista se fija
recién a media tarde, y las reservas del BCRA se publican con algunos días de
rezago. El pipeline refleja el último dato disponible en la fuente, no
inventa ni interpola valores.

## Decisiones de diseño destacadas

- **Cálculo de variación por "rachas" (streaks)**: cuando un precio no cambia
  por varios días seguidos (fines de semana, feriados, rezago de la fuente),
  la variación porcentual se calcula contra el último valor *realmente*
  distinto — no contra el día calendario anterior. Esto evita mostrar 0,00%
  en días donde el mercado simplemente no operó.
- **Combinación de dos fuentes para el dólar**: el histórico viene de
  ArgentinaDatos (una publicación diaria), pero se enriquece con DolarAPI
  para tener el valor más actualizado del día en cada corrida del pipeline.
- **Recorte de series muy extensas**: la inflación argentina tiene registros
  desde 1943 (incluida la hiperinflación de 1989-90), pero el dashboard
  muestra desde 2015 para mantener el eje de los gráficos legible y
  relevante a la coyuntura actual.

## Cómo correrlo localmente

Requiere Python 3.13, una cuenta de servicio de GCP con permisos sobre
BigQuery, y dbt-core.

```bash
git clone https://github.com/bloiselautaro/portfolio-etl-argentina.git
cd portfolio-etl-argentina
pip install -r requirements.txt

# Copiar .env.example a .env y completar con tus credenciales de GCP
cp .env.example .env

# Correr los extractores
cd extraction
python extract_dolar.py
python extract_inflacion.py
python extract_riesgo_pais.py
python extract_bcra.py

# Correr las transformaciones de dbt
cd ../dbt_project/de_challenge_ar
dbt run
```

## Limitaciones conocidas

- La brecha cambiaria solo está disponible desde 2011 (fecha de inicio de la
  serie de dólar blue en la fuente pública), mientras que las reservas BCRA
  se registran desde 2003 — por eso el análisis combinado de ambas series
  arranca en 2011.
- El pipeline depende de la disponibilidad y el rezago de publicación de
  cada fuente pública, que está fuera de nuestro control.
# Argentina Economic Indicators — Serverless ETL

🇬🇧 English | [🇦🇷 Español](LEEME.md)

![Python](https://img.shields.io/badge/Python-3.13-3776AB?logo=python&logoColor=white)
![dbt](https://img.shields.io/badge/dbt--core-1.7.9-FF694B?logo=dbt&logoColor=white)
![BigQuery](https://img.shields.io/badge/BigQuery-4285F4?logo=googlebigquery&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?logo=githubactions&logoColor=white)
![Looker Studio](https://img.shields.io/badge/Looker_Studio-4285F4?logo=looker&logoColor=white)

Data pipeline that extracts, transforms, and exposes Argentina's key economic
indicators in a live dashboard: exchange rates (official, blue/informal, CCL,
MEP, wholesale), inflation, country risk, Central Bank (BCRA) reserves, and
the exchange rate gap.

The pipeline runs on its own, with no servers to maintain: Python extractors
running on GitHub Actions, transformations in dbt, storage and querying in
BigQuery, and visualization in Looker Studio.

**Live dashboard:** https://datastudio.google.com/reporting/007d28ae-b55d-4fab-95ff-7f996d7387d5

## What the dashboard shows

- **Page 1 — Exchange Rates**: price and variation for official, blue, CCL,
  MEP, and wholesale dollar, plus a comparative historical line chart.
- **Page 2 — Inflation & Country Risk**: monthly and year-over-year
  inflation, country risk index and its historical trend.
- **Page 3 — BCRA Reserves & Exchange Rate Gap**: current reserves and their
  history, plus a scatter analysis between reserve levels and the exchange
  rate gap.

## Stack

| Layer | Technology |
|---|---|
| Extraction | Python 3.13 (`requests`, `google-cloud-bigquery`) |
| Orchestration | GitHub Actions (cron, 6 daily runs, Mon-Fri) |
| Storage & compute | BigQuery |
| Transformation | dbt-core 1.7.9 + dbt-bigquery |
| Visualization | Looker Studio |

## Data sources

- [ArgentinaDatos](https://argentinadatos.com) — historical dollar,
  inflation, and country risk data.
- [DolarAPI](https://dolarapi.com) — intraday dollar quotes, used to keep the
  price current between ArgentinaDatos' daily publications.
- [BCRA API v4.0](https://api.bcra.gob.ar) — international reserves.

## Architecture

```
Extractors (Python)
        ↓
BigQuery — raw_economy (raw data, as received from source)
        ↓
dbt — staging (cleaning and typing)
        ↓
dbt — marts (fct_*, variation calculations, unified series)
        ↓
Looker Studio (dashboard)
```

The whole process runs automatically 6 times a day, Monday through Friday,
triggered by GitHub Actions — no manual execution required.

## On data freshness

The dashboard refreshes automatically several times a day, but **this is not
a real-time system** — it's a batch pipeline. The real freshness ceiling is
set by each public source: for example, the official/wholesale dollar rate
is only set in the mid-afternoon, and BCRA reserves are published with a
multi-day lag. The pipeline reflects the latest data available at the
source; it does not invent or interpolate values.

## Notable design decisions

- **Streak-based variation calculation**: when a price doesn't change for
  several consecutive days (weekends, holidays, source lag), the percentage
  variation is calculated against the last *genuinely* different value —
  not against the previous calendar day. This avoids showing 0.00% on days
  when the market simply didn't move.
- **Combining two sources for the dollar**: the historical series comes from
  ArgentinaDatos (one publication per day), enriched with DolarAPI to get
  the most current value on every pipeline run.
- **Trimming very long series**: Argentina's inflation records go back to
  1943 (including the 1989-90 hyperinflation), but the dashboard shows data
  from 2015 onward to keep chart axes readable and relevant to current
  conditions.

## Running it locally

Requires Python 3.13, a GCP service account with BigQuery permissions, and
dbt-core.

```bash
git clone https://github.com/bloiselautaro/portfolio-etl-argentina.git
cd portfolio-etl-argentina
pip install -r requirements.txt

# Copy .env.example to .env and fill in your GCP credentials
cp .env.example .env

# Run the extractors
cd extraction
python extract_dolar.py
python extract_inflacion.py
python extract_riesgo_pais.py
python extract_bcra.py

# Run the dbt transformations
cd ../dbt_project/de_challenge_ar
dbt run
```

## Known limitations

- The exchange rate gap is only available from 2011 onward (the start date
  of the blue dollar series in the public source), while BCRA reserves are
  recorded from 2003 — so the combined analysis of both series starts in
  2011.
- The pipeline depends on the availability and publication lag of each
  public source, which is outside this project's control.
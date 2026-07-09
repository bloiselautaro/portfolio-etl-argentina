import requests
from google.cloud import bigquery
from config import get_bigquery_client, PROJECT_ID, DATASET_RAW

API_URL = "https://api.argentinadatos.com/v1/finanzas/indices/inflacion"
TABLE_NAME = "raw_inflacion"


def fetch_inflacion() -> list[dict]:
    response = requests.get(API_URL, timeout=30)
    response.raise_for_status()
    data = response.json()
    print(f"Registros obtenidos de la API: {len(data)}")
    return data


def load_to_bigquery(rows: list[dict]) -> None:
    client = get_bigquery_client()
    table_id = f"{PROJECT_ID}.{DATASET_RAW}.{TABLE_NAME}"

    job_config = bigquery.LoadJobConfig(
        write_disposition="WRITE_TRUNCATE",
        autodetect=True,
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
    )

    load_job = client.load_table_from_json(rows, table_id, job_config=job_config)
    load_job.result()

    table = client.get_table(table_id)
    print(f"✅ Cargado en {table_id}: {table.num_rows} filas.")


if __name__ == "__main__":
    rows = fetch_inflacion()
    load_to_bigquery(rows)
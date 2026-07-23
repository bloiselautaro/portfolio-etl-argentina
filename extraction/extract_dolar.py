from datetime import datetime, timezone, timedelta
import requests
from google.cloud import bigquery
from config import get_bigquery_client, PROJECT_ID, DATASET_RAW

API_HISTORICO = "https://api.argentinadatos.com/v1/cotizaciones/dolares"
API_ACTUAL = "https://dolarapi.com/v1/dolares"
TABLE_NAME = "raw_dolar"
TZ_ARGENTINA = timezone(timedelta(hours=-3))

def fetch_dolar_historico() -> list[dict]:
    """Trae el historial completo desde ArgentinaDatos."""
    response = requests.get(API_HISTORICO, timeout=30)
    response.raise_for_status()
    data = response.json()
    print(f"Registros históricos obtenidos: {len(data)}")
    return data

def fetch_dolar_intradia() -> list[dict]:
    """Trae las cotizaciones al instante directo desde DolarAPI."""
    response = requests.get(API_ACTUAL, timeout=30)
    response.raise_for_status()
    data = response.json()
    
    registros_actuales = []
    for d in data:
        # DolarAPI devuelve la fecha en UTC (ej. "2026-07-22T01:30:00.000Z").
        # Hay que convertir a hora Argentina antes de extraer la fecha, porque
        # cortar el string a mano asume que UTC y ART caen el mismo día, y eso
        # falla en el rango 21hs-24hs ART (madrugada UTC del día siguiente).
        timestamp_utc = datetime.fromisoformat(d["fechaActualizacion"].replace("Z", "+00:00"))
        fecha_argentina = timestamp_utc.astimezone(TZ_ARGENTINA).strftime("%Y-%m-%d")
        registro = {
            "casa": d["casa"],
            "compra": d["compra"],
            "venta": d["venta"],
            "fecha": fecha_argentina
        }
        registros_actuales.append(registro)
        
    print(f"Registros actuales (intradía) obtenidos: {len(registros_actuales)}")
    return registros_actuales

def combinar_y_deduplicar(historico: list[dict], actual: list[dict]) -> list[dict]:
    """Combina listas pisando el dato histórico de hoy con el dato real de hoy."""
    datos_combinados = {}
    
    # Metemos todo el histórico
    for h in historico:
        clave = (h["casa"], h["fecha"])
        datos_combinados[clave] = h
        
    # Metemos lo actual (si hoy ya existía en el histórico, lo sobreescribe)
    for a in actual:
        clave = (a["casa"], a["fecha"])
        datos_combinados[clave] = a
        
    lista_final = list(datos_combinados.values())
    print(f"Total de registros listos para cargar: {len(lista_final)}")
    return lista_final

def load_to_bigquery(rows: list[dict]) -> None:
    """Carga el historial actualizado a BigQuery, reemplazando la tabla raw."""
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
    historico = fetch_dolar_historico()
    actual = fetch_dolar_intradia()
    rows = combinar_y_deduplicar(historico, actual)
    load_to_bigquery(rows)
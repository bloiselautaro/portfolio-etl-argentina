import requests
from google.cloud import bigquery
from config import get_bigquery_client, PROJECT_ID, DATASET_RAW

BASE_URL = "https://api.bcra.gob.ar/estadisticas/v4.0"

VARIABLES_OBJETIVO = {
    "raw_reservas_bcra": "reservas internacionales",
}


def obtener_catalogo() -> list[dict]:
    response = requests.get(f"{BASE_URL}/monetarias", timeout=30, verify=False)
    response.raise_for_status()
    return response.json()["results"]


def fetch_historico(id_variable: int) -> list[dict]:
    """Trae el histórico completo de una variable, paginando (máx 3000 por página)."""
    todos_los_registros = []
    offset = 0
    limit = 3000

    while True:
        url = f"{BASE_URL}/monetarias/{id_variable}"
        params = {"desde": "2003-01-01", "limit": limit, "offset": offset}
        response = requests.get(url, params=params, timeout=30, verify=False)
        response.raise_for_status()
        detalle = response.json()["results"][0]["detalle"]

        if not detalle:
            break

        todos_los_registros.extend(detalle)
        offset += limit

        if len(detalle) < limit:
            break

    return todos_los_registros


def resolver_id_variable(texto_busqueda: str, catalogo: list[dict]) -> tuple[int, str]:
    """Busca por texto en la descripción. Si hay varias coincidencias
    (ej: series discontinuadas con el mismo nombre), trae el histórico de
    cada una y elige la que tiene el dato más reciente — esa es la serie
    vigente hoy."""
    coincidencias = [
        r for r in catalogo
        if texto_busqueda.lower() in r["descripcion"].lower()
    ]

    if not coincidencias:
        raise ValueError(f"No se encontró ninguna variable con: '{texto_busqueda}'")

    if len(coincidencias) == 1:
        variable = coincidencias[0]
        return variable["idVariable"], variable["descripcion"]

    print(f"⚠️  {len(coincidencias)} coincidencias para '{texto_busqueda}', "
          f"comparando fecha más reciente de cada una:")
    mejor_id = None
    mejor_fecha = None
    mejor_desc = None

    for c in coincidencias:
        historico = fetch_historico(c["idVariable"])
        if not historico:
            print(f"   - id {c['idVariable']}: sin datos, se descarta")
            continue
        ultima_fecha = max(row["fecha"] for row in historico)
        print(f"   - id {c['idVariable']}: última fecha = {ultima_fecha}")
        if mejor_fecha is None or ultima_fecha > mejor_fecha:
            mejor_fecha = ultima_fecha
            mejor_id = c["idVariable"]
            mejor_desc = c["descripcion"]

    print(f"   → Elegida id {mejor_id} (serie vigente, dato más reciente)")
    return mejor_id, mejor_desc


def load_to_bigquery(rows: list[dict], table_name: str) -> None:
    client = get_bigquery_client()
    table_id = f"{PROJECT_ID}.{DATASET_RAW}.{table_name}"

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
    catalogo = obtener_catalogo()

    for table_name, texto_busqueda in VARIABLES_OBJETIVO.items():
        print(f"\n--- Procesando: {texto_busqueda} ---")
        id_variable, descripcion = resolver_id_variable(texto_busqueda, catalogo)
        print(f"Variable resuelta: id={id_variable} → '{descripcion}'")

        rows = fetch_historico(id_variable)
        print(f"Registros obtenidos: {len(rows)}")

        load_to_bigquery(rows, table_name)
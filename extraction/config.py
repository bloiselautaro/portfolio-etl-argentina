import os
from pathlib import Path
from dotenv import load_dotenv
from google.cloud import bigquery

# Carga el .env sin importar desde dónde se ejecute el script
ROOT_DIR = Path(__file__).resolve().parent.parent
load_dotenv(dotenv_path=ROOT_DIR / ".env")

PROJECT_ID = os.getenv("GCP_PROJECT_ID")
DATASET_RAW = os.getenv("GCP_DATASET_RAW")
DATASET_ANALYTICS = os.getenv("GCP_DATASET_ANALYTICS")

# GOOGLE_APPLICATION_CREDENTIALS en el .env es un nombre de archivo relativo
# (ej: "proyecto-etl-key.json"). Google lo busca relativo al directorio
# desde donde se ejecuta el script, lo cual rompe si corremos desde otra
# carpeta (ej: extraction/). Lo resolvemos siempre contra ROOT_DIR y
# sobreescribimos la variable de entorno con la ruta absoluta.
_creds_filename = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
if _creds_filename:
    _creds_path = (ROOT_DIR / _creds_filename).resolve()
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = str(_creds_path)


def get_bigquery_client() -> bigquery.Client:
    """Cliente de BigQuery ya autenticado, listo para usar en cualquier script."""
    return bigquery.Client(project=PROJECT_ID)
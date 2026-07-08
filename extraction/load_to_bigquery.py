import os
import requests
import pandas as pd
from google.cloud import bigquery
from dotenv import load_dotenv

# Cargo las variables de entorno del archivo .env local
load_dotenv()

PROJECT_ID = os.getenv("GCP_PROJECT_ID")
DATASET_RAW = os.getenv("GCP_DATASET_RAW")

def extraer_datos_dolar():
    url = "https://dolarapi.com/v1/dolares"
    response = requests.get(url, timeout=15)
    response.raise_for_status()
    
    df = pd.DataFrame(response.json())
    
    # Ojo: Forzar formato datetime acá para que BigQuery no lo tome como string
    df['fecha_actualizacion'] = pd.to_datetime(df['fechaActualizacion'])
    
    df_limpio = df[['casa', 'compra', 'venta', 'fecha_actualizacion']]
    return df_limpio

def cargar_tabla_raw(df, nombre_tabla):
    client = bigquery.Client()
    
    # Destino completo del recurso en GCP
    table_id = f"{PROJECT_ID}.{DATASET_RAW}.{nombre_tabla}"
    
    # Configuro modo APPEND para acumular el historial diario del mercado
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND
    )
    
    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result() # Bloquea el hilo hasta que termine la transacción en la nube
    print(f"Carga exitosa: Se insertaron registros en {table_id}")

if __name__ == "__main__":
    print("Iniciando extracción del mercado cambiario...")
    datos_dolar = extraer_datos_dolar()
    
    print("Iniciando carga en BigQuery Cloud...")
    cargar_tabla_raw(datos_dolar, "dolar_raw")
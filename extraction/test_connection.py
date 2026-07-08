from config import get_bigquery_client, DATASET_RAW, DATASET_ANALYTICS

if __name__ == "__main__":
    client = get_bigquery_client()
    datasets = [d.dataset_id for d in client.list_datasets()]
    print(f"Proyecto: {client.project}")
    print(f"Datasets encontrados: {datasets}")
    assert DATASET_RAW in datasets, f"Falta el dataset {DATASET_RAW}"
    assert DATASET_ANALYTICS in datasets, f"Falta el dataset {DATASET_ANALYTICS}"
    print("✅ Conexión OK, datasets confirmados.")
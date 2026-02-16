from udata.app import create_app
from udata_metrics.metrics import get_metrics_for_model

app = create_app()
with app.app_context():
    dataset_id = "67c5a3b3b50fe67ba7aa1905"
    metrics = get_metrics_for_model(
        "dataset", dataset_id, ["visit", "download_resource"]
    )
    print(f"METRICS: {metrics}")

module.exports = {
  apps: [
    {
      name: "api-tabular",
      script: "uv",
      args: [
        "run", "gunicorn", "api_tabular.tabular.app:app_factory",
        "--bind", "0.0.0.0:8005",
        "--worker-class", "aiohttp.GunicornWebWorker",
        "--workers", "4",
        "--access-logfile", "-"
      ],
      interpreter: "none"
    },
    {
      name: "api-metrics",
      script: "uv",
      args: [
        "run", "gunicorn", "api_tabular.metrics.app:app_factory",
        "--bind", "0.0.0.0:8006",
        "--worker-class", "aiohttp.GunicornWebWorker",
        "--workers", "4",
        "--access-logfile", "-"
      ],
      interpreter: "none"
    }
  ]
}
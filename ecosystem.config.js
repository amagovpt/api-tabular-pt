module.exports = {
  apps: [
    // ---- Tabular / Metrics APIs (cwd: /opt/api-tabular-pt) ----
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
      cwd: "/opt/api-tabular-pt",
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
      cwd: "/opt/api-tabular-pt",
      interpreter: "none"
    },

    // ---- Hydra services (cwd: /opt/hydra-pt) ----
    {
      name: "hydra-app",
      script: "uv",
      args: [
        "run", "gunicorn", "udata_hydra.app:app_factory",
        "--bind", "0.0.0.0:8000",
        "--worker-class", "aiohttp.GunicornWebWorker",
        "--workers", "4",
        "--access-logfile", "-"
      ],
      cwd: "/opt/hydra-pt",
      interpreter: "none"
    },
    {
      name: "hydra-crawler",
      script: "uv",
      args: ["run", "udata-hydra-crawl"],
      cwd: "/opt/hydra-pt",
      interpreter: "none"
    },
    {
      name: "hydra-worker",
      script: "uv",
      args: ["run", "rq", "worker", "-c", "udata_hydra.worker"],
      cwd: "/opt/hydra-pt",
      interpreter: "none"
    }
  ]
}

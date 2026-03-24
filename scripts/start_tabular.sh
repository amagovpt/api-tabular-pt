#!/bin/bash

WORKDIR="/opt/api-tabular-pt"
LOGDIR="$WORKDIR/logs"
UV_BIN="/home/dev/.local/bin/uv"

# Aguarda 20 segundos antes de iniciar os serviços (evita concorrência no boot)
echo "Aguardando 20 segundos antes de iniciar serviços..."
sleep 20

mkdir -p "$LOGDIR"

# Liberar portas 8005 e 8006, se estiverem ocupadas
for PORT in 8005 8006; do
  PID=$(lsof -ti :"$PORT" 2>/dev/null)
  if [ -n "$PID" ]; then
    echo "Porta $PORT em uso por PID $PID. Encerrando processo..."
    kill "$PID"
    sleep 5
  fi
done

cd "$WORKDIR"

# Inicia o servidor da aplicação (tabular) na porta 8005
$UV_BIN run gunicorn api_tabular.tabular.app:app_factory \
  --bind 0.0.0.0:8005 \
  --worker-class aiohttp.GunicornWebWorker \
  --workers 4 \
  --access-logfile - \
  >> "$LOGDIR/app.log" 2>&1 &

# Inicia o servidor de métricas na porta 8006
$UV_BIN run gunicorn api_tabular.metrics.app:app_factory \
  --bind 0.0.0.0:8006 \
  --worker-class aiohttp.GunicornWebWorker \
  --workers 4 \
  --access-logfile - \
  >> "$LOGDIR/metrics.log" 2>&1 &

wait

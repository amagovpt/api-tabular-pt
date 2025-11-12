#!/bin/bash

# Caminho absoluto do poetry
POETRY_BIN="/home/dev/.local/bin/poetry"
WORKDIR="/opt/api-tabular-pt"
LOGDIR="$WORKDIR/logs"

# Aguarda 20 segundos antes de iniciar os serviços (evita concorrência no boot)
echo "Aguardando 20 segundos antes de iniciar serviços..."
sleep 20

mkdir -p "$LOGDIR"

# Verifica se o lsof está instalado, senão instala (Rocky Linux / RHEL)
if ! command -v lsof &> /dev/null; then
  echo "lsof não encontrado. Instalando..."
  sudo dnf install -y lsof
  if [ $? -ne 0 ]; then
    echo "Erro: falha ao instalar o lsof. Verifique a conectividade e repositórios."
    exit 1
  fi
fi

# Liberar portas 8005 e 8006, se estiverem ocupadas
for PORT in 8005 8006; do
  PID=$(lsof -ti :$PORT)
  if [ -n "$PID" ]; then
    echo "Porta $PORT em uso por PID $PID. Matando processo..."
    kill -9 $PID
    sleep 5   # Aguarda 5 segundos para liberar a porta
  fi
done

cd "$WORKDIR"

# Inicia o servidor da aplicação na porta 8005
$POETRY_BIN run adev runserver -p8005 "$WORKDIR/api_tabular/app.py" > "$LOGDIR/app.log" 2>&1 &

# Inicia o servidor de métricas na porta 8007
$POETRY_BIN run adev runserver -p8007 "$WORKDIR/api_tabular/metrics.py" > "$LOGDIR/metrics.log" 2>&1 &

wait

## Tornar script de inicialização executável:
# chmod +x /opt/api-tabular-pt/start_tabular.sh

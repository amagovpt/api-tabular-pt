#!/bin/bash
#
# Arranque reprodutível de todo o stack via pm2:
#   - Apps (hydra + api-tabular/metrics) a partir do ecosystem.config.js
#   - Módulo pm2-logrotate (instalação + configuração)
#   - Serviço systemd de arranque no boot (pm2 startup) — só se ainda não existir
#   - Persistência (pm2 save) para sobreviver a reboots
#
# Idempotente: pode ser re-executado com segurança (startOrReload aplica
# alterações do ecosystem.config.js aos processos já em execução).
#
# Uso:  bash /opt/api-tabular-pt/scripts/setup_pm2.sh

set -euo pipefail

# Resolver caminhos a partir da localização deste script (scripts/ -> raiz do repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ECOSYSTEM="$(cd "$SCRIPT_DIR/.." && pwd)/ecosystem.config.js"

if ! command -v pm2 >/dev/null 2>&1; then
  echo "ERRO: 'pm2' nao encontrado no PATH. Instale-o primeiro (npm install -g pm2)." >&2
  exit 1
fi

if [ ! -f "$ECOSYSTEM" ]; then
  echo "ERRO: ecosystem.config.js nao encontrado em $ECOSYSTEM" >&2
  exit 1
fi

echo "==> ecosystem: $ECOSYSTEM"

# ---------------------------------------------------------------------------
# 1) Modulo pm2-logrotate (instalacao + configuracao)
# ---------------------------------------------------------------------------
echo "==> A instalar/garantir o modulo pm2-logrotate..."
pm2 install pm2-logrotate

echo "==> A aplicar configuracao do pm2-logrotate..."
pm2 set pm2-logrotate:max_size 50M
pm2 set pm2-logrotate:retain 7
pm2 set pm2-logrotate:compress true
pm2 set pm2-logrotate:dateFormat YYYY-MM-DD_HH-mm-ss
pm2 set pm2-logrotate:rotateInterval "0 2 * * *"   # rotacao diaria as 02:00
pm2 set pm2-logrotate:workerInterval 30
pm2 set pm2-logrotate:rotateModule true

# ---------------------------------------------------------------------------
# 2) Apps do stack (a partir do ecosystem.config.js)
# ---------------------------------------------------------------------------
echo "==> A arrancar/recarregar os apps do ecosystem..."
# startOrReload: arranca os que nao existem, recarrega os que ja estao a correr
pm2 startOrReload "$ECOSYSTEM"

# ---------------------------------------------------------------------------
# 3) Arranque no boot: instalar o servico systemd do pm2 apenas se nao existir
# ---------------------------------------------------------------------------
PM2_USER="$(whoami)"
PM2_SERVICE="pm2-${PM2_USER}"
if systemctl list-unit-files 2>/dev/null | grep -qE "^${PM2_SERVICE}\.service[[:space:]]"; then
  echo "==> Servico systemd '${PM2_SERVICE}.service' ja existe. A saltar 'pm2 startup'."
else
  echo "==> Servico systemd '${PM2_SERVICE}.service' nao existe. A instalar (pm2 startup)..."
  NODE_BIN_DIR="$(dirname "$(command -v node)")"
  if sudo env PATH="$PATH:$NODE_BIN_DIR" pm2 startup systemd -u "$PM2_USER" --hp "$HOME"; then
    echo "   Servico '${PM2_SERVICE}.service' instalado (arranca no boot e faz 'pm2 resurrect')."
  else
    echo "   AVISO: falha ao instalar o servico systemd (sudo indisponivel?). A continuar." >&2
  fi
fi

# ---------------------------------------------------------------------------
# 4) Persistir (apps + modulos) para o arranque no boot
# ---------------------------------------------------------------------------
echo "==> A gravar a lista de processos (pm2 save)..."
pm2 save

echo
echo "==> Concluido. Estado atual:"
pm2 list

#!/usr/bin/env bash
#
# Instalacao/atualizacao do MGprint em Ubuntu 24.04+.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/fabiomigliorini/MGprint/main/instalar.sh | bash
#
# Ou, apos o primeiro install:
#   bash /opt/MGprint/instalar.sh
#
# Requisitos: Ubuntu 24.04+ (Node >=16), usuario com sudo.

set -euo pipefail

PROJECT_DIR="/opt/MGprint"
REPO_URL="https://github.com/fabiomigliorini/MGprint.git"
SERVICE_USER="${SUDO_USER:-${USER:-$(id -un)}}"
SUPERVISOR_CONF="/etc/supervisor/conf.d/MGprint.conf"

if [ "$(id -u)" = "0" ]; then
  echo "ERRO: rode como usuario comum (nao root). O script usa sudo internamente." >&2
  exit 1
fi

echo ">> usuario: $SERVICE_USER"
echo ">> projeto: $PROJECT_DIR"

echo ">> instalando dependencias do sistema (git, nodejs, npm, supervisor)"
sudo apt-get update
sudo apt-get install -y git nodejs npm supervisor

NODE_MAJOR=$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0)
if [ "$NODE_MAJOR" -lt 16 ]; then
  echo "ERRO: Node v$NODE_MAJOR instalado. Ably v2 exige Node >=16." >&2
  echo "Atualize para Ubuntu 24.04+ (Node 18 no repositorio oficial) antes de continuar." >&2
  exit 1
fi
echo ">> Node $(node -v) OK"

if [ -d "$PROJECT_DIR/.git" ]; then
  echo ">> repositorio ja existe, fazendo git pull"
  cd "$PROJECT_DIR"
  if [ -n "$(git status --porcelain)" ]; then
    echo "ERRO: ha alteracoes locais em $PROJECT_DIR. Resolva antes de continuar." >&2
    exit 1
  fi
  git pull --ff-only
else
  echo ">> clonando de $REPO_URL"
  sudo git clone "$REPO_URL" "$PROJECT_DIR"
  sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR"
  cd "$PROJECT_DIR"
fi

echo ">> limpando node_modules e package-lock.json"
rm -rf node_modules package-lock.json

echo ">> npm install"
npm install

NEEDS_CONFIG=0
if [ ! -f "$PROJECT_DIR/config.json" ]; then
  echo ">> criando config.json a partir do sample"
  cp config.json.sample config.json
  NEEDS_CONFIG=1
fi

echo ">> escrevendo $SUPERVISOR_CONF"
sudo tee "$SUPERVISOR_CONF" > /dev/null <<EOF
[program:MGprint]
directory=$PROJECT_DIR/
user=$SERVICE_USER
command=node .
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/MGprint.log
redirect_stderr=true
EOF

echo ">> reiniciando supervisor"
sudo service supervisor restart

if [ "$NEEDS_CONFIG" = "1" ]; then
  cat <<EOF

=============================================================
ATENCAO: install nova detectada.
Edite $PROJECT_DIR/config.json antes do servico funcionar:
  - preencha a chave do Ably
  - ajuste a lista de impressoras (precisam bater com o nome no CUPS)

Depois de editar:
  sudo service supervisor restart
  sudo tail -f /var/log/supervisor/MGprint.log
=============================================================
EOF
else
  echo ">> pronto. log:"
  echo "   sudo tail -f /var/log/supervisor/MGprint.log"
fi

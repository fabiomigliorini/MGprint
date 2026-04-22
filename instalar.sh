#!/usr/bin/env bash
#
# Instalacao/atualizacao do MGprint em Ubuntu 24.04+.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/fabiomigliorini/MGprint/main/instalar.sh | bash
#
# Idempotente: rode quantas vezes quiser. Limpa node_modules em cada execucao.
# Preserva config.json existente (nao reescreve).

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

echo ">> instalando dependencias do sistema (git, nodejs, npm, supervisor, jq)"
sudo apt-get update
sudo apt-get install -y git nodejs npm supervisor jq

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

echo ">> removendo node_modules e package-lock.json (idempotencia)"
rm -rf node_modules package-lock.json

echo ">> npm install"
npm install

# ----- config.json -----
if [ -f "$PROJECT_DIR/config.json" ]; then
  echo ">> config.json ja existe, preservando (edite manualmente se precisar)"
else
  echo ""
  echo ">> configurando config.json"

  printf "Chave do Ably: "
  read -r ABLY_KEY < /dev/tty
  if [ -z "$ABLY_KEY" ]; then
    echo "ERRO: chave do Ably e obrigatoria." >&2
    exit 1
  fi

  echo ""
  echo "Cole o conteudo do printers.json do servidor e pressione Ctrl+D:"
  echo "(no servidor: cat /opt/www/MGspa/laravel/printers.json)"
  PRINTERS_JSON_RAW=$(cat < /dev/tty)

  if ! echo "$PRINTERS_JSON_RAW" | jq empty 2>/dev/null; then
    echo "ERRO: printers.json invalido (nao eh JSON)." >&2
    exit 1
  fi

  # hostname -> tenta casar impressoras cujo nome contenha o hostname
  HOST=$(hostname -s)
  HOST_STRIP=$(echo "$HOST" | sed 's/-ub$//')
  echo ""
  echo ">> hostname: $HOST  (procurando impressoras com '$HOST_STRIP')"

  SELECTED=$(echo "$PRINTERS_JSON_RAW" | jq -r --arg h "$HOST_STRIP" '
    keys[] | select(contains($h))
  ')

  if [ -z "$SELECTED" ]; then
    echo "Nao encontrei impressoras que batem com '$HOST_STRIP'."
    echo "Digite os nomes manualmente, um por linha, termine com linha vazia:"
    PRINTERS_ARR=()
    while IFS= read -r line < /dev/tty; do
      [ -z "$line" ] && break
      PRINTERS_ARR+=("$line")
    done
    if [ "${#PRINTERS_ARR[@]}" -eq 0 ]; then
      echo "ERRO: nenhuma impressora informada." >&2
      exit 1
    fi
    SELECTED=$(printf '%s\n' "${PRINTERS_ARR[@]}")
  else
    echo "Impressoras detectadas:"
    echo "$SELECTED" | sed 's/^/  - /'
  fi

  PRINTERS_ARRAY=$(echo "$SELECTED" | jq -R . | jq -s .)
  jq -n --arg key "$ABLY_KEY" --argjson printers "$PRINTERS_ARRAY" '{
    ably: { key: $key, channel: "printing" },
    printers: $printers
  }' > "$PROJECT_DIR/config.json"

  echo ">> config.json gerado em $PROJECT_DIR/config.json"
fi

# ----- supervisor -----
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

echo ""
echo ">> pronto. log:"
echo "   sudo tail -f /var/log/supervisor/MGprint.log"

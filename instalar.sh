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
echo ""
echo ">> configurando config.json (enter mantem o valor atual)"

CURRENT_KEY=""
CURRENT_PRINTERS_JSON="[]"
if [ -f "$PROJECT_DIR/config.json" ]; then
  CURRENT_KEY=$(jq -r '.ably.key // ""' "$PROJECT_DIR/config.json")
  CURRENT_PRINTERS_JSON=$(jq -c '.printers // []' "$PROJECT_DIR/config.json")
fi

# chave do Ably
echo ""
if [ -n "$CURRENT_KEY" ]; then
  echo "Chave do Ably atual: $CURRENT_KEY"
  printf "Nova chave (enter para manter): "
else
  printf "Chave do Ably: "
fi
read -r ABLY_KEY < /dev/tty
ABLY_KEY=${ABLY_KEY:-$CURRENT_KEY}
if [ -z "$ABLY_KEY" ]; then
  echo "ERRO: chave do Ably e obrigatoria." >&2
  exit 1
fi

# impressoras
echo ""
HAS_PRINTERS=0
if [ "$CURRENT_PRINTERS_JSON" != "[]" ] && [ "$CURRENT_PRINTERS_JSON" != "null" ]; then
  HAS_PRINTERS=1
fi

if ! command -v lpstat > /dev/null; then
  echo "ERRO: lpstat nao encontrado. Instale o CUPS antes: sudo apt install cups cups-client" >&2
  exit 1
fi

mapfile -t LOCAL_PRINTERS < <(lpstat -a 2>/dev/null | awk '{print $1}' | sort -u)

if [ "${#LOCAL_PRINTERS[@]}" -eq 0 ]; then
  echo "AVISO: nenhuma impressora instalada no CUPS deste computador."
  if [ "$HAS_PRINTERS" = "1" ]; then
    echo ">> mantendo impressoras atuais do config.json"
    PRINTERS_ARRAY="$CURRENT_PRINTERS_JSON"
  else
    echo "ERRO: configure ao menos uma impressora no CUPS e rode o script novamente." >&2
    exit 1
  fi
else
  while true; do
    echo ""
    echo "Impressoras instaladas no CUPS deste computador:"
    for i in "${!LOCAL_PRINTERS[@]}"; do
      n=$((i+1))
      p="${LOCAL_PRINTERS[$i]}"
      if echo "$CURRENT_PRINTERS_JSON" | jq -e --arg p "$p" 'index($p) != null' > /dev/null 2>&1; then
        mark="x"
      else
        mark=" "
      fi
      printf "  %2d) [%s] %s\n" "$n" "$mark" "$p"
    done
    echo ""
    echo "Digite os numeros das impressoras a incluir (separados por espaco),"
    if [ "$HAS_PRINTERS" = "1" ]; then
      echo "'all' para todas, ou enter direto para manter selecao atual (marcadas com x):"
    else
      echo "ou 'all' para todas:"
    fi
    printf "Selecao: "
    read -r SELECTION < /dev/tty

    if [ -z "$SELECTION" ]; then
      if [ "$HAS_PRINTERS" = "1" ]; then
        PRINTERS_ARRAY="$CURRENT_PRINTERS_JSON"
      else
        echo "ERRO: nenhuma impressora selecionada."
        continue
      fi
    elif [ "$SELECTION" = "all" ] || [ "$SELECTION" = "ALL" ]; then
      PRINTERS_ARRAY=$(printf '%s\n' "${LOCAL_PRINTERS[@]}" | jq -R . | jq -s .)
    else
      PICKED=()
      INVALID=0
      for n in $SELECTION; do
        if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "${#LOCAL_PRINTERS[@]}" ]; then
          echo "ERRO: numero invalido '$n' (use entre 1 e ${#LOCAL_PRINTERS[@]})."
          INVALID=1
          break
        fi
        PICKED+=("${LOCAL_PRINTERS[$((n-1))]}")
      done
      [ "$INVALID" = "1" ] && continue
      PRINTERS_ARRAY=$(printf '%s\n' "${PICKED[@]}" | jq -R . | jq -s .)
    fi

    echo ""
    echo "Impressoras selecionadas:"
    echo "$PRINTERS_ARRAY" | jq -r '.[]' | sed 's/^/  - /'
    echo ""
    printf "Confirma? [enter = sim / a = alterar]: "
    read -r CONFIRM < /dev/tty
    case "$CONFIRM" in
      ""|s|S|y|Y) break ;;
      a|A) continue ;;
      *) echo "Resposta invalida, voltando pra selecao."; continue ;;
    esac
  done
fi

jq -n --arg key "$ABLY_KEY" --argjson printers "$PRINTERS_ARRAY" '{
  ably: { key: $key, channel: "printing" },
  printers: $printers
}' > "$PROJECT_DIR/config.json"

echo ">> config.json atualizado em $PROJECT_DIR/config.json"

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

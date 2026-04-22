#!/usr/bin/env bash
#
# Atualiza MGprint em maquinas Ubuntu 24.04.
# Roda como usuario 'usuario' (nao como root). Usa sudo apenas pro supervisor.
#
# Uso: bash atualizar.sh

set -euo pipefail

# detecta diretorio do projeto (varia entre maquinas)
for DIR in /opt/www/MGprint /opt/MGprint; do
  if [ -d "$DIR/.git" ]; then
    PROJECT_DIR="$DIR"
    break
  fi
done

if [ -z "${PROJECT_DIR:-}" ]; then
  echo "ERRO: nao encontrei MGprint em /opt/www/MGprint nem em /opt/MGprint" >&2
  exit 1
fi

echo ">> Projeto: $PROJECT_DIR"
cd "$PROJECT_DIR"

# confere node >= 16 (ably@2 exige)
NODE_MAJOR=$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0)
if [ "$NODE_MAJOR" -lt 16 ]; then
  echo "ERRO: Node v$NODE_MAJOR detectado. Ably v2 exige Node >=16. Atualize a distro antes." >&2
  exit 1
fi
echo ">> Node $(node -v) OK"

# garante working tree limpa antes de pull
if [ -n "$(git status --porcelain)" ]; then
  echo "ERRO: ha alteracoes locais nao commitadas em $PROJECT_DIR." >&2
  echo "Resolva manualmente (git status) antes de rodar este script." >&2
  exit 1
fi

echo ">> git pull"
git pull --ff-only

echo ">> limpando node_modules e package-lock.json"
rm -rf node_modules package-lock.json

echo ">> npm install"
npm install

echo ">> reiniciando supervisor"
sudo service supervisor stop
sudo service supervisor start

echo ">> pronto. mostrando log (Ctrl+C para sair):"
sudo tail -f /var/log/supervisor/MGprint.log

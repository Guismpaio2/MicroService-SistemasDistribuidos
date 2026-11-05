#!/usr/bin/env bash
# Sobe o laboratório inteiro (3 microsserviços + frontend) com um único comando.
#
#   ./iniciar.sh
#
# - Instala as dependências na primeira execução (se node_modules não existir).
# - Avisa se alguma porta necessária já estiver em uso.
# - Ctrl+C encerra todos os processos de uma vez.

set -euo pipefail
cd "$(dirname "$0")"

PORTAS=(3000 3001 3002 5173)

# ---- 1) pré-requisitos ----
command -v node >/dev/null || { echo "Node.js não encontrado. Instale a versão 22.15 ou superior."; exit 1; }
VERSAO_MAIOR=$(node -p "process.versions.node.split('.')[0]")
if [ "$VERSAO_MAIOR" -lt 22 ]; then
  echo "Node $(node -v) detectado; é necessário 22.15 ou superior."; exit 1
fi

# ---- 2) portas livres? ----
if command -v lsof >/dev/null; then
  OCUPADAS=()
  for porta in "${PORTAS[@]}"; do
    if lsof -nP -iTCP:"$porta" -sTCP:LISTEN >/dev/null 2>&1; then OCUPADAS+=("$porta"); fi
  done
  if [ ${#OCUPADAS[@]} -gt 0 ]; then
    echo "As portas ${OCUPADAS[*]} já estão em uso por outro programa."
    echo "Encerre-o ou veja a seção 'Problemas comuns' no readme.md para usar outras portas."
    exit 1
  fi
fi

# ---- 3) dependências ----
if [ ! -d backend/api-gateway/node_modules ] || [ ! -d backend/produtos-service/node_modules ] \
   || [ ! -d backend/pedidos-service/node_modules ] || [ ! -d backend/node_modules ]; then
  echo ">> Instalando dependências do backend..."
  (cd backend && npm install && npm run install:all)
fi
if [ ! -d frontend/node_modules ]; then
  echo ">> Instalando dependências do frontend..."
  (cd frontend && npm install)
fi

# ---- 4) subir tudo ----
PIDS=()
encerrar() {
  echo; echo ">> Encerrando..."
  for pid in "${PIDS[@]}"; do kill "$pid" 2>/dev/null || true; done
  wait 2>/dev/null || true
}
trap encerrar INT TERM EXIT

(cd backend && npm run dev) &
PIDS+=($!)
(cd frontend && npm run dev) &
PIDS+=($!)

echo
echo "  Frontend:     http://localhost:5173"
echo "  API Gateway:  http://localhost:3000   (health: http://localhost:3000/health)"
echo "  Ctrl+C para encerrar tudo."
echo

wait

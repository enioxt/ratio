#!/usr/bin/env bash
# Deploy Ratio to Hetzner VPS
# Usage: bash scripts/deploy-vps.sh [--skip-build]
set -euo pipefail

VPS="root@204.168.217.125"
SSH_KEY="$HOME/.ssh/hetzner_ed25519"
REMOTE_DIR="/opt/apps/ratio"
DATA_DIR="/opt/data/ratio"

echo "=== Ratio VPS Deploy ==="

# 1. Create remote dirs
echo "[1/5] Preparing remote directories..."
ssh -i "$SSH_KEY" "$VPS" "
  mkdir -p $REMOTE_DIR $DATA_DIR/lancedb_store $DATA_DIR/data $DATA_DIR/logs
"

# 2. Rsync source (exclude heavy local artifacts)
echo "[2/5] Syncing source..."
rsync -az --progress \
  --exclude '.venv' \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude 'lancedb_store/' \
  --exclude 'data/' \
  --exclude 'logs/' \
  --exclude '_cache/' \
  --exclude '.git' \
  --exclude 'test_cases/' \
  -e "ssh -i $SSH_KEY" \
  "$(dirname "$(dirname "$0")")/" \
  "$VPS:$REMOTE_DIR/"

# 3. Copy .env (must exist locally)
if [ -f "$(dirname "$(dirname "$0")")/.env" ]; then
  echo "[3/5] Copying .env..."
  rsync -az -e "ssh -i $SSH_KEY" \
    "$(dirname "$(dirname "$0")")/.env" \
    "$VPS:$REMOTE_DIR/.env"
else
  echo "[3/5] WARNING: no .env found — copy .env.example to .env and fill in keys"
fi

# 4. Build and start
if [[ "${1:-}" != "--skip-build" ]]; then
  echo "[4/5] Building Docker image (may take ~5min on first run)..."
  ssh -i "$SSH_KEY" "$VPS" "
    cd $REMOTE_DIR
    docker compose -f docker-compose.vps.yml build --pull
  "
else
  echo "[4/5] Skipping build (--skip-build)"
fi

echo "[5/5] Starting containers..."
ssh -i "$SSH_KEY" "$VPS" "
  cd $REMOTE_DIR
  docker compose -f docker-compose.vps.yml up -d
  sleep 5
  docker compose -f docker-compose.vps.yml ps
"

echo ""
echo "=== Deploy complete ==="
echo "  API:      http://127.0.0.1:3085/health  (VPS internal)"
echo "  Frontend: http://127.0.0.1:3086/"
echo "  Add Caddy route for public access: ratio.egos.ia.br → 127.0.0.1:3086"
echo ""
echo "NOTE: LanceDB data not copied (too large for rsync)."
echo "  To enable RAG search, either:"
echo "  1. Run ingestion on VPS: docker exec ratio-api python -m backend.juris_update"
echo "  2. Or rsync lancedb_store from local: rsync -az lancedb_store/ $VPS:$DATA_DIR/lancedb_store/"
echo ""
echo "Escritório (multi-agent drafting) works without LanceDB data."

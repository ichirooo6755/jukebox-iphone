#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/relay-server"

if [[ ! -d .venv ]]; then
  python3 -m venv .venv
  .venv/bin/pip install -r requirements.txt
fi

PORT="${RELAY_PORT:-8780}"
echo "Jukebox relay: http://127.0.0.1:${PORT}"
echo "PWA + remote join: http://127.0.0.1:${PORT}/?room=<CODE>"
echo "Secrets.plist RELAY_BASE_URL=http://127.0.0.1:${PORT}"
exec .venv/bin/uvicorn main:app --host 0.0.0.0 --port "$PORT" --reload

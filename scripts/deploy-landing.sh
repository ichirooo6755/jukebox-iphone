#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LANDING="$ROOT/web/landing"

cd "$LANDING"

if ! command -v netlify >/dev/null 2>&1; then
  echo "Netlify CLI が見つかりません: npm install -g netlify-cli"
  exit 1
fi

echo "Deploying Jukebox landing page from $LANDING"
netlify deploy --prod --dir .

URL="$(netlify status --json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("url",""))' 2>/dev/null || true)"
if [[ -n "$URL" ]]; then
  echo ""
  echo "Deployed: $URL"
  echo "QR URL example: ${URL}/?host=http://192.168.x.x:8765"
  echo ""
  echo "Secrets.plist / .env に設定:"
  echo "JUKEBOX_JOIN_URL=$URL"
fi

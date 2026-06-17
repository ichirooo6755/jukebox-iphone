#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS_DIR="$ROOT/secrets"

SPOTIFY_FILE="$SECRETS_DIR/spotify_auth.json"
GOOGLE_FILE="$SECRETS_DIR/google_auth.json"
ENV_FILE="$ROOT/.env"
SECRETS_PLIST="$ROOT/JukeboxHost/Resources/Secrets.plist"

read_spotify_client_id() {
  awk '/^Client ID$/{getline; print; exit}' "$SPOTIFY_FILE" | tr -d '\r'
}

read_spotify_client_secret() {
  awk '/^Client secret$/{getline; print; exit}' "$SPOTIFY_FILE" | tr -d '\r'
}

read_google_client_id() {
  python3 - "$GOOGLE_FILE" <<'PY'
import json, sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text())
print(data.get("web", {}).get("client_id", ""))
PY
}

read_google_client_secret() {
  python3 - "$GOOGLE_FILE" <<'PY'
import json, sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text())
print(data.get("web", {}).get("client_secret", ""))
PY
}

read_youtube_api_key() {
  if [[ -f "$ENV_FILE" ]]; then
    local line
    line="$(grep -E '^YOUTUBE_API_KEY=' "$ENV_FILE" | tail -1 || true)"
    if [[ -n "$line" ]]; then
      echo "${line#*=}"
      return
    fi
  fi
  echo "${YOUTUBE_API_KEY:-}"
}

main() {
  local missing=0
  [[ -f "$SPOTIFY_FILE" ]] || { echo "Missing: $SPOTIFY_FILE" >&2; missing=1; }
  [[ -f "$GOOGLE_FILE" ]] || { echo "Missing: $GOOGLE_FILE" >&2; missing=1; }
  if [[ "$missing" -eq 1 ]]; then
    echo "Copy templates from secrets.example/ to secrets/ and fill in your credentials." >&2
    exit 1
  fi

  local spotify_id spotify_secret youtube_id youtube_secret youtube_api_key
  spotify_id="$(read_spotify_client_id)"
  spotify_secret="$(read_spotify_client_secret)"
  youtube_id="$(read_google_client_id)"
  youtube_secret="$(read_google_client_secret)"
  youtube_api_key="$(read_youtube_api_key)"

  if [[ -z "$spotify_id" || -z "$spotify_secret" ]]; then
    echo "Could not parse Spotify credentials from $SPOTIFY_FILE" >&2
    exit 1
  fi
  if [[ -z "$youtube_id" || -z "$youtube_secret" ]]; then
    echo "Could not parse YouTube credentials from $GOOGLE_FILE" >&2
    exit 1
  fi

  cat >"$ENV_FILE" <<EOF
# Imported from secrets/spotify_auth.json and secrets/google_auth.json (do not commit)
SPOTIFY_CLIENT_ID=${spotify_id}
SPOTIFY_CLIENT_SECRET=${spotify_secret}
YOUTUBE_API_KEY=${youtube_api_key}
YOUTUBE_CLIENT_ID=${youtube_id}
YOUTUBE_CLIENT_SECRET=${youtube_secret}
EOF
  chmod 600 "$ENV_FILE"

  cat >"$SECRETS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>SPOTIFY_CLIENT_ID</key>
	<string>${spotify_id}</string>
	<key>SPOTIFY_CLIENT_SECRET</key>
	<string>${spotify_secret}</string>
	<key>YOUTUBE_API_KEY</key>
	<string>${youtube_api_key}</string>
	<key>YOUTUBE_CLIENT_ID</key>
	<string>${youtube_id}</string>
	<key>YOUTUBE_CLIENT_SECRET</key>
	<string>${youtube_secret}</string>
</dict>
</plist>
EOF
  chmod 600 "$SECRETS_PLIST"

  if [[ -x "$ROOT/scripts/sync-xcode-env.sh" ]]; then
    "$ROOT/scripts/sync-xcode-env.sh"
  fi

  echo "Imported credentials into .env, Secrets.plist, and Xcode Scheme."
  if [[ -z "$youtube_api_key" ]]; then
    echo "Note: YOUTUBE_API_KEY is empty. Add it to .env if you need public YouTube search."
  fi
}

main "$@"

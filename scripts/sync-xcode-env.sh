#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"
SCHEME_DIR="$ROOT/JukeboxHost.xcodeproj/xcshareddata/xcschemes"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — run scripts/configure-api-credentials.sh first." >&2
  exit 1
fi

cd "$ROOT"
xcodegen generate

python3 - "$ROOT/JukeboxHost.xcodeproj/xcshareddata/xcschemes" "$ENV_FILE" <<'PY'
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

scheme_dir = Path(sys.argv[1])
env_path = Path(sys.argv[2])

values = {}
for line in env_path.read_text().splitlines():
    line = line.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    values[key.strip()] = value.strip()

keys = [
    "SPOTIFY_CLIENT_ID",
    "SPOTIFY_CLIENT_SECRET",
    "YOUTUBE_API_KEY",
    "YOUTUBE_CLIENT_ID",
    "YOUTUBE_CLIENT_SECRET",
    "OAUTH_PUBLIC_REDIRECT_URI",
]

for scheme_path in scheme_dir.glob("*.xcscheme"):
    tree = ET.parse(scheme_path)
    root = tree.getroot()
    launch = root.find("LaunchAction")
    if launch is None:
        continue
    env_vars = launch.find("EnvironmentVariables")
    if env_vars is None:
        env_vars = ET.SubElement(launch, "EnvironmentVariables")

    existing = {node.attrib.get("key"): node for node in env_vars.findall("EnvironmentVariable")}
    for key in keys:
        node = existing.get(key) or ET.SubElement(env_vars, "EnvironmentVariable")
        node.set("key", key)
        node.set("value", values.get(key, ""))
        node.set("isEnabled", "YES")

    tree.write(scheme_path, encoding="UTF-8", xml_declaration=True)
    print(f"Synced environment variables to {scheme_path}")
PY

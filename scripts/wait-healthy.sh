#!/usr/bin/env bash
# Attend que le service soit PRÊT (/ready) et, si demandé, qu'il affiche la version attendue.
#
# Usage : scripts/wait-healthy.sh [version_attendue]      ex. scripts/wait-healthy.sh v1.1.0
# Variables : BASE_URL (défaut http://localhost:8080), RETRIES (défaut 12), DELAY (défaut 5)
# Codes de sortie : 0 sain (et bonne version), 1 non sain ou mauvaise version.
set -euo pipefail

expected="${1:-}"
base="${BASE_URL:-http://localhost:8080}"
retries="${RETRIES:-12}"
delay="${DELAY:-5}"
last="aucune réponse"

for i in $(seq 1 "$retries"); do
  if curl -fsS --max-time 3 "$base/ready" >/dev/null 2>&1; then
    body="$(curl -fsS --max-time 3 "$base/version" 2>/dev/null || true)"
    if [[ -z "$expected" ]] || grep -Eq "\"version\": ?\"${expected//./\\.}\"" <<<"$body"; then
      echo "$body"
      echo "service sain${expected:+ (version $expected confirmée)}"
      exit 0
    fi
    last="version différente de $expected : $body"
  else
    last="/ready ne répond pas encore"
  fi
  echo "tentative $i/$retries : $last" >&2
  sleep "$delay"
done

echo "service non sain : $last" >&2
exit 1

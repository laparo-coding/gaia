#!/usr/bin/env bash
set -euo pipefail

ROLLBAR_API_URL="https://api.rollbar.com/api/1/item/"
PRIMARY_ENV_KEY="GAIA_ROLLBAR_ACCESS_TOKEN"
FALLBACK_ENV_KEY="ROLLBAR_ACCESS_TOKEN"
PROJECT_NAME="gaia"
KEYCHAIN_SERVICE="rollbar-gaia-post-server-item"
DEFAULT_ENV_FILE=".env.local"

usage() {
  cat <<'EOF'
Usage:
  scripts/rollbar-keychain-setup.sh [--token TOKEN] [--env-file PATH] [--keychain-service NAME]

Description:
  1) Liest den Rollbar Server-Token (gaia) aus --token, Env oder Env-Datei.
  2) Testet den Token gegen die Rollbar Ingest API.
  3) Speichert den Token bei Erfolg in der macOS Keychain.

Token-Reihenfolge:
  --token > $GAIA_ROLLBAR_ACCESS_TOKEN > $ROLLBAR_ACCESS_TOKEN > Env-Datei > interaktive Eingabe
EOF
}

trim_token() {
  local value="$1"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  printf '%s' "$(printf '%s' "$value" | tr -d '[:space:]')"
}

read_from_env_file() {
  local env_file="$1"
  local key="$2"
  if [[ ! -f "$env_file" ]]; then
    return 1
  fi

  local line
  line=$(grep -E "^[[:space:]]*${key}=" "$env_file" | tail -n 1 || true)
  if [[ -z "$line" ]]; then
    return 1
  fi

  local raw
  raw="${line#*=}"
  raw="${raw%%#*}"
  trim_token "$raw"
}

assert_dependencies() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "Fehler: curl ist nicht installiert." >&2
    exit 1
  fi

  if ! command -v security >/dev/null 2>&1; then
    echo "Fehler: macOS security CLI wurde nicht gefunden." >&2
    exit 1
  fi
}

TOKEN=""
ENV_FILE="$DEFAULT_ENV_FILE"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --token)
      TOKEN="${2:-}"
      shift 2
      ;;
    --env-file)
      ENV_FILE="${2:-}"
      shift 2
      ;;
    --keychain-service)
      KEYCHAIN_SERVICE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unbekanntes Argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

assert_dependencies

if [[ -z "$TOKEN" && -n "${GAIA_ROLLBAR_ACCESS_TOKEN:-}" ]]; then
  TOKEN="${GAIA_ROLLBAR_ACCESS_TOKEN}"
fi

if [[ -z "$TOKEN" && -n "${ROLLBAR_ACCESS_TOKEN:-}" ]]; then
  TOKEN="${ROLLBAR_ACCESS_TOKEN}"
fi

if [[ -z "$TOKEN" ]]; then
  TOKEN="$(read_from_env_file "$ENV_FILE" "$PRIMARY_ENV_KEY" || true)"
fi

if [[ -z "$TOKEN" ]]; then
  TOKEN="$(read_from_env_file "$ENV_FILE" "$FALLBACK_ENV_KEY" || true)"
fi

if [[ -z "$TOKEN" ]]; then
  read -r -s -p "Rollbar post_server_item Token fuer ${PROJECT_NAME} eingeben: " TOKEN
  echo ""
fi

TOKEN="$(trim_token "$TOKEN")"

if [[ -z "$TOKEN" ]]; then
  echo "Fehler: Kein Token gefunden." >&2
  exit 1
fi

payload=$(cat <<EOF
{"access_token":"${TOKEN}","data":{"environment":"development","level":"info","body":{"message":{"body":"${PROJECT_NAME} keychain setup probe"}}}}
EOF
)

response=$(curl -sS "$ROLLBAR_API_URL" -H "Content-Type: application/json" -d "$payload" || true)

if ! printf '%s' "$response" | tr -d '[:space:]' | grep -q '"err":0'; then
  echo "Fehler: Token-Test fehlgeschlagen." >&2
  echo "Rollbar Antwort: $response" >&2
  exit 1
fi

security add-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" -w "$TOKEN" -U >/dev/null
stored_token=$(security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" -w)

if [[ "$stored_token" != "$TOKEN" ]]; then
  echo "Fehler: Token konnte nicht korrekt aus der Keychain gelesen werden." >&2
  exit 1
fi

echo "Token-Test erfolgreich (err=0)."
echo "Token wurde in der Keychain gespeichert."
echo "Service: $KEYCHAIN_SERVICE"
echo ""
echo "Optional fuer die aktuelle Shell:"
echo "export GAIA_ROLLBAR_ACCESS_TOKEN=\"\$(security find-generic-password -a \"$USER\" -s \"$KEYCHAIN_SERVICE\" -w)\""

#!/usr/bin/env bash
set -euo pipefail

ROLLBAR_API_URL="https://api.rollbar.com/api/1/item/"
PRIMARY_ENV_KEY="GAIA_ROLLBAR_ACCESS_TOKEN"
FALLBACK_ENV_KEY="ROLLBAR_ACCESS_TOKEN"
PROJECT_NAME="gaia"
KEYCHAIN_SERVICE="rollbar-gaia-post-server-item"
DEFAULT_ENV_FILE=".env.local"
CURRENT_USER="${USER:-$(id -un 2>/dev/null || echo "$UID")}"

usage() {
  cat <<'EOF'
Usage:
  scripts/rollbar-keychain-setup.sh [--token TOKEN] [--env-file PATH] [--keychain-service NAME] [--non-interactive]

Description:
  1) Liest den Rollbar Server-Token (gaia) aus --token, Env oder Env-Datei.
  2) Testet den Token gegen die Rollbar Ingest API.
  3) Speichert den Token bei Erfolg in der macOS Keychain.

Token-Reihenfolge:
  --token > $GAIA_ROLLBAR_ACCESS_TOKEN > $ROLLBAR_ACCESS_TOKEN > Env-Datei > interaktive Eingabe

Optionen:
  --non-interactive    Keine interaktive Eingabe; Fehler, wenn kein Token gefunden wird.
EOF
}

# Strip surrounding quotes and whitespace from a token value.
trim_token() {
  local value="$1"
  # Remove surrounding whitespace first
  value="$(printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  # Strip one pair of surrounding double quotes
  if [[ "$value" == \"*\" ]]; then
    value="${value#\"}"
    value="${value%\"}"
  fi
  # Strip one pair of surrounding single quotes
  if [[ "$value" == \'*\' ]]; then
    value="${value#\'}"
    value="${value%\'}"
  fi
  printf '%s' "$value"
}

read_from_env_file() {
  local env_file="$1"
  local key="$2"
  if [[ ! -f "$env_file" ]]; then
    return 1
  fi

  local line
  # Match KEY= or KEY ="..." or KEY = value (whitespace around = allowed)
  line=$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$env_file" | tail -n 1 || true)
  if [[ -z "$line" ]]; then
    return 1
  fi

  local raw
  raw="${line#*=}"
  # Strip inline comments (only when preceded by whitespace or start)
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

# Escape a string for safe inclusion in a JSON string value.
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"    # backslash
  s="${s//\"/\\\"}"     # double quote
  s="${s//$'\n'/\\n}"   # newline
  s="${s//$'\r'/\\r}"   # carriage return
  s="${s//$'\t'/\\t}"   # tab
  printf '%s' "$s"
}

TOKEN=""
ENV_FILE="$DEFAULT_ENV_FILE"
NON_INTERACTIVE=""

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
    --non-interactive)
      NON_INTERACTIVE="1"
      shift
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
  if [[ -n "$NON_INTERACTIVE" ]]; then
    echo "Fehler: Kein Token gefunden und --non-interactive gesetzt." >&2
    exit 1
  fi
  read -r -s -p "Rollbar post_server_item Token fuer ${PROJECT_NAME} eingeben: " TOKEN
  echo ""
fi

TOKEN="$(trim_token "$TOKEN")"

if [[ -z "$TOKEN" ]]; then
  echo "Fehler: Kein Token gefunden." >&2
  exit 1
fi

escaped_token="$(json_escape "$TOKEN")"
escaped_project="$(json_escape "$PROJECT_NAME")"
payload=$(cat <<EOF
{"access_token":"${escaped_token}","data":{"environment":"development","level":"info","body":{"message":{"body":"${escaped_project} keychain setup probe"}}}}
EOF
)

response=$(curl -sS "$ROLLBAR_API_URL" -H "Content-Type: application/json" -d "$payload" || true)

if ! printf '%s' "$response" | tr -d '[:space:]' | grep -q '"err":0'; then
  echo "Fehler: Token-Test fehlgeschlagen." >&2
  echo "Rollbar Antwort: $response" >&2
  exit 1
fi

security add-generic-password -a "$CURRENT_USER" -s "$KEYCHAIN_SERVICE" -w "$TOKEN" -U >/dev/null
stored_token=$(security find-generic-password -a "$CURRENT_USER" -s "$KEYCHAIN_SERVICE" -w)

if [[ "$stored_token" != "$TOKEN" ]]; then
  echo "Fehler: Token konnte nicht korrekt aus der Keychain gelesen werden." >&2
  exit 1
fi

echo "Token-Test erfolgreich (err=0)."
echo "Token wurde in der Keychain gespeichert."
echo "Service: $KEYCHAIN_SERVICE"
echo ""
echo "Optional fuer die aktuelle Shell:"
echo "export GAIA_ROLLBAR_ACCESS_TOKEN=\"\$(security find-generic-password -a \"$CURRENT_USER\" -s \"$KEYCHAIN_SERVICE\" -w)\""

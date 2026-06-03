#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CODACY_CLI="$ROOT_DIR/.codacy/cli.sh"
SKIP_TRIVY=false
SWIFT_ONLY=false

# Standardmäßig nur Swift-Quellbereiche scannen, um Tool-Rauschen zu minimieren.
DEFAULT_PATHS=("Sources" "Tests")

if [[ ! -x "$CODACY_CLI" ]]; then
  echo "Codacy CLI nicht gefunden oder nicht ausführbar: $CODACY_CLI" >&2
  exit 1
fi

paths=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-trivy)
      SKIP_TRIVY=true
      shift
      ;;
    --swift-only)
      SWIFT_ONLY=true
      shift
      ;;
    -h|--help)
      echo "Verwendung: $0 [--skip-trivy] [--swift-only] [pfad ...]"
      echo "Beispiel: $0 --skip-trivy --swift-only"
      exit 0
      ;;
    *)
      paths+=("$1")
      shift
      ;;
  esac
done

if [[ "$SWIFT_ONLY" == true ]] && [[ ${#paths[@]} -eq 0 ]]; then
  SWIFT_ONLY_DEFAULT_PATHS=("Sources" "Tests/GaiaCoreTests" "Tests/GaiaFeatureCatalogTests")
  for candidate in "${SWIFT_ONLY_DEFAULT_PATHS[@]}"; do
    if [[ -d "$ROOT_DIR/$candidate" ]]; then
      paths+=("$candidate")
    fi
  done
fi

if [[ ${#paths[@]} -eq 0 ]]; then
  for candidate in "${DEFAULT_PATHS[@]}"; do
    if [[ -d "$ROOT_DIR/$candidate" ]]; then
      paths+=("$candidate")
    fi
  done
fi

if [[ ${#paths[@]} -eq 0 ]]; then
  echo "Keine gültigen Scan-Pfade gefunden." >&2
  exit 1
fi

echo "Starte Codacy Standard-Check in: ${paths[*]}"

if [[ "$SKIP_TRIVY" == true ]]; then
  echo "Hinweis: Trivy wird fuer diesen Lauf uebersprungen."
fi

if [[ "$SWIFT_ONLY" == true ]]; then
  echo "Hinweis: Swift-only Modus aktiv."
fi

for path in "${paths[@]}"; do
  echo "- Analysiere $path"
  if [[ "$SKIP_TRIVY" == true ]]; then
    (cd "$ROOT_DIR" && "$CODACY_CLI" analyze "$path" --format sarif --tool opengrep)
  else
    (cd "$ROOT_DIR" && "$CODACY_CLI" analyze "$path" --format sarif)
  fi
done

echo "Codacy Standard-Check abgeschlossen."
#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CODACY_CLI="$ROOT_DIR/.codacy/cli.sh"
TOOL_CONFIG="$ROOT_DIR/scripts/ci-cd/codacy-tools.conf"
SKIP_TRIVY=false
SWIFT_ONLY=false

# Standardmäßig nur Swift-Quellbereiche scannen, um Tool-Rauschen zu minimieren.
DEFAULT_PATHS=("Sources" "Tests")

# Load external tool-selection configuration if available. The config file
# is shell-sourceable and defines ESLINT_ROOTS, ESLINT_EXCLUDE_PATHS,
# ESLINT_EXTENSIONS, and TOOL_ORDER. If it is missing, sensible defaults
# (matching the original behavior) are used so the script never silently
# changes semantics.
if [[ -r "$TOOL_CONFIG" ]]; then
  # shellcheck source=/dev/null
  source "$TOOL_CONFIG"
else
  ESLINT_ROOTS=(app web client frontend ui)
  ESLINT_EXCLUDE_PATHS=("*/node_modules/*" "*/.next/*" "*/dist/*" "*/build/*")
  ESLINT_EXTENSIONS=(js cjs mjs jsx ts tsx vue svelte)
  TOOL_ORDER=(opengrep eslint trivy)
fi

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

if [[ "$SKIP_TRIVY" != true ]]; then
  # Work around intermittent mirror.gcr.io issues by preferring GHCR for Trivy DB.
  export TRIVY_DB_REPOSITORY="${TRIVY_DB_REPOSITORY:-ghcr.io/aquasecurity/trivy-db:2}"
  echo "Hinweis: Trivy DB Repository: $TRIVY_DB_REPOSITORY"
fi

resolve_tool_args() {
  local path="$1"
  local tools=()
  local saw_opengrep=false
  local saw_trivy=false

  # Walk the configured TOOL_ORDER so that reordering or adding new tools
  # in the config automatically affects the runtime selection.
  for tool in "${TOOL_ORDER[@]}"; do
    case "$tool" in
      opengrep)
        tools+=("$tool")
        saw_opengrep=true
        ;;
      eslint)
        if path_matches_eslint_root "$path" && path_has_eslint_files "$path"; then
          tools+=("$tool")
        fi
        ;;
      trivy)
        if [[ "$SKIP_TRIVY" != true ]]; then
          tools+=("$tool")
          saw_trivy=true
        fi
        ;;
      *)
        # Unknown tool in config: include it verbatim so future tools
        # work without script changes. Operators can extend TOOL_ORDER
        # safely.
        tools+=("$tool")
        ;;
    esac
  done

  # Defensive baseline: if the config did not declare opengrep or trivy
  # (and trivy is not explicitly skipped), add them so we never lose
  # coverage because of a misconfigured config.
  if [[ "$saw_opengrep" != true ]]; then
    tools+=(opengrep)
  fi
  if [[ "$saw_trivy" != true && "$SKIP_TRIVY" != true ]]; then
    tools+=(trivy)
  fi

  printf '%s\n' "${tools[@]}"
}

path_matches_eslint_root() {
  local path="$1"
  local root
  for root in "${ESLINT_ROOTS[@]}"; do
    case "$path" in
      "$root"|"$root"/*)
        return 0
        ;;
    esac
  done
  return 1
}

path_has_eslint_files() {
  local path="$1"
  local -a find_args=()
  local ext
  for ext in "${ESLINT_EXTENSIONS[@]}"; do
    find_args+=(-o -name "*.$ext")
  done
  # Remove the leading "-o" so the find predicate is well-formed.
  if [[ ${#find_args[@]} -gt 0 ]]; then
    find_args=("${find_args[@]:1}")
  fi

  local -a exclude_args=()
  local exclude
  for exclude in "${ESLINT_EXCLUDE_PATHS[@]}"; do
    exclude_args+=(-not -path "$exclude")
  done

  (cd "$ROOT_DIR" && find "$path" -type f \( "${find_args[@]}" \) "${exclude_args[@]}" -print -quit 2>/dev/null | grep -q .)
}

for path in "${paths[@]}"; do
  echo "- Analysiere $path"
  # The Codacy CLI processes the first --tool flag exclusively in a single
  # invocation. To get additive coverage (opengrep + eslint + trivy) we run
  # the analyzer once per tool, preserving a stable, documented order.
  tool_list=()
  while IFS= read -r tool_name; do
    [[ -z "$tool_name" ]] && continue
    tool_list+=("$tool_name")
  done < <(resolve_tool_args "$path")

  if [[ ${#tool_list[@]} -eq 0 ]]; then
    (cd "$ROOT_DIR" && "$CODACY_CLI" analyze "$path" --format sarif)
    continue
  fi

  for tool_name in "${tool_list[@]}"; do
    echo "  * Tool: $tool_name"
    (cd "$ROOT_DIR" && "$CODACY_CLI" analyze "$path" --format sarif --tool "$tool_name")
  done
done

echo "Codacy Standard-Check abgeschlossen."
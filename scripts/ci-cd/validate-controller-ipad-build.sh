#!/usr/bin/env bash
set -euo pipefail

# Default values can be overridden by env vars.
PROJECT_PATH="${PROJECT_PATH:-GaiaControllerApp.xcodeproj}"
SCHEME_NAME="${SCHEME_NAME:-GaiaControllerApp}"
DESTINATION="${DESTINATION:-generic/platform=iOS Simulator}"
VALIDATION_MODE="${VALIDATION_MODE:-single}"
IPAD_11_NAME="${IPAD_11_NAME:-iPad Pro 11-inch (M5)}"
IPAD_13_NAME="${IPAD_13_NAME:-iPad Pro 13-inch (M5)}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-10}"
XCODEBUILD_TIMEOUT_SECONDS="${XCODEBUILD_TIMEOUT_SECONDS:-180}"
XCODEBUILD_TERMINATION_GRACE_SECONDS="${XCODEBUILD_TERMINATION_GRACE_SECONDS:-5}"
SKIP_PROJECT_LIST="${SKIP_PROJECT_LIST:-0}"
LOG_DIR="${LOG_DIR:-/tmp/gaia-ipad-validation-logs}"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Missing project path: $PROJECT_PATH"
  echo "Set PROJECT_PATH to your .xcodeproj or replace with a workspace invocation."
  exit 1
fi

mkdir -p "$LOG_DIR"

resolve_simulator_id() {
  local device_name="$1"

  if [[ -z "$device_name" ]]; then
    echo ""
    return 0
  fi

  # Preferred path: parse simctl's JSON output. This avoids any shell-side
  # pattern interpolation and is safe for device names that contain
  # parentheses, brackets, dashes, or other regex meta-characters.
  if command -v python3 >/dev/null 2>&1; then
    xcrun simctl list devices available -j 2>/dev/null \
      | python3 -c '
import json
import sys

device_name = sys.argv[1]
payload = json.load(sys.stdin)
runtime_to_devices = payload.get("devices", {})
matched_udid = ""
for runtime, devices in runtime_to_devices.items():
    if not isinstance(devices, list):
        continue
    for device in devices:
        if not isinstance(device, dict):
            continue
        if device.get("name") == device_name and device.get("isAvailable", False):
            matched_udid = device.get("udid", "")
            if matched_udid:
                print(matched_udid)
                sys.exit(0)
sys.exit(0)
' "$device_name" 2>/dev/null
    return 0
  fi

  # Safe fallback when python3 is unavailable: use `grep -F` (fixed-string
  # match) so the device name is never interpreted as a regex. awk then
  # extracts the first 36-character hex UUID following the matched line.
  xcrun simctl list devices available 2>/dev/null \
    | grep -F -- "$device_name (" \
    | head -n 1 \
    | awk '{
        for (i = 1; i <= NF; i++) {
          if (length($i) == 36 && $i ~ /^[A-F0-9-]+$/) {
            print $i
            exit
          }
        }
      }'
}

run_xcodebuild_with_timeout() {
  local label="$1"
  local log_file="$2"
  shift 2

  echo "[${label}] Log file: $log_file"

  "$@" >"$log_file" 2>&1 &

  local pid=$!
  local elapsed=0
  while kill -0 "$pid" 2>/dev/null; do
    if ((elapsed >= XCODEBUILD_TIMEOUT_SECONDS)); then
      echo "[${label}] TIMED OUT after ${elapsed}s. Stopping xcodebuild."
      kill "$pid" 2>/dev/null || true

      local grace_elapsed=0
      while kill -0 "$pid" 2>/dev/null && ((grace_elapsed < XCODEBUILD_TERMINATION_GRACE_SECONDS)); do
        sleep 1
        grace_elapsed=$((grace_elapsed + 1))
      done

      if kill -0 "$pid" 2>/dev/null; then
        echo "[${label}] xcodebuild did not stop after ${XCODEBUILD_TERMINATION_GRACE_SECONDS}s; forcing termination."
        kill -9 "$pid" 2>/dev/null || true
      fi

      wait "$pid" 2>/dev/null || true
      echo "[${label}] Last log lines:"
      tail -n 80 "$log_file" || true
      return 124
    fi

    echo "[${label}] xcodebuild running (${elapsed}s elapsed, timeout ${XCODEBUILD_TIMEOUT_SECONDS}s)..."
    sleep "$HEARTBEAT_SECONDS"
    elapsed=$((elapsed + HEARTBEAT_SECONDS))
  done

  if ! wait "$pid"; then
    echo "[${label}] FAILED. Last log lines:"
    tail -n 80 "$log_file" || true
    return 1
  fi

  echo "[${label}] SUCCEEDED."
  return 0
}

validate_project_listing() {
  local log_file="$LOG_DIR/xcodebuild-list.log"

  echo "[project-list] Validating project listing before simulator builds."
  run_xcodebuild_with_timeout \
    "project-list" \
    "$log_file" \
    xcodebuild \
    -list \
    -project "$PROJECT_PATH"
}

run_build() {
  local label="$1"
  local destination_value="$2"
  local log_file="$LOG_DIR/${label// /_}.log"

  echo "[${label}] Starting build for destination: $destination_value"

  run_xcodebuild_with_timeout \
    "$label" \
    "$log_file" \
    xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME_NAME" \
    -destination "$destination_value" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build
}

if [[ "$SKIP_PROJECT_LIST" == "1" ]]; then
  echo "[project-list] Skipping project listing preflight because SKIP_PROJECT_LIST=1."
else
  validate_project_listing
fi

if [[ "$VALIDATION_MODE" == "dual-ipad" ]]; then
  ipad11_id="$(resolve_simulator_id "$IPAD_11_NAME")"
  ipad13_id="$(resolve_simulator_id "$IPAD_13_NAME")"

  if [[ -z "$ipad11_id" ]]; then
    echo "Unable to resolve simulator id for: $IPAD_11_NAME"
    exit 1
  fi

  if [[ -z "$ipad13_id" ]]; then
    echo "Unable to resolve simulator id for: $IPAD_13_NAME"
    exit 1
  fi

  run_build "ipad-11-inch" "platform=iOS Simulator,id=$ipad11_id"
  run_build "ipad-13-inch" "platform=iOS Simulator,id=$ipad13_id"
  echo "Dual iPad validation completed successfully."
  exit 0
fi

run_build "single" "$DESTINATION"

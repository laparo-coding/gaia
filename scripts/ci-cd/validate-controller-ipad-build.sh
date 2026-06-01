#!/usr/bin/env bash
set -euo pipefail

# Default values can be overridden by env vars.
PROJECT_PATH="${PROJECT_PATH:-GaiaControllerApp.xcodeproj}"
SCHEME_NAME="${SCHEME_NAME:-GaiaControllerApp}"
DESTINATION="${DESTINATION:-generic/platform=iOS Simulator}"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Missing project path: $PROJECT_PATH"
  echo "Set PROJECT_PATH to your .xcodeproj or replace with a workspace invocation."
  exit 1
fi

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_NAME" \
  -destination "$DESTINATION" \
  build

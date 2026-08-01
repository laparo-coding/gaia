#!/usr/bin/env bash
set -euo pipefail

# Validates the GaiaControllerApp build via SwiftPM.
# Replaces the former xcodebuild-based validation (removed along with .xcodeproj).

SDK_NAME="${SDK_NAME:-iphoneos}"
DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET:-16.0}"
ARCHITECTURE="${ARCHITECTURE:-arm64}"

# Validate inputs
if ! [[ "$DEPLOYMENT_TARGET" =~ ^[0-9]+\.[0-9]+$ ]]; then
  echo "Error: DEPLOYMENT_TARGET must be a version number (e.g. 16.0), got '${DEPLOYMENT_TARGET}'."
  exit 1
fi
if ! [[ "$ARCHITECTURE" =~ ^(arm64)$ ]]; then
  echo "Error: ARCHITECTURE must be a valid architecture string (e.g. arm64), got '${ARCHITECTURE}'."
  exit 1
fi

TRIPLE="${ARCHITECTURE}-apple-ios${DEPLOYMENT_TARGET}"

SDK_PATH="$(xcrun --sdk "$SDK_NAME" --show-sdk-path 2>/dev/null)" || {
  echo "Error: xcrun failed to resolve SDK path for '${SDK_NAME}'. Is Xcode installed?"
  exit 1
}

if [[ -z "$SDK_PATH" || ! -d "$SDK_PATH" ]]; then
  echo "Error: Unable to resolve the ${SDK_NAME} SDK path."
  exit 1
fi

echo "Validating GaiaControllerApp for ${TRIPLE} with SDK: ${SDK_PATH}"

if swift build \
  --product GaiaControllerApp \
  --triple "$TRIPLE" \
  --sdk "$SDK_PATH" \
  -Xcc -target \
  -Xcc "$TRIPLE" \
  -Xcc -miphoneos-version-min="$DEPLOYMENT_TARGET" \
  -Xcc -isysroot \
  -Xcc "$SDK_PATH"; then
  echo "Validation PASSED."
else
  echo "Validation FAILED."
  exit 1
fi

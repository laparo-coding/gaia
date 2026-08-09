#!/usr/bin/env bash
set -euo pipefail

SDK_NAME="${SDK_NAME:-iphoneos}"
DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET:-16.0}"
ARCHITECTURE="${ARCHITECTURE:-arm64}"

# Input validation
if [[ ! "$DEPLOYMENT_TARGET" =~ ^[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: DEPLOYMENT_TARGET must be a version string (e.g. 16.0), got '${DEPLOYMENT_TARGET}'"
  exit 1
fi

# Determine platform and validate SDK/architecture combination
case "$SDK_NAME" in
  iphoneos)
    if [[ "$ARCHITECTURE" != "arm64" ]]; then
      echo "ERROR: ARCHITECTURE '${ARCHITECTURE}' is not supported for SDK '${SDK_NAME}'. Only arm64 is valid for device builds."
      exit 1
    fi
    TRIPLE="${ARCHITECTURE}-apple-ios${DEPLOYMENT_TARGET}"
    DEPLOYMENT_FLAG="-miphoneos-version-min"
    ;;
  iphonesimulator)
    if [[ ! "$ARCHITECTURE" =~ ^(arm64|x86_64)$ ]]; then
      echo "ERROR: ARCHITECTURE must be arm64 or x86_64 for simulator builds, got '${ARCHITECTURE}'"
      exit 1
    fi
    TRIPLE="${ARCHITECTURE}-apple-ios${DEPLOYMENT_TARGET}-simulator"
    DEPLOYMENT_FLAG="-mios-simulator-version-min"
    ;;
  *)
    echo "ERROR: SDK_NAME must be 'iphoneos' or 'iphonesimulator', got '${SDK_NAME}'"
    exit 1
    ;;
esac

SDK_PATH="$(xcrun --sdk "$SDK_NAME" --show-sdk-path 2>/dev/null)" || {
  echo "ERROR: Failed to resolve SDK path for '${SDK_NAME}'. Is the SDK installed?"
  exit 1
}

if [[ -z "$SDK_PATH" || ! -d "$SDK_PATH" ]]; then
  echo "ERROR: Resolved SDK path is empty or does not exist: '${SDK_PATH}'"
  exit 1
fi

echo "Building for ${TRIPLE} with SDK: ${SDK_PATH}"

swift build \
  --triple "$TRIPLE" \
  --sdk "$SDK_PATH" \
  -Xcc -isysroot \
  -Xcc "$SDK_PATH" \
  -Xcc -target \
  -Xcc "$TRIPLE" \
  -Xcc "${DEPLOYMENT_FLAG}=${DEPLOYMENT_TARGET}"
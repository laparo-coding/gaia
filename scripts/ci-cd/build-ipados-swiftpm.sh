#!/usr/bin/env bash
set -euo pipefail

SDK_NAME="${SDK_NAME:-iphoneos}"
DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET:-16.0}"
ARCHITECTURE="${ARCHITECTURE:-arm64}"
TRIPLE="${ARCHITECTURE}-apple-ios${DEPLOYMENT_TARGET}"

SDK_PATH="$(xcrun --sdk "$SDK_NAME" --show-sdk-path)"

if [[ -z "$SDK_PATH" || ! -d "$SDK_PATH" ]]; then
  echo "Unable to resolve the ${SDK_NAME} SDK path."
  exit 1
fi

echo "Building for ${TRIPLE} with SDK: ${SDK_PATH}"

swift build \
  --triple "$TRIPLE" \
  --sdk "$SDK_PATH" \
  -Xcc -isysroot \
  -Xcc "$SDK_PATH"
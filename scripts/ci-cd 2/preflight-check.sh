#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  IOS_TEAM_ID
  IOS_BUNDLE_ID
  IOS_CERTIFICATE_BASE64
  IOS_CERTIFICATE_PASSWORD
  IOS_PROVISIONING_PROFILE_BASE64
  IOS_KEYCHAIN_PASSWORD
)

missing=0
for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Missing required variable: $var"
    missing=1
  fi
done

if [[ $missing -ne 0 ]]; then
  echo "Preflight failed: missing signing inputs"
  exit 1
fi

echo "Preflight checks passed"

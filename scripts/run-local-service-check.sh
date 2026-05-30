#!/usr/bin/env zsh

set -euo pipefail

# Override env file locations with HEMERA_ENV_FILE and AITHER_ENV_FILE when
# sibling-repository defaults are not applicable.

script_dir=${0:A:h}
repo_root=${script_dir:h}
hemera_env_file="${HEMERA_ENV_FILE:-${repo_root:h}/hemera/.env.local}"
aither_env_file="${AITHER_ENV_FILE:-${repo_root:h}/aither/.env.local}"

if [[ ! -f "$hemera_env_file" ]]; then
	print -u2 "Missing Hemera env file: $hemera_env_file"
	exit 1
fi

if [[ ! -f "$aither_env_file" ]]; then
	print -u2 "Missing Aither env file: $aither_env_file"
	exit 1
fi

hemera_service_api_key=$(awk 'match($0,/^[[:space:]]*(export[[:space:]]+)?HEMERA_SERVICE_API_KEY[[:space:]]*=/){print substr($0, index($0, "=")+1)}' "$hemera_env_file" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')
aither_sync_token=$(awk 'match($0,/^[[:space:]]*(export[[:space:]]+)?AITHER_SYNC_TOKEN[[:space:]]*=/){print substr($0, index($0, "=")+1)}' "$aither_env_file" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')

if [[ -z "$hemera_service_api_key" ]]; then
	print -u2 "HEMERA_SERVICE_API_KEY is missing in $hemera_env_file"
	exit 1
fi

if [[ -z "$aither_sync_token" ]]; then
	print -u2 "AITHER_SYNC_TOKEN is missing in $aither_env_file"
	exit 1
fi

cd "$repo_root"
HEMERA_SERVICE_API_KEY="$hemera_service_api_key" \
AITHER_SYNC_TOKEN="$aither_sync_token" \
swift run GaiaCLI service-check --json "$@"
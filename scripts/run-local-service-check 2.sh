#!/usr/bin/env zsh

set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h}
hemera_env_file="${repo_root:h}/hemera/.env.local"
aither_env_file="${repo_root:h}/aither/.env.local"

if [[ ! -f "$hemera_env_file" ]]; then
	print -u2 "Missing Hemera env file: $hemera_env_file"
	exit 1
fi

if [[ ! -f "$aither_env_file" ]]; then
	print -u2 "Missing Aither env file: $aither_env_file"
	exit 1
fi

extract_env_value() {
	local key="$1"
	local file="$2"
	awk 'match($0,/^[[:space:]]*(export[[:space:]]+)?'"$key"'[[:space:]]*=/){print substr($0, index($0, "=")+1)}' "$file" \
		| sed -e 's/[[:space:]]*#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e "s/^'//" -e "s/'$//" -e 's/^"//' -e 's/"$//'
}

hemera_service_api_key=$(extract_env_value "HEMERA_SERVICE_API_KEY" "$hemera_env_file")
aither_sync_token=$(extract_env_value "AITHER_SYNC_TOKEN" "$aither_env_file")

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
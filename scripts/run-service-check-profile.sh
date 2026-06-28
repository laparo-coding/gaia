#!/usr/bin/env zsh

set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h}

profile=${1:-}
if [[ -z "$profile" ]]; then
  print -u2 "Usage: ./scripts/run-service-check-profile.sh <profile> [-- <extra service-check args>]"
  print -u2 "Profiles:"
  print -u2 "  host-host-dev               (Gaia/Hemera/Aither on host, development)"
  print -u2 "  docker-host-dev             (Gaia in Docker, Hemera/Aither on host)"
  print -u2 "  host-prod-hemera-local-aither (Production Hemera Academy + local Aither)"
  exit 1
fi

shift
if [[ ${1:-} == "--" ]]; then
  shift
fi

case "$profile" in
  host-host-dev)
    env \
      GAIA_ENV=development \
      GAIA_HEMERA_BASE_URL=http://127.0.0.1:3000 \
      GAIA_AITHER_BASE_URL=http://127.0.0.1:3500 \
      swift run --package-path "$repo_root" GaiaCLI service-check --json "$@"
    ;;
  docker-host-dev)
    env \
      GAIA_ENV=development \
      GAIA_DOCKER_RUNTIME=true \
      GAIA_HEMERA_BASE_URL=http://host.docker.internal:3000 \
      GAIA_AITHER_BASE_URL=http://host.docker.internal:3500 \
      swift run --package-path "$repo_root" GaiaCLI service-check --json "$@"
    ;;
  host-prod-hemera-local-aither)
    env \
      GAIA_ENV=production \
      GAIA_HEMERA_BASE_URL=https://www.hemera.academy \
      GAIA_AITHER_BASE_URL=http://127.0.0.1:3500 \
      swift run --package-path "$repo_root" GaiaCLI service-check --json "$@"
    ;;
  *)
    print -u2 "Unknown profile: $profile"
    print -u2 "Run without args to see available profiles."
    exit 1
    ;;
esac

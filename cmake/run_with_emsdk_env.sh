#!/usr/bin/env bash
set -euo pipefail

emsdk_root="$1"
shift

if [[ ! -f "${emsdk_root}/emsdk_env.sh" ]]; then
    echo "emsdk_env.sh not found at ${emsdk_root}/emsdk_env.sh" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "${emsdk_root}/emsdk_env.sh"
exec "$@"

#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_PAT_FILE:?}"

if [[ ${1:-} == get ]]; then
  token=$(<"$GITHUB_PAT_FILE")
  printf 'password=%s\n' "$token"
fi

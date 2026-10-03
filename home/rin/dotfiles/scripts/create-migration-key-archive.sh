#!/usr/bin/env bash
set -euo pipefail

output=${1:-$HOME/Documents/Backups/sh1m3ji-migration-keys.tar.age}

sops_config=${SH1M3JI_SOPS_CONFIG:-}
if [[ -z "$sops_config" ]]; then
  for candidate in \
    "$PWD/.sops.yaml" \
    "$HOME/nixConfig/.sops.yaml" \
    "$HOME/nix-config/.sops.yaml"; do
    if [[ -f "$candidate" ]]; then
      sops_config=$candidate
      break
    fi
  done
fi

if [[ -z "$sops_config" || ! -f "$sops_config" ]]; then
  echo "migration-key-archive: could not find .sops.yaml" >&2
  exit 1
fi

mapfile -t recipients < <(
  sed -nE \
    's/^[[:space:]]*-[[:space:]]*&[^[:space:]]+[[:space:]]+(age1[^[:space:]]+)$/\1/p' \
    "$sops_config"
)

if (( ${#recipients[@]} < 2 )); then
  echo "migration-key-archive: expected both age recipients in $sops_config" >&2
  exit 1
fi

sources=(
  home/rin/.ssh
  home/rin/.gnupg
  run/secrets/rin/github-pat
  run/secrets/rin/modelapi-key
  run/secrets/rin/anymodel-key
  run/secrets/rin/ssh/company
  home/rin/.claude/.credentials.json
  home/rin/.codex/auth.json
)

for source in "${sources[@]}"; do
  if [[ ! -e "/$source" ]]; then
    echo "migration-key-archive: missing /$source" >&2
    exit 1
  fi
done

gpg_private_keys=(/home/rin/.gnupg/private-keys-v1.d/*.key)
if [[ ! -e "${gpg_private_keys[0]}" ]]; then
  echo "migration-key-archive: GnuPG private key files are missing" >&2
  exit 1
fi

if [[ ! -s /home/rin/.ssh/id_ed25519 || ! -s /home/rin/.ssh/id_ed25519.pub ]]; then
  echo "migration-key-archive: personal SSH keypair is missing" >&2
  exit 1
fi

age_args=()
for recipient in "${recipients[@]}"; do
  age_args+=(--recipient "$recipient")
done

umask 077
output_dir=$(dirname -- "$output")
mkdir -p -- "$output_dir"
temporary=$(mktemp --tmpdir="$output_dir" ".$(basename -- "$output").XXXXXXXX")
trap 'rm -f -- "$temporary"' EXIT HUP INT TERM

tar --create --file=- --directory=/ \
  --exclude='home/rin/.gnupg/**/.#*' \
  --exclude='home/rin/.gnupg/**/*.lock' \
  --exclude='home/rin/.gnupg/**/S.*' \
  --exclude='home/rin/.gnupg/gpg.conf' \
  --exclude='home/rin/.gnupg/gpg-agent.conf' \
  "${sources[@]}" \
  | age "${age_args[@]}" --output "$temporary"

mv -- "$temporary" "$output"
trap - EXIT HUP INT TERM

echo "Encrypted migration key archive: $output"
sha256sum -- "$output"

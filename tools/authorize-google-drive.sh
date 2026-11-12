#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Authorize the SOPS-managed personal Google OAuth client and store the
resulting rclone token directly in the SOPS ciphertext.

Usage:
  authorize-google-drive [--secrets-file ./secrets/secrets.yaml]

Run this as rin from a graphical session. The command uses an isolated
temporary rclone config and never prints the client secret or OAuth token.
EOF
}

secrets_file="$PWD/secrets/secrets.yaml"

while (( $# > 0 )); do
  case "$1" in
    --secrets-file)
      [[ $# -ge 2 ]] || {
        echo "authorize-google-drive: --secrets-file requires a value" >&2
        exit 2
      }
      secrets_file=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "authorize-google-drive: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ $EUID -eq 0 ]]; then
  echo "authorize-google-drive: run this as rin, not root" >&2
  exit 1
fi

if [[ ! -r "$secrets_file" ]]; then
  echo "authorize-google-drive: encrypted secrets file is not readable: $secrets_file" >&2
  exit 1
fi

secrets_file=$(realpath -e -- "$secrets_file")
runtime_parent="${XDG_RUNTIME_DIR:-/tmp}"
runtime_dir=$(mktemp -d "$runtime_parent/authorize-google-drive.XXXXXXXX")
chmod 0700 "$runtime_dir"

cleanup() {
  case "$runtime_dir" in
    "$runtime_parent"/authorize-google-drive.*) rm -rf -- "$runtime_dir" ;;
    *) echo "authorize-google-drive: refusing unexpected cleanup path: $runtime_dir" >&2 ;;
  esac
}
trap cleanup EXIT HUP INT TERM

rclone_config="$runtime_dir/rclone.conf"
config_dump="$runtime_dir/rclone.json"
sops_value="$runtime_dir/sops-token-value.json"
client_id="$runtime_dir/google-drive-client-id"
client_secret="$runtime_dir/google-drive-client-secret"

sops decrypt --extract '["rin"]["google-drive-client-id"]' "$secrets_file" >"$client_id"
sops decrypt --extract '["rin"]["google-drive-client-secret"]' "$secrets_file" >"$client_secret"
chmod 0600 "$client_id" "$client_secret"

if [[ ! -s "$client_id" || ! -s "$client_secret" ]]; then
  echo "authorize-google-drive: the personal OAuth client fields are empty" >&2
  exit 1
fi

if ! grep -Eq '\.apps\.googleusercontent\.com$' "$client_id"; then
  echo "authorize-google-drive: the client ID is not a Google desktop OAuth client ID" >&2
  exit 1
fi

{
  printf '[gdrive]\n'
  printf 'type = drive\n'
  printf 'scope = drive\n'
  printf 'client_id = '
  tr -d '\n' <"$client_id"
  printf '\nclient_secret = '
  tr -d '\n' <"$client_secret"
  printf '\n'
} >"$rclone_config"
chmod 0600 "$rclone_config"

echo "A browser window will open for Google authorization."
echo "Use the Google account whose Drive will hold NixBackups/sh1m3ji."

rclone --config "$rclone_config" --auto-confirm config reconnect gdrive:

if ! rclone --config "$rclone_config" about gdrive: >/dev/null; then
  echo "authorize-google-drive: the new token could not access Google Drive" >&2
  exit 1
fi

rclone --config "$rclone_config" config dump >"$config_dump"
chmod 0600 "$config_dump"

if ! jq -e '
  .gdrive.type == "drive"
  and (.gdrive.client_id | type == "string" and length > 0)
  and (.gdrive.client_secret | type == "string" and length > 0)
  and (
    .gdrive.token
    | fromjson
    | type == "object"
      and (.access_token | type == "string" and length > 0)
      and (.refresh_token | type == "string" and length > 0)
  )
' "$config_dump" >/dev/null; then
  echo "authorize-google-drive: rclone did not return valid OAuth token JSON" >&2
  exit 1
fi

jq -c '.gdrive.token' "$config_dump" >"$sops_value"
chmod 0600 "$sops_value"
sops set --value-stdin "$secrets_file" '["rin"]["google-drive-token"]' <"$sops_value"

echo "The personal-client Google authorization was stored in SOPS."
echo "Review the encrypted diff, rebuild, and retry the manual snapshot."

#!/usr/bin/env bash
set -euo pipefail

: "${SH1M3JI_DEFAULT_SECRETS_FILE:?}"
: "${SH1M3JI_RESTIC_REPOSITORY:?}"
: "${SH1M3JI_RESTIC_HOSTNAME:?}"
: "${SH1M3JI_RCLONE_PROGRAM:?}"

usage() {
  cat <<'EOF'
Usage: restore-sh1m3ji --target /mnt --age-key KEY [options]

Options:
  --secrets-file FILE   Encrypted SOPS file packaged by the flake by default
  --snapshot ID         Snapshot ID, or latest (default)
  --dry-run             Ask Restic to check the restore without writing files
  --yes                 Skip the final RESTORE confirmation
  -h, --help            Show this help
EOF
}

target=
age_key=
secrets_file=$SH1M3JI_DEFAULT_SECRETS_FILE
requested_snapshot=latest
dry_run=false
assume_yes=false

while (( $# > 0 )); do
  case "$1" in
    --target|--age-key|--secrets-file|--snapshot)
      [[ $# -ge 2 ]] || {
        echo "restore: $1 requires a value" >&2
        exit 2
      }
      case "$1" in
        --target) target=$2 ;;
        --age-key) age_key=$2 ;;
        --secrets-file) secrets_file=$2 ;;
        --snapshot) requested_snapshot=$2 ;;
      esac
      shift 2
      ;;
    --dry-run) dry_run=true; shift ;;
    --yes) assume_yes=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "restore: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "restore: run as root so ownership and metadata can be restored" >&2
  exit 1
fi

if [[ -z "$target" || -z "$age_key" ]]; then
  echo "restore: --target and --age-key are required" >&2
  usage >&2
  exit 2
fi

target=$(realpath -m -- "$target")
if [[ "$target" == / || ! -d "$target/home" ]]; then
  echo "restore: target must be an installed tree with a home mount" >&2
  exit 1
fi

if ! mountpoint --quiet -- "$target/home"; then
  echo "restore: $target/home is not a distinct mounted filesystem" >&2
  exit 1
fi

age_key=$(realpath -e -- "$age_key")
secrets_file=$(realpath -e -- "$secrets_file")

runtime_dir=$(mktemp -d /run/restore-sh1m3ji.XXXXXXXX)
chmod 0700 "$runtime_dir"
trap 'rm -rf -- "$runtime_dir"' EXIT HUP INT TERM

extract_secret() {
  local expression=$1
  local destination=$2

  SOPS_AGE_KEY_FILE="$age_key" sops decrypt --extract "$expression" "$secrets_file" >"$destination"
  chmod 0600 "$destination"
}

google_token="$runtime_dir/google-drive-token"
google_client_id="$runtime_dir/google-drive-client-id"
google_client_secret="$runtime_dir/google-drive-client-secret"
restic_password="$runtime_dir/restic-password"
rclone_config="$runtime_dir/rclone.conf"
snapshots_json="$runtime_dir/snapshots.json"

extract_secret '["rin"]["google-drive-token"]' "$google_token"
extract_secret '["rin"]["google-drive-client-id"]' "$google_client_id"
extract_secret '["rin"]["google-drive-client-secret"]' "$google_client_secret"
extract_secret '["rin"]["restic-password"]' "$restic_password"

if [[ "$(<"$google_token")" == AUTHORIZATION_REQUIRED ]]; then
  echo "restore: Google Drive authorization is still pending" >&2
  exit 1
fi

if ! jq -e '
  type == "object"
  and (.access_token | type == "string" and length > 0)
  and (.refresh_token | type == "string" and length > 0)
' "$google_token" >/dev/null; then
  echo "restore: Google Drive token is invalid" >&2
  exit 1
fi

for secret_file in "$google_client_id" "$google_client_secret" "$restic_password"; do
  if [[ ! -s "$secret_file" ]]; then
    echo "restore: an extracted credential is empty" >&2
    exit 1
  fi
done

{
  printf '[gdrive]\n'
  printf 'type = drive\n'
  printf 'scope = drive\n'
  printf 'client_id = '
  tr -d '\n' <"$google_client_id"
  printf '\nclient_secret = '
  tr -d '\n' <"$google_client_secret"
  printf '\ntoken = '
  tr -d '\n' <"$google_token"
  printf '\n'
} >"$rclone_config"
chmod 0600 "$rclone_config"

export RCLONE_CONFIG="$rclone_config"
export RCLONE_TPSLIMIT=8
export RCLONE_TPSLIMIT_BURST=8

if ! rclone about gdrive: >/dev/null; then
  echo "restore: Google Drive authentication or connectivity check failed" >&2
  exit 1
fi

restic_command=(
  restic
  --repo "$SH1M3JI_RESTIC_REPOSITORY"
  --password-file "$restic_password"
  --option "rclone.program=$SH1M3JI_RCLONE_PROGRAM"
)

if [[ "$requested_snapshot" == latest ]]; then
  "${restic_command[@]}" snapshots \
    --host "$SH1M3JI_RESTIC_HOSTNAME" \
    --latest 1 \
    --json >"$snapshots_json"
else
  "${restic_command[@]}" snapshots \
    --host "$SH1M3JI_RESTIC_HOSTNAME" \
    --json \
    "$requested_snapshot" >"$snapshots_json"
fi

snapshot_id=$(jq -er 'if length == 1 then .[0].id else empty end' "$snapshots_json")
snapshot_time=$(jq -r '.[0].time' "$snapshots_json")

printf 'Snapshot: %s\n' "$snapshot_id"
printf 'Created:  %s\n' "$snapshot_time"
printf 'Target:   %s\n' "$target"

restore_args=(restore "$snapshot_id" --target "$target")
if $dry_run; then
  restore_args+=(--dry-run --verbose=2)
else
  restore_args+=(--verbose=1)
fi

if ! $dry_run && ! $assume_yes; then
  printf 'Type RESTORE to continue: '
  read -r confirmation
  if [[ "$confirmation" != RESTORE ]]; then
    echo "restore: cancelled"
    exit 1
  fi
fi

"${restic_command[@]}" "${restore_args[@]}"
echo "restore: snapshot $snapshot_id completed successfully"

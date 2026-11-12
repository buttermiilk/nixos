#!/usr/bin/env bash
set -euo pipefail

: "${SH1M3JI_GOOGLE_DRIVE_TOKEN:?}"
: "${SH1M3JI_GOOGLE_DRIVE_CLIENT_ID:?}"
: "${SH1M3JI_GOOGLE_DRIVE_CLIENT_SECRET:?}"
: "${SH1M3JI_RCLONE_CONFIG:?}"

for secret_file in \
  "$SH1M3JI_GOOGLE_DRIVE_TOKEN" \
  "$SH1M3JI_GOOGLE_DRIVE_CLIENT_ID" \
  "$SH1M3JI_GOOGLE_DRIVE_CLIENT_SECRET"
do
  if [[ ! -s "$secret_file" ]]; then
    echo "rclone-config: a required Google Drive credential is unavailable" >&2
    exit 1
  fi
done

if grep -qx AUTHORIZATION_REQUIRED "$SH1M3JI_GOOGLE_DRIVE_TOKEN"; then
  echo "rclone-config: Google Drive authorization has not been completed" >&2
  exit 1
fi

if ! jq -e '
  type == "object"
  and (.access_token | type == "string" and length > 0)
  and (.refresh_token | type == "string" and length > 0)
' "$SH1M3JI_GOOGLE_DRIVE_TOKEN" >/dev/null; then
  echo "rclone-config: SOPS does not contain valid rclone OAuth token JSON" >&2
  exit 1
fi

config_dir=$(dirname "$SH1M3JI_RCLONE_CONFIG")
install -d -m 0700 "$config_dir"
temporary_config=$(mktemp "$config_dir/.rclone.conf.XXXXXXXX")
trap 'rm -f -- "$temporary_config"' EXIT HUP INT TERM

{
  printf '[gdrive]\n'
  printf 'type = drive\n'
  printf 'scope = drive\n'
  printf 'client_id = '
  tr -d '\n' <"$SH1M3JI_GOOGLE_DRIVE_CLIENT_ID"
  printf '\nclient_secret = '
  tr -d '\n' <"$SH1M3JI_GOOGLE_DRIVE_CLIENT_SECRET"
  printf '\ntoken = '
  tr -d '\n' <"$SH1M3JI_GOOGLE_DRIVE_TOKEN"
  printf '\n'
} >"$temporary_config"

if [[ -n ${SH1M3JI_R2_ACCESS_KEY_ID:-} \
  && -n ${SH1M3JI_R2_SECRET_ACCESS_KEY:-} \
  && -n ${SH1M3JI_R2_ENDPOINT:-} \
  && -n ${SH1M3JI_R2_BUCKET:-} \
  && -s $SH1M3JI_R2_ACCESS_KEY_ID \
  && -s $SH1M3JI_R2_SECRET_ACCESS_KEY \
  && -s $SH1M3JI_R2_ENDPOINT \
  && -s $SH1M3JI_R2_BUCKET ]]
then
  r2_endpoint=$(tr -d '\n' <"$SH1M3JI_R2_ENDPOINT")
  r2_endpoint="${r2_endpoint%/}"

  if [[ "$r2_endpoint" =~ ^https://[A-Za-z0-9.-]+\.r2\.cloudflarestorage\.com$ ]]; then
    {
      printf '\n[r2-s3]\n'
      printf 'type = s3\n'
      printf 'provider = Cloudflare\n'
      printf 'access_key_id = '
      tr -d '\n' <"$SH1M3JI_R2_ACCESS_KEY_ID"
      printf '\nsecret_access_key = '
      tr -d '\n' <"$SH1M3JI_R2_SECRET_ACCESS_KEY"
      printf '\nendpoint = %s\n' "$r2_endpoint"
      printf 'acl = private\n'
      printf 'no_check_bucket = true\n'
      printf '\n[r2]\n'
      printf 'type = alias\n'
      printf 'remote = r2-s3:'
      tr -d '\n' <"$SH1M3JI_R2_BUCKET"
      printf '\n'
    } >>"$temporary_config"
  else
    echo "rclone-config: ignoring invalid optional R2 endpoint" >&2
  fi
fi

chmod 0600 "$temporary_config"
mv -f -- "$temporary_config" "$SH1M3JI_RCLONE_CONFIG"
trap - EXIT HUP INT TERM

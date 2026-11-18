#!/usr/bin/env bash
set -euo pipefail

: "${SH1M3JI_R2_ACCESS_KEY_ID:?}"
: "${SH1M3JI_R2_SECRET_ACCESS_KEY:?}"
: "${SH1M3JI_R2_ENDPOINT:?}"

for secret_file in \
  "$SH1M3JI_R2_ACCESS_KEY_ID" \
  "$SH1M3JI_R2_SECRET_ACCESS_KEY" \
  "$SH1M3JI_R2_ENDPOINT"
do
  if [[ ! -r "$secret_file" || ! -s "$secret_file" ]]; then
    echo "aws-r2: a required R2 secret is unavailable" >&2
    exit 1
  fi
done

AWS_ACCESS_KEY_ID=$(tr -d '\n' <"$SH1M3JI_R2_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY=$(tr -d '\n' <"$SH1M3JI_R2_SECRET_ACCESS_KEY")
r2_endpoint=$(tr -d '\n' <"$SH1M3JI_R2_ENDPOINT")
r2_endpoint="${r2_endpoint%/}"

if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" ]]; then
  echo "aws-r2: a required R2 credential is empty" >&2
  exit 1
fi

# Match the endpoint accepted by the existing rclone R2 integration.
if [[ ! "$r2_endpoint" =~ ^https://[A-Za-z0-9.-]+\.r2\.cloudflarestorage\.com$ ]]; then
  echo "aws-r2: invalid R2 endpoint" >&2
  exit 1
fi

export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
# R2 uses static credentials; an inherited AWS session must not supply its token.
unset AWS_SESSION_TOKEN AWS_SECURITY_TOKEN AWS_PROFILE AWS_DEFAULT_PROFILE

exec aws --endpoint-url "$r2_endpoint" --region auto "$@"

#!/usr/bin/env bash
set -euo pipefail

# Usage: osu-lazer-settings FILE KEY=VALUE...
# Sets each KEY in an osu!lazer ini file (`Key = Value` lines) and leaves
# every other line alone. Missing keys are appended; a missing file is
# created with only these keys, and lazer fills in the rest on its next exit.
file=$1
shift

mkdir -p "$(dirname "$file")"
touch "$file"

tmp=$(mktemp "$file.XXXXXX")
trap 'rm -f "$tmp"' EXIT

awk '
  BEGIN {
    for (i = 1; i < ARGC; i++) {
      split(ARGV[i], kv, "=")
      key = kv[1]
      want[key] = substr(ARGV[i], length(key) + 2)
      order[++n] = key
      delete ARGV[i]
    }
  }
  {
    key = $0
    sub(/ = .*/, "", key)
    if (key in want) {
      print key " = " want[key]
      done[key] = 1
    } else {
      print
    }
  }
  END {
    for (i = 1; i <= n; i++)
      if (!(order[i] in done))
        print order[i] " = " want[order[i]]
  }
' "$@" <"$file" >"$tmp"

chmod --reference="$file" "$tmp"
mv "$tmp" "$file"
trap - EXIT

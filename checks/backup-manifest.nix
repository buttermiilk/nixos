# Sandbox test: create a fixture tree, back it up with restic, and verify that
# the manifest's paths/excludes produce the expected snapshot contents.
{
  pkgs,
  lib,
  manifest,
}:

let
  sources = lib.concatMapStringsSep " " lib.escapeShellArg manifest.paths;
  excludes = lib.concatMapStringsSep " " lib.escapeShellArg manifest.excludes;
in
pkgs.runCommand "backup-manifest-check"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.jq
      pkgs.restic
    ];
  }
  ''
    fixture="$TMPDIR/fixture"
    export HOME="$TMPDIR/home"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    export RESTIC_REPOSITORY="$TMPDIR/repository"
    export RESTIC_PASSWORD="fixture-only-password"

    mkdir -p \
      "$fixture/home/rin/Downloads" \
      "$fixture/home/rin/Documents/Dev/app/node_modules/dependency" \
      "$fixture/home/rin/Documents/Dev/app/src" \
      "$fixture/home/rin/Documents/Other/node_modules" \
      "$fixture/home/rin/Documents/osu/Data" \
      "$fixture/home/rin/Documents/osu/Logs" \
      "$fixture/home/rin/Documents/osu/Songs" \
      "$fixture/home/rin/Documents/Notes" \
      "$fixture/home/rin/Pictures/cache" \
      "$fixture/home/rin/Videos" \
      "$fixture/home/rin/.config/zen/default" \
      "$fixture/home/rin/.config/zen/profile" \
      "$fixture/home/rin/.config/gh" \
      "$fixture/home/rin/.config/.wrangler/config" \
      "$fixture/home/rin/.fly/logs" \
      "$fixture/home/rin/.gemini/antigravity-cli" \
      "$fixture/home/rin/.android" \
      "$fixture/home/rin/.config/obs-studio/basic/scenes" \
      "$fixture/home/rin/.codex/sessions/2026/08/26"

    touch \
      "$fixture/home/rin/Downloads/keep.txt" \
      "$fixture/home/rin/Documents/Dev/app/node_modules/dependency/drop.txt" \
      "$fixture/home/rin/Documents/Dev/app/src/keep.txt" \
      "$fixture/home/rin/Documents/Other/node_modules/keep.txt" \
      "$fixture/home/rin/Documents/osu/Data/drop.txt" \
      "$fixture/home/rin/Documents/osu/Logs/drop.txt" \
      "$fixture/home/rin/Documents/osu/Songs/keep.txt" \
      "$fixture/home/rin/Documents/Notes/keep.txt" \
      "$fixture/home/rin/Pictures/cache/drop.txt" \
      "$fixture/home/rin/Pictures/keep.txt" \
      "$fixture/home/rin/Videos/keep.txt" \
      "$fixture/home/rin/.config/zen/default/.keep" \
      "$fixture/home/rin/.config/zen/default/user.js" \
      "$fixture/home/rin/.config/zen/profile/.parentlock" \
      "$fixture/home/rin/.config/zen/profile/lock" \
      "$fixture/home/rin/.config/zen/profile/places.sqlite" \
      "$fixture/home/rin/.config/zen/profiles.ini" \
      "$fixture/home/rin/.config/gh/hosts.yml" \
      "$fixture/home/rin/.config/.wrangler/config/default.toml" \
      "$fixture/home/rin/.fly/config.yml" \
      "$fixture/home/rin/.fly/logs/drop.log" \
      "$fixture/home/rin/.gemini/antigravity-cli/antigravity-oauth-token" \
      "$fixture/home/rin/.android/adbkey" \
      "$fixture/home/rin/.android/adbkey.pub" \
      "$fixture/home/rin/.config/obs-studio/basic/scenes/Personal.json" \
      "$fixture/home/rin/.codex/auth.json" \
      "$fixture/home/rin/.codex/sessions/2026/08/26/session.jsonl"

    printf 'Signature: 8a477f597d28d172789f06886806bc55\n' \
      >"$fixture/home/rin/Pictures/cache/CACHEDIR.TAG"

    source_paths=()
    for source_path in ${sources}; do
      source_paths+=("$fixture$source_path")
    done

    exclude_args=()
    for exclude_path in ${excludes}; do
      exclude_args+=("--exclude=$fixture$exclude_path")
    done

    restic init >/dev/null
    restic backup \
      "''${source_paths[@]}" \
      "''${exclude_args[@]}" \
      --exclude-caches \
      --host ${lib.escapeShellArg manifest.hostname} \
      >/dev/null

    restic ls latest --json \
      | jq -r 'select(.struct_type == "node") | .path' \
      >"$TMPDIR/inventory"

    assert_present() {
      if ! grep -Fqx "$fixture$1" "$TMPDIR/inventory"; then
        echo "expected path missing from snapshot: $1" >&2
        exit 1
      fi
    }

    assert_absent() {
      if grep -Fq "$fixture$1" "$TMPDIR/inventory"; then
        echo "excluded path present in snapshot: $1" >&2
        exit 1
      fi
    }

    assert_present /home/rin/Downloads/keep.txt
    assert_present /home/rin/Documents/Dev/app/src/keep.txt
    assert_present /home/rin/Documents/Other/node_modules/keep.txt
    assert_present /home/rin/Documents/osu/Songs/keep.txt
    assert_present /home/rin/Documents/Notes/keep.txt
    assert_present /home/rin/Pictures/keep.txt
    assert_present /home/rin/Videos/keep.txt
    assert_present /home/rin/.config/zen/profile/places.sqlite
    assert_present /home/rin/.config/gh/hosts.yml
    assert_present /home/rin/.config/.wrangler/config/default.toml
    assert_present /home/rin/.fly/config.yml
    assert_present /home/rin/.gemini/antigravity-cli/antigravity-oauth-token
    assert_present /home/rin/.android/adbkey
    assert_present /home/rin/.android/adbkey.pub
    assert_present /home/rin/.config/obs-studio/basic/scenes/Personal.json
    assert_present /home/rin/.codex/auth.json
    assert_present /home/rin/.codex/sessions/2026/08/26/session.jsonl

    assert_absent /home/rin/Documents/Dev/app/node_modules
    assert_absent /home/rin/Documents/osu/Data
    assert_absent /home/rin/Documents/osu/Logs
    assert_absent /home/rin/Pictures/cache/drop.txt
    assert_absent /home/rin/.config/zen/default/.keep
    assert_absent /home/rin/.config/zen/default/user.js
    assert_absent /home/rin/.config/zen/profile/.parentlock
    assert_absent /home/rin/.config/zen/profile/lock
    assert_absent /home/rin/.config/zen/profiles.ini
    assert_absent /home/rin/.fly/logs

    touch "$out"
  ''

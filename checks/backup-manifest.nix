{
  pkgs,
  lib,
  manifest,
  backup,
}:

# The production selection is encrypted.
assert backup.paths == [ ];
assert backup.exclude == [ ];
assert backup.dynamicFilesFrom != null;
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
    umask 077
    fixture="$TMPDIR/fixture"
    export HOME="$TMPDIR/home"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    export RESTIC_REPOSITORY="$TMPDIR/repository"
    export RESTIC_PASSWORD="fixture-only-password"

    mkdir -p \
      "$fixture/home/user/Documents/Dev/project with spaces/src" \
      "$fixture/home/user/Documents/Dev/project with spaces/node_modules/dependency" \
      "$fixture/home/user/Documents/Other/node_modules" \
      "$fixture/home/user/Pictures/cache" \
      "$fixture/home/user/.cache/example" \
      "$fixture/home/user/.var/app/org.example.App/cache" \
      "$fixture/home/user/.var/app/org.example.App/config" \
      "$fixture/home/user/.local/share/example" \
      "$fixture/home/user/.config/example/profile" \
      "$fixture/home/user/.config/new-application"

    touch \
      "$fixture/home/user/Documents/Dev/project with spaces/src/keep.txt" \
      "$fixture/home/user/Documents/Dev/project with spaces/node_modules/dependency/drop.txt" \
      "$fixture/home/user/Documents/Other/node_modules/keep.txt" \
      "$fixture/home/user/Pictures/keep.txt" \
      "$fixture/home/user/Pictures/cache/drop.txt" \
      "$fixture/home/user/.cache/example/drop.txt" \
      "$fixture/home/user/.var/app/org.example.App/cache/drop.txt" \
      "$fixture/home/user/.var/app/org.example.App/config/keep.json" \
      "$fixture/home/user/.local/share/example/save.dat" \
      "$fixture/home/user/.config/example/profile/keep.json" \
      "$fixture/home/user/.config/example/profile/lock" \
      "$fixture/home/user/.config/new-application/keep.json"
    printf 'private fixture state\n' \
      >"$fixture/home/user/.config/example/profile/keep.json"
    printf 'Signature: 8a477f597d28d172789f06886806bc55\n' \
      >"$fixture/home/user/Pictures/cache/CACHEDIR.TAG"

    # These stand in for the two runtime SOPS files.
    cat >"$TMPDIR/paths" <<EOF
    $fixture/home/user
    EOF
    cat >"$TMPDIR/excludes" <<EOF
    $fixture/home/user/Documents/Dev/**/node_modules
    $fixture/home/user/.config/example/**/lock
    $fixture/home/user/.cache
    $fixture/home/user/.var/app/*/cache
    EOF
    mkdir -p "$fixture/home/user/New folder"
    touch "$fixture/home/user/New folder/keep.txt"

    restic init >/dev/null
    restic backup \
      --files-from="$TMPDIR/paths" \
      --exclude-file="$TMPDIR/excludes" \
      --one-file-system \
      ${lib.optionalString manifest.excludeCaches "--exclude-caches"} \
      --host ${lib.escapeShellArg manifest.hostname} \
      >/dev/null
    restic ls latest --json \
      | jq -r 'select(.struct_type == "node") | .path' \
      >"$TMPDIR/inventory"

    assert_present() {
      if ! grep -Fqx "$fixture$1" "$TMPDIR/inventory"; then
        echo "expected fixture path missing from snapshot: $1" >&2
        exit 1
      fi
    }
    assert_absent() {
      if grep -Fq "$fixture$1" "$TMPDIR/inventory"; then
        echo "excluded fixture path present in snapshot: $1" >&2
        exit 1
      fi
    }

    assert_present '/home/user/Documents/Dev/project with spaces/src/keep.txt'
    assert_present /home/user/Documents/Other/node_modules/keep.txt
    assert_present /home/user/Pictures/keep.txt
    assert_present /home/user/.config/example/profile/keep.json
    assert_present /home/user/.config/new-application/keep.json
    assert_present /home/user/.local/share/example/save.dat
    assert_present /home/user/.var/app/org.example.App/config/keep.json
    assert_present '/home/user/New folder/keep.txt'
    assert_absent '/home/user/Documents/Dev/project with spaces/node_modules'
    assert_absent /home/user/Pictures/cache/drop.txt
    assert_absent /home/user/.config/example/profile/lock
    assert_absent /home/user/.cache
    assert_absent /home/user/.var/app/org.example.App/cache

    # Recovery consumes snapshots, independently of the current private list.
    restic restore latest --target "$TMPDIR/restored" >/dev/null
    cmp "$fixture/home/user/.config/example/profile/keep.json" \
      "$TMPDIR/restored$fixture/home/user/.config/example/profile/keep.json"

    # Unreadable policy must fail rather than silently back up a smaller set.
    if restic backup --files-from="$TMPDIR/missing" >/dev/null 2>&1; then
      echo "backup accepted a missing selection file" >&2
      exit 1
    fi
    touch "$out"
  ''

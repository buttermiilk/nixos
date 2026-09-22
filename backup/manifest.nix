{
  # Gate the power-menu coordinator during first-time setup or reauthorization.
  # Inert Restic units and the recovery app remain buildable when this is false.
  enable = true;

  hostname = "sh1m3ji";
  repository = "rclone:gdrive:NixBackups/sh1m3ji";

  # Canonical absolute sources for both the normal backup service and the
  # live-ISO restore application. Avoid redundant nested sources: Documents
  # already includes Dev, osu, and every other Documents subdirectory.
  paths = [
    "/home/rin/Downloads"
    "/home/rin/Documents"
    "/home/rin/Pictures"
    "/home/rin/Videos"
    "/home/rin/.config/zen"

    # Small, non-declarative application state. The Restic repository is
    # encrypted; several of these files contain active login credentials.
    "/home/rin/.config/gh"
    "/home/rin/.config/.wrangler/config"
    "/home/rin/.fly"
    "/home/rin/.gemini/antigravity-cli/antigravity-oauth-token"
    "/home/rin/.android/adbkey"
    "/home/rin/.android/adbkey.pub"
    "/home/rin/.config/obs-studio/basic"
    "/home/rin/.codex/auth.json"
    "/home/rin/.codex/sessions"
  ];

  # Restic patterns are matched against full paths. Keep exclusions narrowly
  # anchored so a disposable name in one tree does not hide valuable data in
  # another.
  excludes = [
    "/home/rin/Documents/Dev/**/node_modules"
    "/home/rin/Documents/osu/Data"
    "/home/rin/Documents/osu/Logs"

    # Never restore stale browser locks.
    "/home/rin/.config/zen/**/.parentlock"
    "/home/rin/.config/zen/**/lock"

    # Home Manager recreates these declarative profile files.
    "/home/rin/.config/zen/profiles.ini"
    "/home/rin/.config/zen/default/user.js"
    "/home/rin/.config/zen/default/.keep"

    # Fly's logs are diagnostic output, not account state.
    "/home/rin/.fly/logs"
  ];

  # Pass Restic's --exclude-caches so directories carrying CACHEDIR.TAG are
  # treated as reproducible cache data.
  excludeCaches = true;
}

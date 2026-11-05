{

  enable = true;

  hostname = "sh1m3ji";
  repository = "rclone:gdrive:NixBackups/sh1m3ji";

  paths = [
    "/home/rin/Downloads"
    "/home/rin/Documents"
    "/home/rin/Pictures"
    "/home/rin/Videos"
    "/home/rin/.config/zen"

    "/home/rin/.config/gh"
    "/home/rin/.config/.wrangler/config"
    "/home/rin/.fly"
    "/home/rin/.gemini/antigravity-cli/antigravity-oauth-token"
    "/home/rin/.android/adbkey"
    "/home/rin/.android/adbkey.pub"
    "/home/rin/.config/obs-studio/basic"
    "/home/rin/.claude.json"
    "/home/rin/.claude/.credentials.json"
    "/home/rin/.codex/auth.json"
    "/home/rin/.codex/sessions"
  ];

  excludes = [
    "/home/rin/Documents/Dev/**/node_modules"
    "/home/rin/Documents/osu/Data"
    "/home/rin/Documents/osu/Logs"

    "/home/rin/Documents/osu-lazer/cache"
    "/home/rin/Documents/osu-lazer/logs"

    "/home/rin/.config/zen/**/.parentlock"
    "/home/rin/.config/zen/**/lock"

    "/home/rin/.config/zen/profiles.ini"
    "/home/rin/.config/zen/default/user.js"
    "/home/rin/.config/zen/default/.keep"

    "/home/rin/.fly/logs"
  ];

  excludeCaches = true;
}

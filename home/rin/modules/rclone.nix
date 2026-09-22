{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  googleDriveToken = osConfig.sops.secrets."rin/google-drive-token".path;
  googleDriveClientId = osConfig.sops.secrets."rin/google-drive-client-id".path;
  googleDriveClientSecret = osConfig.sops.secrets."rin/google-drive-client-secret".path;
  r2AccessKeyId = osConfig.sops.secrets."rin/access-key-id".path;
  r2SecretAccessKey = osConfig.sops.secrets."rin/secret-access-key".path;
  r2Endpoint = osConfig.sops.secrets."rin/endpoint".path;
  r2Bucket = osConfig.sops.secrets."rin/bucket".path;
  rcloneConfig = "${config.xdg.configHome}/rclone/rclone.conf";

  renderRcloneConfig = pkgs.writeShellApplication {
    name = "render-rclone-config";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.jq
    ];
    runtimeEnv = {
      SH1M3JI_GOOGLE_DRIVE_TOKEN = googleDriveToken;
      SH1M3JI_GOOGLE_DRIVE_CLIENT_ID = googleDriveClientId;
      SH1M3JI_GOOGLE_DRIVE_CLIENT_SECRET = googleDriveClientSecret;
      SH1M3JI_R2_ACCESS_KEY_ID = r2AccessKeyId;
      SH1M3JI_R2_SECRET_ACCESS_KEY = r2SecretAccessKey;
      SH1M3JI_R2_ENDPOINT = r2Endpoint;
      SH1M3JI_R2_BUCKET = r2Bucket;
      SH1M3JI_RCLONE_CONFIG = rcloneConfig;
    };
    text = builtins.readFile ../dotfiles/scripts/render-rclone-config.sh;
  };
in
{
  home.packages = [ pkgs.rclone ];

  home.activation.renderRcloneConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${lib.getExe renderRcloneConfig}
  '';

  systemd.user.services.rclone-config = {
    Unit.Description = "Render rclone configuration from SOPS";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe renderRcloneConfig;
    };
  };
}

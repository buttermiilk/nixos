{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  manifest = import ../../../backup/manifest.nix;
  resticPassword = osConfig.sops.secrets."rin/restic-password".path;
  backupPaths = osConfig.sops.secrets."rin/backup-paths".path;
  backupExcludes = osConfig.sops.secrets."rin/backup-excludes".path;
  rcloneConfig = "${config.xdg.configHome}/rclone/rclone.conf";

  zenQuiesce = pkgs.writeShellApplication {
    name = "quiesce-zen-for-backup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.procps
    ];
    text = builtins.readFile ./backup/quiesce-zen-for-backup.sh;
  };

  backupAndReboot = pkgs.writeShellApplication {
    name = "backup-and-reboot";
    runtimeInputs = [ pkgs.systemd ];
    text = builtins.readFile ./backup/backup-and-reboot.sh;
  };
in
{
  services.restic = {
    enable = true;
    backups.gdrive = {
      repository = manifest.repository;
      passwordFile = resticPassword;
      dynamicFilesFrom = "${lib.getExe' pkgs.coreutils "cat"} ${lib.escapeShellArg backupPaths}";
      initialize = true;
      timerConfig = null;
      runCheck = false;
      inhibitsSleep = true;
      extraOptions = [
        "rclone.program=${lib.getExe pkgs.rclone}"
      ];
      extraBackupArgs = [
        "--host=${manifest.hostname}"
        "--tag=manual"
        "--one-file-system"
        "--exclude-file=${backupExcludes}"
      ]
      ++ lib.optional manifest.excludeCaches "--exclude-caches";
      backupPrepareCommand = ''
        set -eu
        # Stop before initializing/uploading anything if private policy is missing.
        test -s ${lib.escapeShellArg backupPaths}
        test -r ${lib.escapeShellArg backupExcludes}
        ${lib.getExe zenQuiesce}
      '';
    };
  };

  systemd.user.services = {
    backup-and-reboot = {
      Unit.Description = "Back up selected state and reboot on success";
      Service = {
        Type = "oneshot";
        ExecStart =
          if manifest.enable then lib.getExe backupAndReboot else lib.getExe' pkgs.coreutils "false";
        TimeoutStartSec = "infinity";
      };
    };

    restic-backups-gdrive = {
      Unit = {
        Requires = [ "rclone-config.service" ];
        After = [ "rclone-config.service" ];
      };
      Service = {
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
        Environment = [
          "RCLONE_CONFIG=${rcloneConfig}"
          "RCLONE_TPSLIMIT=8"
          "RCLONE_TPSLIMIT_BURST=8"
        ];
      };
    };
  };
}

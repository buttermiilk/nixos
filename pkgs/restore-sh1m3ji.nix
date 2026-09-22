{
  coreutils,
  defaultSecretsFile,
  jq,
  lib,
  manifest,
  rclone,
  restic,
  sops,
  util-linux,
  writeShellApplication,
}:

writeShellApplication {
  name = "restore-sh1m3ji";
  runtimeInputs = [
    coreutils
    jq
    rclone
    restic
    sops
    util-linux
  ];
  runtimeEnv = {
    SH1M3JI_DEFAULT_SECRETS_FILE = toString defaultSecretsFile;
    SH1M3JI_RESTIC_REPOSITORY = manifest.repository;
    SH1M3JI_RESTIC_HOSTNAME = manifest.hostname;
    SH1M3JI_RCLONE_PROGRAM = lib.getExe rclone;
  };
  text = builtins.readFile ../home/rin/dotfiles/scripts/restore-sh1m3ji.sh;
}

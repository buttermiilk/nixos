{
  age,
  coreutils,
  defaultSecretsFile,
  gnutar,
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
  meta.description = "Restore the encrypted sh1m3ji snapshot from a live ISO";
  runtimeInputs = [
    age
    coreutils
    gnutar
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
  text = builtins.readFile ./restore-sh1m3ji.sh;
}

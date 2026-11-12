{
  coreutils,
  jq,
  rclone,
  sops,
  writeShellApplication,
}:

writeShellApplication {
  name = "authorize-google-drive";
  meta.description = "Authorize rclone and store its Google token through SOPS";
  runtimeInputs = [
    coreutils
    jq
    rclone
    sops
  ];
  text = builtins.readFile ./authorize-google-drive.sh;
}

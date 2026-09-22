{
  coreutils,
  jq,
  rclone,
  sops,
  writeShellApplication,
}:

writeShellApplication {
  name = "authorize-google-drive";
  runtimeInputs = [
    coreutils
    jq
    rclone
    sops
  ];
  text = builtins.readFile ../home/rin/dotfiles/scripts/authorize-google-drive.sh;
}

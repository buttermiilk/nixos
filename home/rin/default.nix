{ ... }:

{
  imports = [
    ./modules/applications.nix
    ./modules/backup.nix
    ./modules/browser.nix
    ./modules/desktop.nix
    ./modules/codex.nix
    ./modules/editors.nix
    ./modules/gaming.nix
    ./modules/development.nix
    ./modules/nixcord.nix
    ./modules/obs.nix
    ./modules/rclone.nix
    ./modules/shell.nix
    ./modules/sober.nix
  ];

  home.username = "rin";
  home.homeDirectory = "/home/rin";
  home.stateVersion = "26.05";
}

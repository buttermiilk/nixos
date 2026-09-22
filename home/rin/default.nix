{ inputs, ... }:

{
  imports = [
    inputs.zen-browser.homeModules.beta
    ./modules/applications.nix
    ./modules/backup.nix
    ./modules/browser.nix
    ./modules/desktop.nix
    ./modules/development.nix
    ./modules/nixcord.nix
    ./modules/rclone.nix
    ./modules/shell.nix
  ];

  home.username = "rin";
  home.homeDirectory = "/home/rin";
  home.stateVersion = "26.05"; # Never change this after installation.
}

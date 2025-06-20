{ config, lib, pkgs, ... }:

let
  waybarConfig = ./../dotfiles/main/waybar/config.jsonc;
  waybarStyle = ./../dotfiles/main/waybar/style.css;
in {
  programs.waybar = {
    enable = true;
    settings = builtins.fromJSON (builtins.readFile waybarConfig);
    style = builtins.readFile waybarStyle;
  };

  home.packages = with pkgs; [
    cliphist playerctl networkmanager dunst
    wl-clipboard
    gsettings-desktop-schemas
  ];
}

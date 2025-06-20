{ config, lib, pkgs, ... }:

let 
  lockFile = ''
    preload = ~/.config/wallpapers/linux.jpg
    wallpaper = eDP-1, ~/.config/wallpapers/linux.jpg
    splash = false
  '';
in {
  home.file.".config/hypr/hyprpaper.conf".text = lockFile;
}

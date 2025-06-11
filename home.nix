# nixos/home.nix
{ config, pkgs, ... }:

{
  home-manager.users.rin = {
    home.stateVersion = "23.11";

    programs.zsh = {
      enable = true;
      ohMyZsh = {
        enable = true;
        theme = "robbyrussell";
        plugins = [ "git" "z" ];
      };
    };

    home.packages = with pkgs; [
      cbonsai
      tty-clock
    ];

    home.file.".config/kitty" = {
      source = ./dotfiles/kitty;
      recursive = true;
    };
    home.file.".config/fastfetch" = {
      source = ./dotfiles/fastfetch;
      recursive = true;
    };
    home.file.".config/i3" = {
      source = ./dotfiles/i3;
      recursive = true;
    };
    home.file.".config/i3status-rust" = {
      source = ./dotfiles/i3status-rust;
      recursive = true;
    };
    home.file.".config/picom" = {
      source = ./dotfiles/picom;
      recursive = true;
    };
    home.file.".config/rofi" = {
      source = ./dotfiles/rofi;
      recursive = true;
    };
    home.file."Pictures/wallpapers" = {
      source = ./dotfiles/wallpapers;
      recursive = true;
    };
  };
}

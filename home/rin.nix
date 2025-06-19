{ config, pkgs, ... }:

{
  home.stateVersion = "25.05";

  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "candy";
      plugins = [ "git" "z" ];
    };
    initExtra = ''
      eval "$(zoxide init zsh)"
    '';
  };

  home.packages = with pkgs; [
    cbonsai
    tty-clock
    zoxide
  ];

  home.file.".config/kitty" = {
    source = ../dotfiles/kitty;
    recursive = true;
  };
  home.file.".config/fastfetch" = {
    source = ../dotfiles/fastfetch;
    recursive = true;
  };
  home.file.".config/i3" = {
    source = ../dotfiles/i3;
    recursive = true;
  };
  home.file.".config/i3status-rust" = {
    source = ../dotfiles/i3status-rust;
    recursive = true;
  };
  home.file.".config/picom" = {
    source = ../dotfiles/picom;
    recursive = true;
  };
  home.file.".config/rofi" = {
    source = ../dotfiles/rofi;
    recursive = true;
  };
  home.file.".config/wallpapers" = {
    source = ../dotfiles/wallpapers;
    recursive = true;
  };
}

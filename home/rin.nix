{ config, pkgs, ... }:

{
  # state the version of the home manager
  home.stateVersion = "25.05";

  # as we enabled zsh, we definitely need to configure it
  programs.zsh = {
    enable = true;
    # opt-in for ohmyzsh
    # this is merely personal choice again, you use what you like
    oh-my-zsh = {
      enable = true;
      # the candy theme makes everything easy to look at
      theme = "candy";
      # plugins like git makes using a shell with git repos easier
      plugins = [ "git" "z" ];
    };
    # initialize zoxide which is just a better cd command
    initExtra = ''
      eval "$(zoxide init zsh)"
    '';
  };

  # set some aliases for our shell
  home.shellAliases = {
    ls = "ls --color=auto";
    grep = "grep --color=auto";
    ll = "ls -l";
    "cd.." = "cd ..";
    stab = "shutdown now";
  };

  # packages for this user only
  # it is recommended to put dotfiles packages in here
  home.packages = with pkgs; [
    cbonsai
    tty-clock
    zoxide
  ];

  # symlink dotfiles in the respective home directories
  # when you need to change something, depends on where you
  # installed your base system, get in there and work with it
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

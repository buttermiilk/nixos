{ config, pkgs, ... }:

{
  # import our modularized dots
  imports = builtins.attrValues (import ./modules);
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
    # dotfiles stuff
    adwaita-icon-theme
    bat cava dunst
    hyprland hyprlock hyprpaper
    kitty ncmpcpp neovim
    nwg-dock-hyprland
    nwg-drawer rofi
    playerctl waybar fcitx5
    # misc toolings
    cbonsai hyprsunset hyprshot
    tty-clock wl-clipboard zoxide
  ];

  # symlink dotfiles in the respective home directories
  # when you need to change something, depends on where you
  # installed your base system, get in there and work with it
  home.file.".config/nvim" = {
    source = ../dotfiles/main/nvim;
    recursive = true;
  };
  home.file.".config/rofi" = {
    source = ../dotfiles/main/rofi;
    recursive = true;
  };
  home.file.".config/scripts" = {
    source = ../dotfiles/main/scripts;
    recursive = true;
  };
  home.file.".config/wallpapers" = {
    source = ../dotfiles/main/wallpapers;
    recursive = true;
  };
  home.file.".config/waybar" = {
    source = ../dotfiles/main/waybar;
    recursive = true;
  };
}

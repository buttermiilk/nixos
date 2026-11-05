{ lib, pkgs, ... }:

let

  materialPolybar = pkgs.polybar.override {
    pulseSupport = true;
    i3Support = true;
  };

  startPolybar = pkgs.writeShellApplication {
    name = "start-polybar";
    runtimeInputs = [ materialPolybar ];
    text = ''
      export POLYBAR_BATTERY=BAT0 POLYBAR_ADAPTER=AC
      for supply in /sys/class/power_supply/*; do
        [[ -r "$supply/type" ]] || continue
        read -r supply_type < "$supply/type"
        case "$supply_type" in
          Battery) POLYBAR_BATTERY="''${supply##*/}" ;;
          Mains) POLYBAR_ADAPTER="''${supply##*/}" ;;
        esac
      done
      exec polybar main
    '';
  };

  inhibitClicker = pkgs.writeShellApplication {
    name = "inhibit-clicker";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      libnotify
      systemd
      util-linux
      xdotool
    ];
    text = lib.removePrefix "#!/usr/bin/env bash\n" (
      builtins.readFile ../dotfiles/scripts/inhibit-clicker.sh
    );
  };

  ecoMode = pkgs.writeShellApplication {
    name = "eco-mode";
    runtimeInputs = with pkgs; [
      brightnessctl
      coreutils
      i3
      libnotify
      procps
      materialPolybar
    ];
    text = lib.removePrefix "#!/usr/bin/env bash
" (builtins.readFile ../dotfiles/scripts/eco-mode.sh);
  };
in
{
  home.packages = with pkgs; [

    picom
    feh
    autotiling
    rofi
    materialPolybar
    startPolybar
    flameshot
    libnotify
    brightnessctl
    pulseaudio
    i3lock
    pavucontrol
    xclip
    inhibitClicker
    ecoMode
    google-chrome
  ];

  services.dunst.enable = true;

  services.redshift = {
    enable = true;
    provider = "manual";

    latitude = 13.7563;
    longitude = 100.5018;
  };

  xdg.configFile = {
    "fastfetch".source = ../dotfiles/fastfetch;
    "i3".source = ../dotfiles/i3;
    "picom".source = ../dotfiles/picom;
    "polybar".source = ../dotfiles/polybar;
    "rofi".source = ../dotfiles/rofi;
    "wallpapers".source = ../dotfiles/wallpapers;
  };

  systemd.user.tmpfiles.rules = [
    "L+ %h/.local/share/fonts - - - - %h/Documents/Media/fonts"
  ];

  fonts.fontconfig.enable = true;

  home.pointerCursor = {
    enable = true;
    package = pkgs.neuro-cursor;
    name = "Neuro-sama";
    size = 32;
    gtk.enable = true;
    x11.enable = true;
  };

  xresources.properties."Xft.dpi" = 96;

  gtk = {
    enable = true;
    font = {
      name = "Adwaita Sans";
      size = 11;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  programs.kitty = {
    enable = true;
    shellIntegration.enableZshIntegration = true;
    font = {
      name = "monospace";
      size = 13;
    };
    settings = {

      tab_bar_style = "hidden";
    };
  };
}

{ lib, pkgs, ... }:

let
  themedPolybar = pkgs.polybar.override {
    pulseSupport = true;
    i3Support = true;
  };

  startPolybar = pkgs.writeShellApplication {
    name = "start-polybar";
    runtimeInputs = [
      themedPolybar
      pkgs.coreutils
    ];
    text = ''
      export POLYBAR_WIFI_LABEL
      POLYBAR_WIFI_LABEL="$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
      POLYBAR_WIFI_LABEL="''${POLYBAR_WIFI_LABEL:0:7}"
      export POLYBAR_BATTERY=BAT0 POLYBAR_ADAPTER=AC
      for supply in /sys/class/power_supply/*; do
        [[ -r "$supply/type" ]] || continue
        read -r supply_type < "$supply/type"
        case "$supply_type" in
          Battery) POLYBAR_BATTERY="''${supply##*/}" ;;
          Mains) POLYBAR_ADAPTER="''${supply##*/}" ;;
        esac
      done
      exec polybar "$@" main
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
    text = lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ./desktop/inhibit-clicker.sh);
  };

  mkPowerMode =
    name: mode:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [
        brightnessctl
        coreutils
        i3
        libnotify
        procps
        themedPolybar
        util-linux
      ];
      text =
        "POWER_MODE_TARGET=${mode}\n"
        + lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ./desktop/eco-mode.sh);
    };
  ecoMode = mkPowerMode "eco-mode" "eco";
  performanceMode = mkPowerMode "performance-mode" "performance";
in
{
  home.packages = with pkgs; [
    picom
    feh
    autotiling
    rofi
    themedPolybar
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
    performanceMode
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

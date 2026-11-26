{
  config,
  lib,
  pkgs,
  ...
}:

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
    # Installing the addon alone does not add UniKey to a fresh Fcitx profile.
    "fcitx5/profile" = {
      force = true;
      text = ''
        [Groups/0]
        Name=Default
        Default Layout=us
        DefaultIM=unikey

        [Groups/0/Items/0]
        Name=keyboard-us
        Layout=

        [Groups/0/Items/1]
        Name=unikey
        Layout=

        [GroupOrder]
        0=Default
      '';
    };
    "fcitx5/conf/unikey.conf" = {
      force = true;
      text = ''
        InputMethod=Telex
        OutputCharset=Unicode
      '';
    };
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
    colorScheme = "dark";
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    font = {
      name = "Adwaita Sans";
      size = 11;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  # broadcast GTK settings to running X11 apps
  services.xsettingsd = {
    enable = true;
    settings = {
      "Net/ThemeName" = config.gtk.theme.name;
      "Net/IconThemeName" = config.gtk.iconTheme.name;
      "Gtk/FontName" = "${config.gtk.font.name} ${toString config.gtk.font.size}";
      "Gtk/CursorThemeName" = config.home.pointerCursor.name;
      "Gtk/CursorThemeSize" = config.home.pointerCursor.size;
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style.name = "adwaita-dark";
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

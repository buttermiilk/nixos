{ lib, pkgs, ... }:

let

  # PipeWire exposes a PulseAudio-compatible server. Enable that module and i3
  # integration in the otherwise-minimal nixpkgs Polybar build.
  materialPolybar = pkgs.polybar.override {
    pulseSupport = true;
    i3Support = true;
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
in
{
  home.packages = with pkgs; [
    # Launched from the i3 and Polybar configuration.
    picom
    feh
    autotiling
    xborders
    rofi
    materialPolybar
    flameshot
    libnotify # notify-send, used by the i3 split-orientation binds
    brightnessctl
    alsa-utils # amixer, used by the F8 microphone mute bind
    pulseaudio # pactl CLI only; the actual server is PipeWire
    i3lock
    pavucontrol
    xclip
    inhibitClicker
    google-chrome
  ];

  services.dunst.enable = true;

  services.redshift = {
    enable = true;
    provider = "manual";
    # Bangkok city centre; fixed coordinates avoid depending on GeoClue.
    latitude = 13.7563;
    longitude = 100.5018;
  };

  # Dotfiles are symlinked into ~/.config without translating their native
  # formats into Nix.
  xdg.configFile = {
    "fastfetch".source = ../dotfiles/fastfetch;
    "i3".source = ../dotfiles/i3;
    "picom".source = ../dotfiles/picom;
    "polybar".source = ../dotfiles/polybar;
    "rofi".source = ../dotfiles/rofi;
    "wallpapers".source = ../dotfiles/wallpapers;
  };

  # Keep the personal font collection outside the Nix store while exposing it
  # through Fontconfig's standard per-user directory.
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

  # Rofi's show-icons setting needs an icon theme installed.
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
      # Zellij owns tabs and the status bar in this setup.
      tab_bar_style = "hidden";
    };
  };

  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-backgroundremoval
      obs-pipewire-audio-capture
      obs-plugin-countdown
      obs-gstreamer
      obs-vkcapture
    ];
  };
}

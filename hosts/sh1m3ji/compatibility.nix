{ pkgs, ... }:

{
  # Runtime libraries for downloaded Linux binaries. NixOS already provides
  # the nix-ld base libraries, including curl and systemd.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      alsa-lib
      at-spi2-core
      cairo
      cups
      dbus
      expat
      glib
      gtk3
      libgbm
      libx11
      libxcb
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxkbcommon
      libxrandr
      nspr
      nss
      pango
      vulkan-loader
    ];
  };
}

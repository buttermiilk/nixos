{ lib, pkgs, ... }:

let
  concord = pkgs.concord-client;

  concordDesktop = pkgs.makeDesktopItem {
    name = "concord";
    desktopName = "Concord";
    comment = "Discord client in the terminal";
    exec = "kitty --class concord ${lib.getExe concord}";
    icon = "discord";
    terminal = false;
    categories = [
      "Network"
      "InstantMessaging"
    ];
  };
in
{
  programs.thunderbird = {
    enable = true;
    profiles.default = {
      isDefault = true;
      withExternalGnupg = true;
    };
  };
  home.packages = with pkgs; [
    fastfetch
    chafa
    btop
    zip
    unzip
    ripgrep
    jq
    remmina
    blender-with-mcp
    blender-mcp
    ghidra
    monitask
    concordDesktop
    mpv
  ];
}

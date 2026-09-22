{ pkgs, ... }:

let
  osuWinello = pkgs.writeShellApplication {
    name = "osu-winello";
    runtimeInputs = [ pkgs.steam-run ];
    text = builtins.readFile ../dotfiles/scripts/osu-winello.sh;
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
    # Terminal tools
    fastfetch
    chafa # Fastfetch's image logo renderer
    btop
    tty-clock
    cbonsai
    zip
    unzip
    ripgrep
    jq

    # Remote access and graphical applications
    remmina
    # Blender Lab's MCP extension is exposed as a read-only system extension.
    blender-with-mcp
    blender-mcp
    kdePackages.kdenlive
    ghidra
    prismlauncher
    pkgs.bongocat-osu
    pkgs.taiko-editor
    pkgs.tiny10-vm
    pkgs.vinegar

    # osu! stable through osu-winello; the wrapper supplies the FHS runtime.
    steam-run
    zenity
    osuWinello
  ];
}

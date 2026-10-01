{
  config,
  lib,
  pkgs,
  ...
}:

let
  osuWinello = pkgs.writeShellApplication {
    name = "osu-winello";
    runtimeInputs = [
      pkgs.gamemode
      pkgs.steam-run
    ];
    text = builtins.readFile ../dotfiles/scripts/osu-winello.sh;
  };

  # PhotoGIMP: Photoshop-style shortcuts, tool layout, and docks for GIMP 3.
  photogimpConfig =
    pkgs.runCommand "photogimp-3.1-config"
      {
        src = pkgs.fetchurl {
          url = "https://github.com/Diolinux/PhotoGIMP/releases/download/3.1/PhotoGIMP-linux.zip";
          hash = "sha256-vw4SeYcNQBUr6z5wLPPk4BpokgMaGs5bxKm4WIlLWE4=";
        };
        nativeBuildInputs = [ pkgs.unzip ];
      }
      ''
        unzip -q "$src"
        cp -r PhotoGIMP-linux/.config/GIMP/3.0 "$out"
        # PhotoGIMP ships 8 undo levels; Photoshop's default history is 50.
        sed -i 's/^(undo-levels 8)$/(undo-levels 50)/' "$out/gimprc"
      '';
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
    gimp
    ghidra
    prismlauncher
    bongocat-osu
    taiko-editor
    tiny10-vm
    vinegar

    # Company-mandated time tracker (X11 only; works under i3).
    monitask

    # osu! stable through osu-winello; the wrapper supplies the FHS runtime.
    steam-run
    zenity
    osuWinello
  ];

  # GIMP rewrites its config files, so they cannot be read-only store links.
  # Seed PhotoGIMP once; delete ~/.config/GIMP/3.0 to reset to it.
  home.activation.seedPhotoGimp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    gimp_dir="${config.xdg.configHome}/GIMP/3.0"
    if [ ! -e "$gimp_dir/shortcutsrc" ]; then
      run mkdir -p "$gimp_dir"
      run cp -r --no-preserve=mode ${photogimpConfig}/. "$gimp_dir/"
    fi
  '';
}

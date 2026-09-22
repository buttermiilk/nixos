{
  alsa-lib,
  coreutils,
  fetchurl,
  jre8,
  lib,
  libarchive,
  libglvnd,
  libpulseaudio,
  makeDesktopItem,
  stdenvNoCC,
  symlinkJoin,
  unzip,
  writeShellApplication,
}:

let
  version = "4.1.4";

  archive = fetchurl {
    url = "https://alchyr.s-ul.eu/QcbjVt0F";
    hash = "sha256-Qv/cC9vSFF1AqOlKxPz/ioExu1snBFkcAO0sRBeR+F0=";
  };

  payload = stdenvNoCC.mkDerivation {
    pname = "taiko-editor-payload";
    inherit version;
    src = archive;
    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      mkdir -p \
        "$out/share/taiko-editor/lib/update/alchyr" \
        "$out/share/icons/hicolor/48x48/apps"

      ${libarchive}/bin/bsdtar --extract --file "$src" --directory "$out/share/taiko-editor" \
        lib/desktop-1.0.jar \
        lib/update/alchyr/Updater.class

      ${unzip}/bin/unzip -p "$out/share/taiko-editor/lib/desktop-1.0.jar" \
        taikoedit/images/icon_48.png \
        >"$out/share/icons/hicolor/48x48/apps/taiko-editor.png"

      runHook postInstall
    '';
  };

  launcher = writeShellApplication {
    name = "taiko-editor";
    runtimeInputs = [ coreutils ];
    runtimeEnv = {
      TAIKO_EDITOR_JAVA = lib.getExe jre8;
      TAIKO_EDITOR_LIBRARY_PATH = "${
        lib.makeLibraryPath [
          alsa-lib
          libglvnd
          libpulseaudio
        ]
      }:/run/opengl-driver/lib";
      TAIKO_EDITOR_PAYLOAD = "${payload}/share/taiko-editor";
      TAIKO_EDITOR_VERSION = version;
    };
    text = builtins.readFile ../home/rin/dotfiles/scripts/taiko-editor.sh;
  };

  desktopItem = makeDesktopItem {
    name = "taiko-editor";
    desktopName = "osu! Taiko Editor";
    comment = "Edit osu!taiko beatmaps in the Winello song library";
    exec = "taiko-editor %F";
    icon = "taiko-editor";
    categories = [ "Game" ];
  };
in
symlinkJoin {
  name = "taiko-editor-${version}";
  paths = [
    desktopItem
    launcher
    payload
  ];

  meta = {
    description = "Standalone osu!taiko beatmap editor by Alchyr";
    homepage = "https://github.com/Alchyr/TaikoEditor";
    license = lib.licenses.cc0;
    mainProgram = "taiko-editor";
    platforms = [ "x86_64-linux" ];
  };
}

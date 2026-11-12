{
  SDL2,
  autoPatchelfHook,
  fetchurl,
  lib,
  libx11,
  libxrandr,
  makeDesktopItem,
  makeWrapper,
  sfml_2,
  stdenv,
  xdotool,
}:

let
  source = (lib.importJSON ../mirrors.json).bongocat-osu;
  desktopItem = makeDesktopItem {
    name = "bongocat-osu";
    desktopName = "Bongo Cat for osu!";
    comment = "Keyboard and mouse-reactive Bongo Cat overlay";
    exec = "bongocat-osu";
    icon = "input-gaming";
    categories = [
      "Game"
      "AudioVideo"
    ];
  };
in
stdenv.mkDerivation {
  pname = "bongocat-osu";
  inherit (source) version;

  src = fetchurl { inherit (source) url hash; };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  dontBuild = true;

  buildInputs = [
    SDL2
    libx11
    libxrandr
    sfml_2
    xdotool
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/libexec/bongocat-osu" "$out/share/bongocat-osu"
    install -Dm755 bin/bongo "$out/libexec/bongocat-osu/bongo"
    cp -r share/. "$out/share/"
    cp -r ${desktopItem}/share/. "$out/share/"

    makeWrapper "$out/libexec/bongocat-osu/bongo" "$out/bin/bongocat-osu" \
      --run 'config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/bongocat-osu"' \
      --run 'mkdir -p "$config_dir"' \
      --run "[ -e \"\$config_dir/font\" ] || ln -s '$out/share/bongocat-osu/font' \"\$config_dir/font\"" \
      --run "[ -e \"\$config_dir/img\" ] || ln -s '$out/share/bongocat-osu/img' \"\$config_dir/img\"" \
      --run 'cd "$config_dir"'

    runHook postInstall
  '';

  meta = {
    description = "Native Bongo Cat overlay for osu! and other input modes";
    homepage = "https://github.com/kuroni/bongocat-osu";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "bongocat-osu";
    platforms = [ "x86_64-linux" ];
  };
}

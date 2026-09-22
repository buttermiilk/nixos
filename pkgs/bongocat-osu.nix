{
  SDL2,
  fetchFromGitHub,
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
  version = "unstable-2022-07-30";

  src = fetchFromGitHub {
    owner = "kuroni";
    repo = "bongocat-osu";
    rev = "0714582791529af714bc9a6a6a6f77497c7c561d";
    hash = "sha256-Kgi0G/H+7Yk1Ogvb42lJnzdgrK+6OL5h0vFYK142qT0=";
  };

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [
    SDL2
    libx11
    libxrandr
    sfml_2
    xdotool
  ];

  configurePhase = ''
    runHook preConfigure
    cp Makefile.linux Makefile
    runHook postConfigure
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/libexec/bongocat-osu" "$out/share/bongocat-osu"
    install -Dm755 bin/bongo "$out/libexec/bongocat-osu/bongo"
    cp -r font img "$out/share/bongocat-osu/"
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
    mainProgram = "bongocat-osu";
    platforms = [ "x86_64-linux" ];
  };
}

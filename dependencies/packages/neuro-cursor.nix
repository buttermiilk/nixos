{
  fetchurl,
  lib,
  stdenvNoCC,
}:

let
  source = (lib.importJSON ../mirrors.json).neuro-cursor;
in
stdenvNoCC.mkDerivation {
  pname = "neuro-sama-cursor";
  inherit (source) version;
  src = fetchurl { inherit (source) url hash; };
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    themeDir="$out/share/icons/Neuro-sama"
    mkdir -p "$themeDir"
    cp -a ./. "$themeDir"
    runHook postInstall
  '';

  meta = {
    description = "Neuro-sama X cursor theme";
    platforms = lib.platforms.linux;
  };
}

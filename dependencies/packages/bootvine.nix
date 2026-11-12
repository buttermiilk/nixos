{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  dbus,
  systemd,
}:

let
  source = (lib.importJSON ../mirrors.json).bootvine;
in
stdenvNoCC.mkDerivation {
  pname = "bootvine";
  inherit (source) version;
  src = fetchurl { inherit (source) url hash; };
  sourceRoot = ".";
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    stdenv.cc.cc.lib
    dbus
    systemd
  ];
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r bin lib share "$out/"
    chmod -R u+w "$out"
    while IFS= read -r -d "" unit; do
      substituteInPlace "$unit" --replace-fail /usr/bin/bootvine "$out/bin/bootvine"
    done < <(find "$out/lib/systemd/system" -type f -print0)
    runHook postInstall
  '';

  meta = {
    description = "Live tree of systemd boot and shutdown jobs";
    homepage = "https://codeberg.org/wvhulle/bootvine";
    license = lib.licenses.gpl3Plus;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "bootvine";
    platforms = [ "x86_64-linux" ];
  };
}

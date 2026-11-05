{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  pipewire,
  libva,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "concord";
  version = "2.6.1";

  src = fetchurl {
    url = "https://github.com/chojs23/concord/releases/download/v${finalAttrs.version}/concord-x86_64-unknown-linux-gnu.tar.xz";
    hash = "sha256-eEm+fxAB6iTLMK25XGqIfHXojgUh/E9I6MHHlgOf7V8=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  buildInputs = [ stdenv.cc.cc.lib alsa-lib pipewire libva ];
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 concord "$out/bin/concord"
    install -Dm644 LICENSE "$out/share/licenses/concord/LICENSE"
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/concord" \
      --set-default PIPEWIRE_CONFIG_DIR "${pipewire}/share/pipewire"
  '';

  meta = {
    description = "Discord client in the terminal";
    homepage = "https://github.com/chojs23/concord";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "concord";
    platforms = [ "x86_64-linux" ];
  };
})

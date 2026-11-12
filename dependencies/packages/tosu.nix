{
  fetchurl,
  icu,
  lib,
  makeWrapper,
  stdenv,
  unzip,
}:

let
  source = (lib.importJSON ../upstream.json).tosu;
in
stdenv.mkDerivation {
  pname = "tosu";
  inherit (source) version;

  src = fetchurl { inherit (source) url hash; };
  sourceRoot = ".";

  nativeBuildInputs = [
    makeWrapper
    unzip
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 tosu "$out/libexec/tosu/tosu"
    makeWrapper "$out/libexec/tosu/tosu" "$out/bin/tosu" \
      --set NIX_LD "$(cat ${stdenv.cc}/nix-support/dynamic-linker)" \
      --prefix NIX_LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          stdenv.cc.cc.lib
          icu
        ]
      }"

    runHook postInstall
  '';

  dontStrip = true;
  dontPatchELF = true;

  meta = {
    description = "osu! memory reader that serves overlay and stream counter data";
    homepage = "https://github.com/tosuapp/tosu";
    license = lib.licenses.lgpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "tosu";
    platforms = [ "x86_64-linux" ];
  };
}

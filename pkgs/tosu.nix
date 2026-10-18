{
  fetchzip,
  icu,
  lib,
  makeWrapper,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "tosu";
  version = "4.26.2";

  src = fetchzip {
    url = "https://github.com/tosuapp/tosu/releases/download/v${finalAttrs.version}/tosu-linux-v${finalAttrs.version}.zip";
    hash = "sha256-02ghnFGcHMw1Sy/8a2v6hMkj5jNw4aIy9pdyKUY+R9I=";
    stripRoot = false;
  };

  nativeBuildInputs = [ makeWrapper ];

  # tosu is a `pkg` executable that reads its JS payload from its own file, so
  # patchelf corrupts it. Run it unmodified through the host's nix-ld shim
  # (programs.nix-ld) instead, pointing nix-ld at the libraries it needs.
  # The bundled .NET beatmap parser dlopen()s ICU.
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
})

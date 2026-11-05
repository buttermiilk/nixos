{
  autoPatchelfHook,
  cairo,
  coreutils,
  dpkg,
  fetchurl,
  fontconfig,
  freetype,
  glib,
  gnugrep,
  gtk3,
  icu,
  krb5,
  lib,
  libglvnd,
  libice,
  libnotify,
  libsm,
  libx11,
  libxcursor,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxscrnsaver,
  makeDesktopItem,
  makeWrapper,
  openssl,
  stdenv,
  xdg-utils,
  zlib,
}:

let

  runtimeLibs = [
    cairo
    fontconfig
    freetype
    glib
    gtk3
    icu
    krb5
    libglvnd
    libice
    libsm
    libx11
    libxcursor
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxscrnsaver
    openssl
    zlib
  ];

  desktopItem = makeDesktopItem {
    name = "monitask";
    desktopName = "Monitask";
    comment = "Monitask desktop time tracker";
    exec = "monitask";
    icon = "monitask";
    categories = [ "Office" ];
  };
in
stdenv.mkDerivation {
  pname = "monitask";
  version = "0.01.86";

  src = fetchurl {
    url = "https://nixos.mewo.eu.org/monitask.deb";
    hash = "sha256-WGtcLv1xAqdhmvuMmtc6Z8VDX0wjUYEXSuxxbzlk/rY=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [
    fontconfig
    stdenv.cc.cc.lib
    zlib
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/opt" "$out/bin"
    cp -r opt/monitask "$out/opt/monitask"
    rm "$out/opt/monitask/libcoreclrtraceptprovider.so"

    install -Dm644 usr/share/icons/mt_znak.svg \
      "$out/share/icons/hicolor/scalable/apps/monitask.svg"
    cp -r ${desktopItem}/share/applications "$out/share/"

    makeWrapper "$out/opt/monitask/Monitask" "$out/bin/monitask" \
      --chdir "$out/opt/monitask" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}" \
      --prefix PATH : "${
        lib.makeBinPath [
          coreutils
          gnugrep
          libnotify
          xdg-utils
        ]
      }"

    runHook postInstall
  '';

  dontStrip = true;

  meta = {
    description = "Monitask employee time tracker (X11 only)";
    homepage = "https://www.monitask.com/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "monitask";
    platforms = [ "x86_64-linux" ];
  };
}

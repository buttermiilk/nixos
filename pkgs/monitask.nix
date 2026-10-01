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
  # Libraries the bundled .NET runtime and Avalonia dlopen() by soname at
  # runtime, which autoPatchelfHook cannot see.
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
stdenv.mkDerivation (finalAttrs: {
  pname = "monitask";
  version = "0.01.86";

  # Monitask's official APT repository. Old .deb files may disappear after an
  # upstream release; take the new Filename/SHA256 from
  # https://deskcap.blob.core.windows.net/deployment/Linux/deb/Release/dists/bionic/main/binary-amd64/Packages
  src = fetchurl {
    url = "https://deskcap.blob.core.windows.net/deployment/Linux/deb/Release/pool/main/m/monitask/monitask_${finalAttrs.version}_amd64.deb";
    hash = "sha256-d4UrkRDfdR135ctnazjUw1sy2YIRVXR9HJh/LKS4jng=";
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
    # LTTng tracing provider: links an LTTng-UST soname nixpkgs no longer ships
    # and is only loaded when tracing is enabled.
    rm "$out/opt/monitask/libcoreclrtraceptprovider.so"

    install -Dm644 usr/share/icons/mt_znak.svg \
      "$out/share/icons/hicolor/scalable/apps/monitask.svg"
    cp -r ${desktopItem}/share/applications "$out/share/"

    # Upstream's launcher also cds here: the app loads ./Assets/... relative to
    # the working directory. User data goes to ~/.config and ~/.local.
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

  # The bundled .NET apphost locates its runtime next to itself; stripping
  # breaks the managed single-directory layout.
  dontStrip = true;

  meta = {
    description = "Monitask employee time tracker (X11 only)";
    homepage = "https://www.monitask.com/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "monitask";
    platforms = [ "x86_64-linux" ];
  };
})

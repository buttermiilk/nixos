{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  freetype,
  fontconfig,
  zlib,
  libwebp,
  libopus,
  libGL,
  vulkan-loader,
  libx11,
  libxcursor,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxscrnsaver,
  libxtst,
  wayland,
  libdecor,
  libxkbcommon,
  alsa-lib,
  libpulseaudio,
  pipewire,
  dbus,
  ffmpeg,
  libsecret,
  libnotify,
  xdg-utils,
  cacert,
}:

let
  source = (lib.importJSON ../upstream.json).larpercord;
  runtimeLibraries = [
    libGL
    vulkan-loader
    libx11
    libxcursor
    libxext
    libxfixes
    libxi
    libxrandr
    libxscrnsaver
    libxtst
    wayland
    libdecor
    libxkbcommon
    alsa-lib
    libpulseaudio
    pipewire
    dbus
    ffmpeg
  ];
in
stdenvNoCC.mkDerivation {
  pname = "larpercord";
  inherit (source) version;
  src = fetchurl { inherit (source) url hash; };
  dontUnpack = true;
  dontBuild = true;
  dontStrip = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
  ];
  buildInputs = [
    freetype
    fontconfig
    zlib
    libwebp
    libopus
  ]
  ++ runtimeLibraries;
  # The release bundles SDL3, curl and OpenSSL, but SDL and the media player
  # load graphics, audio, D-Bus and FFmpeg libraries by name at runtime.
  runtimeDependencies = map lib.getLib runtimeLibraries;
  # SDL also advertises optional Steam integration and this legacy GLES alias.
  # libglvnd provides the supported libGLESv1_CM.so.1 name instead.
  autoPatchelfIgnoreMissingDeps = [
    "libsteam_api.so"
    "libGLES_CM.so.1"
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "dev.larpercord";
      desktopName = "larperCord";
      comment = "Native Discord client";
      exec = "larpercord";
      icon = "discord";
      startupWMClass = "dev.larpercord";
      categories = [
        "Network"
        "InstantMessaging"
      ];
    })
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/larpercord"
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/larpercord" \
      --prefix PATH : "${
        lib.makeBinPath [
          libsecret
          libnotify
          xdg-utils
        ]
      }" \
      --set-default SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt"
  '';

  meta = {
    description = "Native Discord client with a themeable SDL3 and Dear ImGui interface";
    homepage = "https://github.com/RshaCuDeVidro/larperCord";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "larpercord";
    platforms = [ "x86_64-linux" ];
  };
}

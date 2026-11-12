# CI only. The host uses packages/bootvine.nix, which downloads the binary.
{
  lib,
  fetchgit,
  rustPlatform,
  pkg-config,
  dbus,
  systemd,
}:

let
  source = (lib.importJSON ../upstream.json).bootvine;
  src = fetchgit { inherit (source) url rev hash; };
in
rustPlatform.buildRustPackage {
  pname = "bootvine-ci";
  inherit (source) version;
  inherit src;
  cargoLock.lockFile = "${src}/Cargo.lock";
  cargoBuildFlags = [
    "--package"
    "bootvine"
  ];
  cargoTestFlags = [
    "--package"
    "bootvine"
  ];
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    dbus
    systemd
  ];

  postInstall = ''
    mkdir -p "$out/lib/systemd/system" "$out/share/doc/bootvine"
    cp -r bootvine/system-files/systemd/. "$out/lib/systemd/system/"
    cp LICENSE README.md "$out/share/doc/bootvine/"
  '';
}

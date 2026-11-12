{ lib, ... }:

{
  # First activation waits for CI to publish and verify the binary mirror pin.
  services.bootvine.enable = builtins.hasAttr "bootvine" (
    lib.importJSON ../../dependencies/mirrors.json
  );
}

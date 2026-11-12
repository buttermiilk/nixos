# Adapted from wvhulle/bootvine's nix/nixos-module.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.bootvine;
in
{
  options.services.bootvine = {
    enable = lib.mkEnableOption "Bootvine boot and shutdown progress on a virtual terminal";
    package = lib.mkPackageOption pkgs "bootvine" { };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    systemd = {
      packages = [ cfg.package ];
      services.bootvine.wantedBy = [ "sysinit.target" ];
      services.bootvine-shutdown.wantedBy = [ "shutdown.target" ];
    };
    boot.initrd.systemd = {
      packages = [ cfg.package ];
      storePaths = [ (lib.getExe cfg.package) ];
      services.bootvine.wantedBy = [ "sysinit.target" ];
    };
  };
}

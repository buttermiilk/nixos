{ lib, pkgs, ... }:

let
  installSober = pkgs.writeShellApplication {
    name = "install-sober";
    runtimeInputs = [ pkgs.flatpak ];
    text = builtins.readFile ../dotfiles/scripts/install-sober.sh;
  };
in
{

  systemd.user.services.install-sober = {
    Unit = {
      Description = "Ensure Sober is installed from Flathub for this user";
      StartLimitIntervalSec = 0;
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe installSober;
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "60s";
      TimeoutStartSec = "30min";
    };
    Install.WantedBy = [ "default.target" ];
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:

let

  powerLimit = pkgs.writeShellApplication {
    name = "power-limit";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
      config.services.tlp.package
    ];
    text = lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ./power-limit.sh);
  };
in
{
  environment.systemPackages = [ powerLimit ];
  boot.kernelModules = [ "intel_rapl_msr" ];
  systemd.tmpfiles.rules = [ "d /run/power-limit 0755 root root -" ];

  security.sudo.extraRules = [
    {
      users = [ "rin" ];
      commands =
        map
          (mode: {
            command = "/run/current-system/sw/bin/power-limit ${mode}";
            options = [ "NOPASSWD" ];
          })
          [
            "normal"
            "eco"
            "performance"
          ];
    }
  ];

  # Record native limits before our cap or thermal policy can change them.
  systemd.services.power-limit-baseline = {
    description = "Record firmware CPU package power limits";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    before = [
      "thermald.service"
      "tlp.service"
      "power-limit.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe powerLimit} capture";
    };
  };

  systemd.services.power-limit = {
    description = "Apply CPU package power cap for the selected mode";
    wantedBy = [
      "multi-user.target"
      "post-resume.target"
    ];
    after = [
      "power-limit-baseline.service"
      "thermald.service"
      "tlp.service"
      "post-resume.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe powerLimit} apply";
    };
  };

  systemd.timers.power-limit = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "10s";
      AccuracySec = "1s";
    };
  };
}

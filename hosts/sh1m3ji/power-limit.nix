{ lib, pkgs, ... }:

let
  # Firmware lets the i5-1235U sustain 23 W and boost to 51 W, more than this
  # chassis can shed: during osu! tourney streams the package hit its thermal
  # limit and the forced throttle stalled the game and OBS together (they
  # share the package). A lower sustained limit holds clocks steady instead.
  # `eco-mode` switches to the eco limits, which still keep a terminal, Zed
  # and Concord responsive. Firmware enforces the lower of the MSR and MMIO
  # limits, so both are written. The mode lives in /run, so like eco-mode it
  # resets to normal on reboot.
  powerLimit = pkgs.writeShellApplication {
    name = "power-limit";
    text = ''
      state=/run/power-limit-mode
      mode="''${1:-}"
      if [[ "$mode" == restore ]]; then
        mode=normal
        [[ -r "$state" ]] && mode=$(<"$state")
      fi

      # Watts: sustained (PL1) and short boost (PL2).
      case "$mode" in
        normal) pl1=18 pl2=30 ;;
        eco) pl1=7 pl2=12 ;;
        *)
          echo "usage: power-limit normal|eco|restore" >&2
          exit 2
          ;;
      esac

      for zone in /sys/class/powercap/intel-rapl:0 /sys/class/powercap/intel-rapl-mmio:0; do
        [[ -d "$zone" ]] || continue
        echo $((pl1 * 1000000)) >"$zone/constraint_0_power_limit_uw"
        echo $((pl2 * 1000000)) >"$zone/constraint_1_power_limit_uw"
      done
      echo "$mode" >"$state"
    '';
  };
in
{
  environment.systemPackages = [ powerLimit ];

  # Firmware restores its own limits on resume, so reapply then too.
  systemd.services.power-limit = {
    description = "Apply CPU package power limits";
    wantedBy = [
      "multi-user.target"
      "post-resume.target"
    ];
    after = [
      "thermald.service"
      "post-resume.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe powerLimit} restore";
    };
  };

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
          ];
    }
  ];
}

{ lib, pkgs, ... }:

let

  powerLimit = pkgs.writeShellApplication {
    name = "apply-package-power-cap";
    text = ''
      ceiling_uw=30000000
      found=0
      for zone in /sys/class/powercap/intel-rapl:0 /sys/class/powercap/intel-rapl-mmio:0; do
        [[ -d "$zone" ]] || continue
        found=1
        for constraint in 0 1; do
          name=$(<"$zone/constraint_''${constraint}_name")
          case "$constraint:$name" in
            0:long_term|1:short_term) ;;
            *) echo "Unexpected RAPL constraint: $zone/$constraint ($name)" >&2; exit 1 ;;
          esac
          limit_file="$zone/constraint_''${constraint}_power_limit_uw"
          current=$(<"$limit_file")
          if (( current > ceiling_uw )); then
            printf '%s\n' "$ceiling_uw" >"$limit_file"
            applied=$(<"$limit_file")
            if (( applied > ceiling_uw )); then
              echo "RAPL limit did not take effect: $limit_file=$applied" >&2
              exit 1
            fi
          fi
        done
      done
      if (( ! found )); then
        echo "No Intel package RAPL interface found" >&2
        exit 1
      fi
    '';
  };
in
{
  environment.systemPackages = [ powerLimit ];

  systemd.services.power-limit = {
    description = "Cap CPU package sustained and boost power at 30 W";
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
      ExecStart = lib.getExe powerLimit;
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

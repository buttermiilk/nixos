{ pkgs, ... }:

let
  chu2Exclusive = pkgs.writeShellScript "chu2-exclusive" ''
    chu2=0
    jacks=
    for d in /sys/bus/usb/devices/*; do
      [ -r "$d/idVendor" ] || continue
      case "$(${pkgs.coreutils}/bin/cat "$d/idVendor"):$(${pkgs.coreutils}/bin/cat "$d/idProduct")" in
        31b2:0113) chu2=1 ;;
        0020:0b21) jacks="$jacks $d" ;;
      esac
    done
    if [ "$ACTION" = remove ] && [ "''${PRODUCT%%/*}" = 31b2 ]; then
      chu2=0
    fi
    for d in $jacks; do
      echo $((1 - chu2)) > "$d/authorized"
    done
  '';
in
{
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;

    wireplumber.extraConfig."51-chu2-dsp" = {
      "monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = "~alsa_output.usb-KTMicro_Chu2_DSP.*"; } ];
          actions.update-props = {
            "audio.format" = "S16LE";
            "audio.rate" = 48000;
            "api.alsa.period-size" = 512;
            "api.alsa.period-num" = 3;
            "api.alsa.headroom" = 0;
          };
        }
      ];
    };
  };

  services.udev.extraRules = ''
    ACTION=="add|remove", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{PRODUCT}=="31b2/113/*|20/b21/*", RUN+="${chu2Exclusive}"
  '';
}

{ config, lib, pkgs, ... }:

let
  lockFile = ''
    general {
      immediate_render = true
    }

    background {
      monitor =
      path = $HOME/.config/wallpapers/linux.jpg
      color = rgba(25, 20, 20, 1.0)
      blur_passes = 1 # 0 disables blurring
      blur_size = 5
      vibrancy_darkness = 0.0
    }

    input-field {
      monitor =
      size = 200, 30
      outline_thickness = 2
      dots_size = 0.25 # Scale of input-field height, 0.2 - 0.8
      dots_spacing = 0.55 # Scale of dots' absolute size, 0.0 - 1.0
      dots_center = true
      dots_rounding = -1
      outer_color = rgba(242, 243, 244, 0.3)
      inner_color = rgba(242, 243, 244, 0.3)
      font_color = rgba(242, 243, 244, 0.75)
      fade_on_empty = false
      placeholder_text = # Text rendered in the input box when it's empty.
      hide_input = false
      check_color = rgba(204, 136, 34, 0)
      fail_color = rgba(204, 34, 34, 0.3) # if authentication fail change to this color
      fail_text = $FAIL <b>($ATTEMPTS)</b> # can be set to empty
      capslock_color = -1
      numlock_color = -1
      bothlock_color = -1 # when both locks are active. -1 means don't change outer color (same for above)
      invert_numlock = false # change color if numlock is off
      swap_font_color = false # see below
      position = 0, -472
      halign = center
      valign = center
    }

    label {
      monitor = 
      text = cmd[update:1000] echo "$(~/.config/scripts/audio/songStatus)"
      color = rgba(242, 243, 244, 0.75)
      font_size = 14
      font_family = SF Pro Text
      position = 20, 512
      halign = left
      valign = center
    }

    label {
      monitor =
      text = cmd[update:1000] echo "$(~/.config/scripts/network/stats)‎"
      color = rgba(242, 243, 244, 0.75)
      font_size = 16
      font_family = SF Pro Text
      position = -35, 512
      halign = right
      valign = center
    }

    label {
      monitor =
      text = cmd[update:1000] echo "$(~/.config/scripts/battery/stats)‎"
      color = rgba(242, 243, 244, 0.75)
      font_size = 19
      font_family = SF Pro Text
      position = -93, 512
      halign = right
      valign = center
    }

    label {
      monitor =
      text = cmd[update:1000] echo "$(~/.config/scripts/layoutStats)‎"
      color = rgba(242, 243, 244, 0.75)
      font_size = 15
      font_family = SF Pro Text
      position = -150, 512
      halign = right
      valign = center
    }

    label {
      monitor =
      text = cmd[update:1000] echo "$(date +"%A, %B %d")"
      color = rgba(242, 243, 244, 0.75)
      font_size = 20
      font_family = Inter Bold
      position = 0, 405
      halign = center
      valign = center
    }

    label {
      monitor = 
      text = cmd[update:1000] echo "$(date +"%k:%M")"
      color = rgba(242, 243, 244, 0.75)
      font_size = 93
      font_family = Inter Bold
      position = 0, 310
      halign = center
      valign = center
    }

    label {
      monitor =
      text = Rin 
      color = rgba(242, 243, 244, 0.75)
      font_size = 12
      font_family = Inter Bold
      position = 0, -407
      halign = center
      valign = center
    }

    label {
      monitor =
      text = Enter Password
      color = rgba(242, 243, 244, 0.75)
      font_size = 10
      font_family = Inter
      position = 0, -438
      halign = center
      valign = center
    }

    image {
      monitor =
      path = ~/wallpapers/pfp.png 
      border_color = 0xffdddddd
      border_size = 0
      size = 73
      rounding = -1
      rotate = 0
      reload_time = -1
      reload_cmd = 
      position = 0, -353
      halign = center
      valign = center
    }
  '';
in {
  home.file.".config/hypr/hyprlock.conf".text = lockFile;
}

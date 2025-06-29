{ config, lib, pkgs, ... }:

{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        immediate_render = true;
      };
      background = {
        path = "${config.home.homeDirectory}/.config/wallpapers/linux.jpg";
        color = "rgba(25,20,20,1)";
        blur_passes = 1;
        blur_size = 5;
        vibrancy_darkness = 0.0;
      };
      input-field = {
        size = "200, 30";
        outline_thickness = 2;
        dots_size = 0.25;
        dots_spacing = 0.55;
        dots_center = true;
        dots_rounding = -1;
        outer_color = "rgba(242, 243, 244, 0.3)";
        inner_color = "rgba(242, 243, 244, 0.3)";
        font_color = "rgba(242, 243, 244, 0.75)";
        fade_on_empty = false;
        placeholder_text = "";
        hide_input = false;
        check_color = "rgba(204, 136, 34, 0)";
        fail_color = "rgba(204, 34, 34, 0.3)";
        fail_text = "$FAIL <b>($ATTEMPTS)</b>";
        capslock_color = -1;
        numlock_color = -1;
        bothlock_color = -1;
        invert_numlock = false;
        swap_font_color = false;
        position = "0, -472";
        halign = "center";
        valign = "center";
      };
    };
    label = [
      {
        text = ''
          ${builtins.exec "bash -c '${config.home.homeDirectory}/.config/scripts/audio/songStatus'"}
        '';
        color = "rgba(242, 243, 244, 0.75)";
        font_size = 14;
        font_family = "Inter";
        position = "20, 512";
        halign = "left";
        valign = "center";
      }

      {
        text = ''
          ${builtins.exec "bash -c '${config.home.homeDirectory}/.config/scripts/network/stats'"}
        '';
        color = "rgba(242, 243, 244, 0.75)";
        font_size = 16;
        font_family = "Inter";
        position = "-35, 512";
        halign = "right";
        valign = "center";
      }

      {
        text = ''
          ${builtins.exec "bash -c '${config.home.homeDirectory}/.config/scripts/battery/stats'"}
        '';
        color = "rgba(242, 243, 244, 0.75)";
        font_size = 19;
        font_family = "Inter";
        position = "-93, 512";
        halign = "right";
        valign = "center";
      }

      {
        text = ''
          ${builtins.exec "bash -c '${config.home.homeDirectory}/.config/scripts/layoutStats'"}
        '';
        color = "rgba(242, 243, 244, 0.75)";
        font_size = 15;
        font_family = "Inter";
        position = "-150, 512";
        halign = "right";
        valign = "center";
      }

      {
        text = ''
          ${builtins.exec "bash -c 'date +\"%A, %B %d\"'"}
        '';
        color = "rgba(242, 243, 244, 0.75)";
        font_size = 20;
        font_family = "Inter Bold";
        position = "0, 405";
        halign = "center";
        valign = "center";
      }

      {
        text = ''
          ${builtins.exec "bash -c 'date +\"%k:%M\"'"}
        '';
        color = "rgba(242, 243, 244, 0.75)";
        font_size = 93;
        font_family = "Inter Bold";
        position = "0, 310";
        halign = "center";
        valign = "center";
      }

      {
        text = "Rin";
        color = "rgba(242, 243, 244, 0.75)";
        font_size = 12;
        font_family = "Inter Bold";
        position = "0, -407";
        halign = "center";
        valign = "center";
      }

      {
        text = "Enter Password";
        color = "rgba(242, 243, 244, 0.75)";
        font_size = 10;
        font_family = "Inter";
        position = "0, -438";
        halign = "center";
        valign = "center";
      }
    ];
    image = {
      path = "${config.home.homeDirectory}/wallpapers/pfp.png"; 
      border_color = "0xffdddddd";
      border_size = 0;
      size = 73;
      rounding = -1;
      rotate = 0;
      reload_time = -1;
      position = "0, -353";
      halign = "center";
      valign = "center";
    };
  };
}

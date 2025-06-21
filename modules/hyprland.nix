{ config, lib, pkgs, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;

    settings = {
      monitor = [ ",preferred,auto,1.25" ];

      exec-once = [
        "systemctl --user import-environment"
        "hyprpaper"
        "playerctld"
        "waybar"
        "wl-paste --watch cliphist store"
        # "hyprlock --immediate"
        "~/.config/scripts/battery/notif"
        "export GTK_IM_MODULE=fcitx5"
        "export QT_IM_MODULE=fcitx5"
        "export XMODIFIERS=@im=fcitx5"
        "export INPUT_METHOD=fcitx5"
        "export SDL_IM_MODULE=fcitx5"
        "fcitx5"
      ];

      input = {
        kb_layout = "us";
        follow_mouse = 2;
        touchpad.natural_scroll = "yes";
        sensitivity = 0;
      };

      general = {
        gaps_in = 4;
        gaps_out = 15;
        border_size = 0;
        col.active_border = "rgba(cba6f7ff) rgba(89b4faff) rgba(94e2d5ff) 10deg";
        col.inactive_border = "0xff45475a";
        layout = "master";
      };

      misc.disable_hyprland_logo = true;

      decoration = {
        rounding = 6;
        blur = {
          enabled = true;
          size = 3;
          passes = 3;
          new_optimizations = true;
        };
        shadow = {
          enabled = true;
          range = 60;
          render_power = 5;
          color = "rgba(42,52,57,50)";
          color_inactive = "0x22000000";
        };
        blurls = "lockscreen";
        dim_inactive = false;
        dim_strength = 0.5;
      };

      animations = {
        enabled = true;
        bezier = [
          "myBezier, 0.5, 1, 0.89, 1"
          "myBezier2, 0.22, 1, 0.36, 1"
        ];
        animation = [
          "windowsIn, 1, 7, myBezier2, popin"
          "windowsOut, 1, 25, myBezier2, slide bottom"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, myBezier, slide"
          "specialWorkspace, 1, 5, myBezier, slide"
        ];
      };

      dwindle = {
        pseudotile = "yes";
        force_split = 2;
        preserve_split = "yes";
      };

      master = {
        mfact = 0.5;
        new_status = "master";
        new_on_top = true;
        orientation = "left";
        allow_small_split = true;
        smart_resizing = false;
      };

      gestures = {
        workspace_swipe = "on";
        workspace_swipe_fingers = 3;
      };

      xwayland.force_zero_scaling = "on";

      windowrulev2 = [
        "float, title:^(fastfetch)$"
        "center,title:^(chat.openai.com_/)$"
        "size 800 600,title:^(chat.openai.com_/)$"
        "center,title:^(web.whatsapp.com_/)$"
        "size 750 700,title:^(web.whatsapp.com_/)$"
        "center,title:^(Open Files)$"
        "center,title:^(All Files)$"
        "center,title:^(Open File)$"
        "center,title:^(fastfetch)$"
        "size 790 350,title:^(fastfetch)$"
        "center,title:^(kitty)$"
        "size 750 750,title:^(File Upload)$"
        "opacity 1 1,class:^(thunar)$"
        "opacity 1 1, title:^(rofi)(.*)$"
        "float,title:^(ncmpcpp)$"
        "center,title:^(ncmpcpp)$"
        "size 1275 620,title:^(ncmpcpp)$"
      ];

      layerrule = [
        "blur, waybar"
        "ignorezero, waybar"
        "blur, notifications"
        "ignorezero, notifications"
        "blur, nwg-dock"
        "ignorealpha 1, nwg-dock"
      ];

      bind = [
        "$mainMod, T, exec, kitty"
        "$mainMod SHIFT, T, exec, [float] kitty"
        "$mainMod, A, killactive"
        "$mainMod, Escape, exec, hyprlock"
        "$mainMod, Q, exec, ~/.config/rofi/powerMenu"
        "$mainMod, X, exec, hyprctl kill"
        "$mainMod, E, exec, thunar"
        "$mainMod SHIFT, E, exec, [float] thunar"
        "$mainMod, V, togglefloating"
        ", $mainMod, exec, rofi -show drun"
        "$mainMod, P, pseudo"
        "$mainMod, J, togglesplit"
        "$mainMod, PRINT, exec, hyprshot -m window --clipboard-only"
        ", PRINT, exec, hyprshot -m output --clipboard-only"
        "SHIFT, PRINT, exec, hyprshot -m region --clipboard-only"
        "ALT, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy"
        "$mainMod SHIFT, B, exec, killall waybar && waybar & disown"
        "$mainMod, F, fullscreen"
        "$mainMod, B, exec, zen-browser"
        "$mainMod SHIFT, X, exec, hyprctl dispatch exit 0"
        "ALT, B, exec, blueman-manager"
        "$mainMod SHIFT, D, exec, ~/.config/scripts/doNotDisturb/toggle"
        "$mainMod, PERIOD, exec, playerctld shift"
        "$mainMod, COMMA, exec, playerctld unshift"
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"
        "$mainMod, l, movefocus, l"
        "$mainMod, h, movefocus, r"
        "$mainMod, k, movefocus, u"
        "$mainMod, j, movefocus, d"
        "$mainMod SHIFT, up, movewindow, u"
        "$mainMod SHIFT, down, movewindow, d"
        "$mainMod SHIFT, left, movewindow, l"
        "$mainMod SHIFT, right, movewindow, r"
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
        "$mainMod SHIFT, 0, movetoworkspace, 10"
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
      ];

      bindm = [
        "$mainMod, mouse:272, movewindow"
        "ALT, mouse:272, resizewindow"
      ];

      "$mainMod" = "SUPER";
      "$SCRIPT" = "~/.config/scripts/";
    };
  };
}

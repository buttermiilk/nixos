{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    dunst
    adwaita-icon-theme
  ];

  services.dunst = {
    enable = true;
    settings = {
      global = {
        monitor = 0;
        follow = "none";
        width = 300;
        height = 300;
        origin = "top-right";
        offset = "20x20";
        scale = 0;
        notification_limit = 20;

        progress_bar = true;
        progress_bar_height = 10;
        progress_bar_frame_width = 0;
        progress_bar_min_width = 125;
        progress_bar_max_width = 250;
        progress_bar_corner_radius = 4;

        icon_corner_radius = 5;
        indicate_hidden = true;

        transparency = 10;
        separator_height = 2;
        padding = 8;
        horizontal_padding = 8;
        text_icon_padding = 10;
        frame_width = 3;
        gap_size = 5;
        separator_color = "auto";
        sort = true;

        font = "JetBrainsMono Nerd Font 8";
        line_height = 3;
        markup = "full";
        format = "󰟪 %a\n<b>󰋑 %s</b>\n%b";
        alignment = "left";
        vertical_alignment = "center";
        show_age_threshold = 60;
        ellipsize = "middle";
        ignore_newline = false;
        stack_duplicates = true;
        hide_duplicate_count = false;
        show_indicators = true;

        icon_theme = "Adwaita";

        sticky_history = true;
        history_length = 20;

        dmenu = "/usr/bin/rofi -dmenu -p dunst:";
        browser = "/usr/bin/xdg-open";
        always_run_script = true;
        title = "Dunst";
        class = "Dunst";
        corner_radius = 10;
        ignore_dbusclose = false;

        force_xwayland = false;
        force_xinerama = false;
      };

      urgency_critical = {
        background = "#f5e0dc";
        foreground = "#1e1e2e";
        frame_color = "#f38ba8";
        timeout = 0;
      };
    };
  };
}

{ config, lib, pkgs, ... }:

{
  home.file.".config/waybar/config.jsonc".text = builtins.toJSON {
    layer = "top";
    position = "top";
    mod = "dock";
    exclusive = true;
    passthrough = false;
    gtk-layer-shell = true;
    height = 35;

    modules-left = [
      "custom/app-menu" "hyprland/window" "custom/files" "custom/browser"
      "custom/chats" "custom/terminal" "custom/clipboard" "custom/neovim"
    ];

    modules-center = [];

    modules-right = [
      "custom/media" "custom/wifi" "battery" "custom/recording"
      "tray" "custom/all-apps" "custom/do-not-disturb" "clock"
    ];

    "custom/app-menu" = {
      format = " ";
      on-click = "~/.config/rofi/appMenu";
      tooltip = false;
    };

    "hyprland/window" = {
      format = "{initialTitle}";
      rewrite = {
        "" = "Home";
        "kitty" = "Terminal";
        "Zen Browser" = "Zen Browser";
        "chat.openai.com_/" = "ChatGPT";
        "fastfetch" = "About Lappy";
        "Enter name of file to save to…" = "Save File";
        "Discord" = "Discord";
        "Spotify Free" = "Spotify";
      };
      tooltip = false;
    };

    "custom/files" = {
      format = "Files";
      on-click = "thunar";
      tooltip = false;
    };

    "custom/browser" = {
      format = "Browser";
      on-click = "zen-browser";
      tooltip = false;
    };

    "custom/chats" = {
      format = "Discord";
      on-click = "discord";
      tooltip = false;
    };

    "custom/terminal" = {
      format = "Terminal";
      on-click = "kitty";
      tooltip = false;
    };

    "custom/clipboard" = {
      format = "Clipboard";
      on-click = "cliphist list | rofi -dmenu | cliphist decode | wl-copy";
      tooltip = false;
    };

    "custom/neovim" = {
      format = "Neovim";
      on-click = "kitty zsh -i -c 'nvim'";
      tooltip = false;
    };

    "custom/media" = {
      format = "{}";
      escape = true;
      return-type = "json";
      max-length = 40;
      exec = "$HOME/.config/scripts/audio/mediaplayer.py 2> /dev/null";
      tooltip = false;
    };

    "custom/wifi" = {
      exec = "$HOME/.config/scripts/network/stats 2> /dev/null";
      tooltip = false;
      interval = 60;
      on-click = "exec ~/.config/rofi/wifiMenu";
    };

    battery = {
      bat = "BAT1";
      interval = 60;
      states = { critical = 21; };
      format = "{icon}";
      format-icons = [ " " " " " " " " " " ];
      format-charging = "  {capacity}%";
      format-critical = " {capacity}%";
      tooltip = false;
    };

    tray = {
      icon-size = 15;
      spacing = 9;
      tooltip = false;
    };

    "custom/all-apps" = {
      format = " ";
      on-click = "rofi -show drun";
      tooltip = false;
    };

    "custom/do-not-disturb" = {
      exec = "~/.config/scripts/doNotDisturb/stats";
      return-type = "json";
      format = "{icon}";
      format-icons = {
        "true" = " ";
        "false" = "";
      };
      interval = "once";
      signal = 1;
    };

    clock = {
      interval = 60;
      format = "{:%a %b %d %I:%M %p}";
      tooltip = false;
    };
  };
  home.file.".config/waybar/style.css".text = ''
    * {
      font-family: Inter, sans-serif;
      font-size: 12
    }

    window#waybar {
      background-color: rgba(111, 111, 111, 0.4);
    }

    #custom-app-menu,
    #window,
    #custom-files,
    #custom-browser,
    #custom-chats,
    #custom-terminal,
    #custom-clipboard,
    #custom-neovim,
    #custom-media,
    #custom-wifi,
    #battery,
    #tray,
    #custom-chatgpt,
    #custom-all-apps,
    #custom-recording,
    #custom-do-not-disturb,
    #clock {
      color: #1b1b1b;
      padding: 2px 0px 2px 0px;
      font-weight: 500;
    }

    #custom-app-menu {
      font-size: 15;
      margin-left: 14px;
      padding: 1px 0px 3px 0px;
    }

    #window {
      font-weight: bold;
      margin-left: 15px;
    }

    #custom-files {
      margin-left: 18px;
    }

    #custom-browser {
      margin-left: 18px;
    }

    #custom-chats {
      margin-left: 18px;
    }

    #custom-terminal {
      margin-left: 18px;
    }

    #custom-clipboard {
      margin-left: 18px;
    }

    #custom-neovim {
      margin-left: 18px;
    }

    #custom-media {
      font-size: 11;
      margin-right: 27px;
    }

    #battery {
      font-size: 17;
      margin-right: 17px;
    }

    #battery.charging {
      font-size: 11;
    }

    #battery.critical {
      font-size: 11;
    }

    #custom-wifi {
      font-size: 16;
      margin-right: 17px;
    }

    #custom-chatgpt {
      font-size: 13;
      margin-left: 13px;
    }

    #custom-all-apps {
      font-size: 13;
      margin-left: 17px;
    }

    #custom-recording {
      font-size: 12;
      margin-right: 15px;
    }

    #custom-do-not-disturb {
      margin-left: 17px;
    }

    #clock {
      margin-left: 15px;
      margin-right: 14px;
    }
  '';
}

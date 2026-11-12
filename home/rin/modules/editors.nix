{
  config,
  osConfig,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    neovim
    jetbrains.clion
  ];

  programs.zed-editor = {
    enable = true;
    extensions = [
      "nix"
      "astro"
      "toml"
      "discord-presence"
    ];
    userSettings = {
      base_keymap = "VSCode";
      auto_update = false;
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
      disable_ai = true;
      cli_default_open_behavior = "existing_window";
      buffer_font_family = "FantasqueSansM Nerd Font";
      buffer_font_size = 17;
      buffer_font_features.calt = true;
      ui_font_family = "Adwaita Sans";
      ui_font_size = 16;
      tab_size = 2;
      soft_wrap = "editor_width";
      preferred_line_length = 70;
      relative_line_numbers = "enabled";
      vertical_scroll_margin = 2;
      scroll_beyond_last_line = "vertical_scroll_margin";
      max_tabs = 3;
      minimap.show = "never";
      autosave.after_delay.milliseconds = 1000;
      format_on_save = "on";

      languages.Nix.language_servers = [
        "nixd"
        "!nil"
      ];
      lsp.nixd.settings =
        let
          flake = ''(builtins.getFlake "${config.home.homeDirectory}/nixConfig")'';
          host = "${flake}.nixosConfigurations.${osConfig.networking.hostName}";
        in
        {
          formatting.command = [ "nixfmt" ];
          nixpkgs.expr = "${host}.pkgs";
          options = {
            nixos.expr = "${host}.options";
            home-manager.expr = "${host}.options.home-manager.users.type.getSubOptions [ ]";
          };
        };

      lsp.discord_presence.initialization_options = {
        application_id = "1263505205522337886";
        base_icons_url = "https://raw.githubusercontent.com/xhyrom/zed-discord-presence/main/assets/icons/";
        state = "Probably checking {filename}";
        details = "In the silly room";
        large_image = "{base_icons_url}/{language:lo}.png";
        large_text = "{language:u}";
        small_image = "{base_icons_url}/zed.png";
        small_text = "Zed";
        idle = {
          timeout = 9999;
          action = "change_activity";
          state = "Idling";
          details = "In the silly room";
          large_image = "{base_icons_url}/zed.png";
          large_text = "Zed";
          small_image = "{base_icons_url}/idle.png";
          small_text = "Idle";
        };
        git_integration = false;
      };
    };
  };
}

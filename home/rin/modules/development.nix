{
  config,
  inputs,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  tomlFormat = pkgs.formats.toml { };

  codexHome =
    if config.home.preferXdgDirectories then
      "${config.xdg.configHome}/codex"
    else
      "${config.home.homeDirectory}/.codex";
in
{
  home.packages = with pkgs; [
    cargo
    rustc
    python3
    nodejs_24 # Includes npm
    pnpm
    bun
    flyctl
    gh
    inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default

    # pdf tools
    poppler-utils
    python3Packages.pymupdf
    qpdf
    ghostscript

    neovim

    # X11 automation (click, type, move/resize windows) for driving GUI apps
    # from scripts and agents.
    xdotool

    # Antigravity CLI from the flake input
    inputs.antigravity.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli

    # Language servers for Zed, one per toolchain above. They go on the
    # normal PATH, not programs.zed-editor.extraPackages: Zed looks servers
    # up in the project's login-shell environment, which never sees that
    # wrapper's PATH. The servers Zed downloads itself are generic Linux
    # binaries that NixOS can't run reliably.
    nixd
    nixfmt
    rust-analyzer
    basedpyright
    ruff
    # Node: TS/JS, Astro, Tailwind, and HTML/CSS/JSON/ESLint
    vtsls
    astro-language-server
    tailwindcss-language-server
    vscode-langservers-extracted
    # Shell scripts in dotfiles/scripts
    bash-language-server
    shellcheck
    # TOML (Cargo, wrangler)
    taplo
  ];

  programs.codex = {
    enable = true;

    package = inputs.codex-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;

    settings = {
      model = "gpt-5.6-sol";
      model_reasoning_effort = "high";

      approvals_reviewer = "auto_review";

      projects = {
        "/home/rin/nixConfig".trust_level = "trusted";
        "/home/rin/Documents/Dev/bot".trust_level = "trusted";
        "/home/rin/Documents/Dev/blender".trust_level = "trusted";
        "/home/rin/Documents/Dev/deliveratool".trust_level = "trusted";
        "/home/rin/Documents/Dev/lld-front".trust_level = "trusted";
        "/home/rin/Documents/Dev/milk".trust_level = "trusted";
        "/home/rin/Documents/Dev/outline-lld".trust_level = "trusted";
        "/home/rin/Documents/Dev/outline-lld-db".trust_level = "trusted";
        "/home/rin/Documents/Dev/vot-web".trust_level = "trusted";
        "/home/rin/Documents/Dev/etoh-datapack".trust_level = "trusted";
        "/home/rin/.var/app/org.vinegarhq.Sober/config/sober".trust_level = "trusted";
        "/home/rin/Documents/Dev/ref-bot".trust_level = "trusted";
        "/home/rin/Documents/Dev/osu-skill".trust_level = "trusted";
        "/home/rin/Documents/Dev/randomizer".trust_level = "trusted";
        "/home/rin/Documents/Rev/someRandomThing.rep".trust_level = "trusted";
        "/home/rin/Documents/Dev/stopmotion".trust_level = "trusted";
        "/home/rin/Documents/Dev/quals".trust_level = "trusted";
        "/home/rin/Documents/tosu-patched/static/vot6-overlay".trust_level = "trusted";
        "/home/rin/.local/share/osuconfig/tosu/static/vot6-overlay".trust_level = "trusted";
        "/home/rin/Documents/Dev/visuals".trust_level = "trusted";
        "/home/rin/Documents/Dev/storyboarder".trust_level = "trusted";
        "/home/rin/Documents/Dev/beatblockMinecraft".trust_level = "trusted";
        "/home/rin/Documents/Dev/lld-bot".trust_level = "trusted";
      };

      notice.hide_rate_limit_model_nudge = true;

      tui.model_availability_nux = {
        "gpt-5.6-sol" = 4;
        "gpt-6-astra" = 4;
      };

      # provider with sort of a nice token pricing,
      # in case the sub runs out.
      # not used frequently.
      model_providers.modelapi = {
        name = "ModelAPI";
        base_url = "https://modelapi.vn/v1";
        wire_api = "responses";
        auth = {
          command = lib.getExe' pkgs.coreutils "cat";
          args = [
            osConfig.sops.secrets."rin/modelapi-key".path
          ];
        };
      };

      mcp_servers.blender = {
        command = lib.getExe pkgs.blender-mcp;
        default_tools_approval_mode = "prompt";
        startup_timeout_sec = 20;
        tool_timeout_sec = 120;
      };
    };
  };

  home.file."${codexHome}/modelapi.config.toml".source =
    tomlFormat.generate "codex-modelapi.config.toml"
      {
        model_provider = "modelapi";
      };

  home.file."${codexHome}/chatgpt.config.toml".source =
    tomlFormat.generate "codex-chatgpt.config.toml"
      {
        model_provider = "openai";
      };

  programs.vscodium = {
    enable = true;
    package = pkgs.vscodium;

    profiles.default.userSettings = {
      "editor.tabSize" = 2;
      "editor.fontSize" = 17;
      "editor.wordWrap" = "bounded";
      "editor.wordWrapColumn" = 85;
      "editor.minimap.enabled" = false;
      "files.autoSave" = "afterDelay";
      "editor.formatOnSave" = true;
      "markdown-preview-enhanced.previewTheme" = "github-dark.css";
      "editor.fontFamily" = "'FantasqueSansM Nerd Font', monospace";
      # Fantasque Sans Mono's ligatures are contextual alternates (calt).
      "editor.fontLigatures" = "'calt'";
      "git.autofetch" = true;
      "security.workspace.trust.untrustedFiles" = "open";
    };
  };

  # Native GPU renderer instead of Chromium's; mirrors the VSCodium setup above.
  programs.zed-editor = {
    enable = true;

    # Same coverage as VSCodium's nix-ide and Astro extensions.
    extensions = [
      "nix"
      "astro"
      "toml"
      "discord-presence"
    ];
    userSettings = {
      base_keymap = "VSCode";
      # Nix owns updates; Zed can't replace itself in the store anyway.
      auto_update = false;
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
      disable_ai = true;
      cli_default_open_behavior = "existing_window";

      buffer_font_family = "FantasqueSansM Nerd Font";
      buffer_font_size = 17;
      # Fantasque Sans Mono's ligatures are contextual alternates (calt).
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
          # Completion and docs come from this flake's own nixpkgs, NixOS and
          # Home Manager options rather than whatever <nixpkgs> resolves to.
          flake = ''(builtins.getFlake "${config.home.homeDirectory}/nixConfig")'';
          host = "${flake}.nixosConfigurations.${osConfig.networking.hostName}";
        in
        {
          formatting.command = [ "nixfmt" ];
          nixpkgs.expr = "import ${flake}.inputs.nixpkgs { }";
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

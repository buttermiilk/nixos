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
    if config.home.preferXdgDirectories
    then "${config.xdg.configHome}/codex"
    else "${config.home.homeDirectory}/.codex";
in
{
  home.packages = with pkgs; [
    cargo
    rustc
    python3
    nodejs_24 # Includes npm
    pnpm
    flyctl
    gh

    # pdf tools
    poppler-utils
    python3Packages.pymupdf
    qpdf
    ghostscript

    neovim

    # Antigravity IDE and CLI from the flake input
    inputs.antigravity.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-ide
    inputs.antigravity.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli
  ];

  programs.codex = {
    enable = true;

    package =
      inputs.codex-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;

    settings = {
      model = "gpt-5.6-sol";
      model_reasoning_effort = "high";

      disable_response_storage = true;
      network_access = "enabled";

      approvals_reviewer = "auto_review";

      projects = {
        "/home/rin/nixConfig".trust_level = "trusted";
        "/home/rin/Documents/Dev/blender".trust_level = "trusted";
        "/home/rin/Documents/Dev/lld-front".trust_level = "trusted";
        "/home/rin/Documents/Dev/milk".trust_level = "trusted";
        "/home/rin/Documents/Dev/vot-web".trust_level = "trusted";
        "/home/rin/Documents/Dev/etoh-datapack".trust_level = "trusted";
        "/home/rin/.var/app/org.vinegarhq.Sober/config/sober".trust_level = "trusted";
        "/home/rin/Documents/Dev/ref-bot".trust_level = "trusted";
        "/home/rin/Documents/Dev/osu-skill".trust_level = "trusted";
        "/home/rin/Documents/Dev/randomizer".trust_level = "trusted";
        "/home/rin/Documents/Rev/someRandomThing.rep".trust_level = "trusted";
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
    tomlFormat.generate "codex-modelapi.config.toml" {
      model_provider = "modelapi";
    };

  home.file."${codexHome}/chatgpt.config.toml".source =
    tomlFormat.generate "codex-chatgpt.config.toml" {
      model_provider = "openai";
    };

  programs.vscodium = {
    enable = true;
    package = pkgs.vscodium;

    profiles.default.userSettings = {
      "editor.tabSize" = 2;
      "editor.fontSize" = 15;
      "editor.wordWrap" = "bounded";
      "editor.wordWrapColumn" = 75;
      "editor.minimap.enabled" = false;
      "files.autoSave" = "afterDelay";
      "editor.formatOnSave" = true;
      "markdown-preview-enhanced.previewTheme" = "github-dark.css";
      "editor.fontFamily" = "'Fantasque Sans Mono', 'Droid Sans Mono', monospace";
      "git.autofetch" = true;
      "security.workspace.trust.untrustedFiles" = "open";
    };
  };
}

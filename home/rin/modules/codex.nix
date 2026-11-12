{
  config,
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
  configFileKey =
    if config.home.preferXdgDirectories then
      "${lib.removePrefix config.home.homeDirectory config.xdg.configHome}/codex/config.toml"
    else
      ".codex/config.toml";
  baseSettings = tomlFormat.generate "codex-base-config.toml" config.programs.codex.settings;
  trustPolicy = pkgs.writeText "codex-trusted-project-globs.json" (
    builtins.toJSON config.programs.codex.trustedProjectGlobs
  );
  python = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);
  syncConfig = pkgs.writeShellApplication {
    name = "sync-codex-config";
    runtimeEnv.CODEX_DEFAULT_HOME = codexHome;
    text = ''
      exec ${lib.getExe python} ${./codex/sync-config.py} \
        --home "''${CODEX_HOME:-$CODEX_DEFAULT_HOME}" \
        --base ${baseSettings} --policy ${trustPolicy} "$@"
    '';
  };
  configuredCodex = pkgs.symlinkJoin {
    name = "codex-configured-${pkgs.codex-cli.version}";
    inherit (pkgs.codex-cli) version meta;
    paths = [ pkgs.codex-cli ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/codex" --run ${lib.escapeShellArg (lib.getExe syncConfig)}
    '';
    passthru.unwrapped = pkgs.codex-cli;
  };
in
{
  options.programs.codex.trustedProjectGlobs = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ "${config.home.homeDirectory}/Documents/Dev/*" ];
    description = "Directory globs expanded locally.";
  };

  config = {
    # This file is generated locally rather than linked into the public Nix store.
    home.file.${configFileKey}.enable = lib.mkForce false;
    home.packages = [ syncConfig ];
    home.activation.captureCodexConfig = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
      run ${lib.getExe syncConfig} --capture
    '';
    home.activation.syncCodexConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${lib.getExe syncConfig}
    '';

    programs.codex = {
      enable = true;

      package = configuredCodex;

      settings = {
        model = "gpt-6.1-sol";
        model_reasoning_effort = "high";

        approvals_reviewer = "auto_review";

        projects."${config.home.homeDirectory}/nixConfig".trust_level = "trusted";

        notice.hide_rate_limit_model_nudge = true;

        tui.model_availability_nux = {
          "gpt-6.1-sol" = 4;
          "gpt-6-astra" = 4;
        };

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
  };
}

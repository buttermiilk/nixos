{ inputs }:

{
  # External recipes are built with the host's pkgs; their helper flakes are unused.
  overlay =
    final: _prev:
    let
      blenderMcp = (final.lib.importJSON ./upstream.json).blender-mcp;
      blenderMcpSource = final.fetchgit {
        inherit (blenderMcp) url rev hash;
        fetchSubmodules = false;
      };
    in
    {
      codex-cli = final.callPackage "${inputs.codex-nix}/package.nix" { };
      claude-code-cli = final.callPackage "${inputs.claude-code-nix}/package.nix" { };
      google-antigravity-cli = final.callPackage "${inputs.antigravity}/pkgs/cli.nix" { };
      discord-lean = final.callPackage "${inputs.nixcord}/pkgs/discord" { withTTS = false; };

      blender-mcp = final.callPackage ./packages/blender-mcp.nix {
        src = blenderMcpSource;
        inherit (blenderMcp) version;
      };
      blender-mcp-extension = final.callPackage ./packages/blender-mcp-extension.nix {
        src = blenderMcpSource;
        inherit (blenderMcp) version;
      };
      blender-with-mcp = final.callPackage ./packages/blender-with-mcp.nix {
        blenderMcpExtension = final.blender-mcp-extension;
      };
      concord-client = final.callPackage ./packages/concord.nix { };
      bootvine = final.callPackage ./packages/bootvine.nix { };
      bongocat-osu = final.callPackage ./packages/bongocat-osu.nix { };
      taiko-editor = final.callPackage ./packages/taiko-editor.nix { };
      monitask = final.callPackage ./packages/monitask.nix { };
      tosu = final.callPackage ./packages/tosu.nix { };
      neuro-cursor = final.callPackage ./packages/neuro-cursor.nix { };
      osu-winello-icon = ./assets/osu-winello.png;
    };

  packages =
    pkgs:
    {
      osu-winello-icon = pkgs.runCommand "osu-winello-icon" { } ''
        cp ${./assets/osu-winello.png} "$out"
      '';
      inherit (pkgs)
        codex-cli
        claude-code-cli
        google-antigravity-cli
        discord-lean
        blender-mcp
        blender-mcp-extension
        blender-with-mcp
        concord-client
        bongocat-osu
        taiko-editor
        monitask
        tosu
        neuro-cursor
        ;
    }
    // pkgs.lib.optionalAttrs ((builtins.fromJSON (builtins.readFile ./mirrors.json)) ? bootvine) {
      inherit (pkgs) bootvine;
    };

  # Hardware choices belong to each host; the catalog supplies named modules.
  hardwareModules = {
    intel = inputs.nixos-hardware.nixosModules.common-cpu-intel;
    laptop = inputs.nixos-hardware.nixosModules.common-pc-laptop;
    ssd = inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd;
  };

  nixosModules = [
    ./modules/bootvine.nix
    inputs.disko.nixosModules.disko
    inputs.sops-nix.nixosModules.sops
    inputs.artcraft.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
  ];
  homeModules = [
    inputs.zen-browser.homeModules.beta
    inputs.nixcord.homeModules.nixcord
  ];
  diskoPackage = system: inputs.disko.packages.${system}.disko;
}

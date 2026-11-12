{
  description = "sh1m3ji — rin's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    antigravity = {
      url = "github:jacopone/antigravity-nix";
      flake = false;
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake/beta";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    codex-nix = {
      url = "github:sadjow/codex-cli-nix";
      flake = false;
    };

    claude-code-nix = {
      url = "git+https://github.com/sadjow/claude-code-nix.git?ref=main";
      flake = false;
    };

    nixcord = {
      url = "github:4evy/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";

      inputs.nixpkgs-packages.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    artcraft = {
      url = "github:ipeglin/artcraft-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      system = "x86_64-linux";
      dependencies = import ./dependencies { inherit inputs; };
      sh1m3ji = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit dependencies; };
        modules = [
          ./hosts/sh1m3ji
          ./hosts/sh1m3ji/integrations.nix
        ];
      };
      pkgs = sh1m3ji.pkgs;
      manifest = import ./backup/manifest.nix;
      tools = {
        authorize-google-drive = pkgs.callPackage ./tools/authorize-google-drive.nix { };
        restore-sh1m3ji = pkgs.callPackage ./tools/restore-sh1m3ji.nix {
          defaultSecretsFile = ./secrets/secrets.yaml;
          inherit manifest;
        };
      };
      mkApp = package: {
        type = "app";
        program = nixpkgs.lib.getExe package;
        meta.description = package.meta.description or package.name;
      };
    in
    {
      nixosConfigurations.sh1m3ji = sh1m3ji;
      overlays.default = dependencies.overlay;
      formatter.${system} = pkgs.nixfmt-tree;
      packages.${system} =
        dependencies.packages pkgs
        // tools
        // {
          disko = dependencies.diskoPackage system;
          concord = pkgs.concord-client;
        };
      apps.${system} = builtins.mapAttrs (_: mkApp) tools;
      devShells.${system} = import ./devshells { inherit pkgs; };
      checks.${system} = import ./checks {
        inherit pkgs manifest;
        host = sh1m3ji;
      };
    };
}

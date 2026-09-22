{
  description = "sh1m3ji — rin's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # per-machine quirks maintained by the community (Intel laptop profiles)
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # antigravity for testing, maintained by the community
    antigravity = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Blender Lab's official MCP server and Blender extension.
    blender-mcp = {
      url = "git+https://projects.blender.org/lab/blender_mcp.git?ref=refs/tags/v1.0.0";
      flake = false;
    };

    # declarative disk partitioning — the btrfs layout lives in hosts/sh1m3ji/disko.nix
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # secrets encrypted in-repo, decrypted at boot with a root-owned age key
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Firefox-based browser with a Home Manager module for declarative profiles,
    # policies, extensions, spaces, pins, and other Zen-specific state.
    zen-browser = {
      # Follow stable/beta releases instead of the nightly Twilight channel.
      url = "github:0xc000022070/zen-browser-flake/beta";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # codex cli isn't in nixpkgs
    codex-nix = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixcord
    # basically just discord with vencord that's declarative
    nixcord = {
      url = "github:4evy/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      nixos-hardware,
      disko,
      home-manager,
      sops-nix,
      ...
    }:
    let
      system = "x86_64-linux";
      backupManifest = import ./backup/manifest.nix;

      overlay = final: _prev: {
        blender-mcp = final.callPackage ./pkgs/blender-mcp.nix {
          src = inputs.blender-mcp;
        };
        blender-mcp-extension = final.callPackage ./pkgs/blender-mcp-extension.nix {
          src = inputs.blender-mcp;
        };
        blender-with-mcp = final.callPackage ./pkgs/blender-with-mcp.nix {
          blenderMcpExtension = final.blender-mcp-extension;
        };
        bongocat-osu = final.callPackage ./pkgs/bongocat-osu.nix { };
        taiko-editor = final.callPackage ./pkgs/taiko-editor.nix { };
        material-icon-font = final.callPackage ./pkgs/material-icon-font.nix { };
        tiny10-vm = final.callPackage ./pkgs/tiny10-vm.nix { };
        neuro-cursor = final.callPackage ./pkgs/neuro-cursor.nix {
          src = ./home/rin/dotfiles/neuro-cursor/theme;
        };
      };

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ overlay ];
      };

      authorizeGoogleDrive = pkgs.callPackage ./pkgs/authorize-google-drive.nix { };
      restoreSh1m3ji = pkgs.callPackage ./pkgs/restore-sh1m3ji.nix {
        defaultSecretsFile = ./secrets/secrets.yaml;
        manifest = backupManifest;
      };
      backupManifestCheck = import ./checks/backup-manifest.nix {
        inherit pkgs;
        lib = nixpkgs.lib;
        manifest = backupManifest;
      };

      sh1m3ji = nixpkgs.lib.nixosSystem {
        inherit system;
        # Make flake-provided packages visible to Home Manager modules.
        specialArgs = { inherit inputs; };
        modules = [
          nixos-hardware.nixosModules.common-cpu-intel
          nixos-hardware.nixosModules.common-pc-laptop
          nixos-hardware.nixosModules.common-pc-laptop-ssd

          disko.nixosModules.disko
          sops-nix.nixosModules.sops

          # Apply the custom-packages overlay to the NixOS module system so
          # that host and Home Manager modules can use pkgs.bongocat-osu, etc.
          { nixpkgs.overlays = [ overlay ]; }

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.backupFileExtension = "hm-bak";
            home-manager.users.rin = import ./home/rin;
          }

          ./hosts/sh1m3ji
        ];
      };
    in
    {
      formatter.${system} = pkgs.nixfmt-tree;

      overlays.default = overlay;

      packages.${system} = {
        # Use the exact Disko version pinned in flake.lock during installation.
        disko = disko.packages.${system}.disko;
        authorize-google-drive = authorizeGoogleDrive;
        inherit (pkgs)
          blender-mcp
          blender-mcp-extension
          blender-with-mcp
          bongocat-osu
          material-icon-font
          neuro-cursor
          taiko-editor
          tiny10-vm
          ;
        restore-sh1m3ji = restoreSh1m3ji;
      };

      apps.${system} = {
        restore-sh1m3ji = {
          type = "app";
          program = "${restoreSh1m3ji}/bin/restore-sh1m3ji";
          meta.description = "Restore the encrypted sh1m3ji snapshot from a live ISO";
        };
        authorize-google-drive = {
          type = "app";
          program = "${authorizeGoogleDrive}/bin/authorize-google-drive";
          meta.description = "Authorize rclone and store its Google token through SOPS";
        };
      };

      nixosConfigurations.sh1m3ji = sh1m3ji;
      checks.${system} = {
        sh1m3ji = sh1m3ji.config.system.build.toplevel;
        backup-manifest = backupManifestCheck;
      };
    };
}

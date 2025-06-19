{
  description = "just learning flakes";

  # declaring the inputs of the outputs function
  # nix will fetch everything from the inputs
  # then make it available to the outputs function
  inputs = {
    # nixpkgs input
    # this will expose a variable 'nixpkgs' to outputs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # home-manager input
    # this exposes 'home-manager'
    home-manager.url = "github:nix-community/home-manager";
    # we make home-manager follow our nixpkgs declaration
    # so the dependency tree does not get flooded later
    # here we "reroute" the nixpkgs input of the package
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  # the outputs function
  # 'self' is referring to this flake file
  # so when we call 'self', nix will re-evaluate this file
  # and use what we declared in this flake file
  # the elipsis '...' allows us to pass more things
  # to our inputs and not pollute the function call
  # or break our existing implementation
  # we make use of the other variables using
  # the 'input' wrapper, so:
  # 'input.var.things' etc.
  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      # you can import hardware-configuration
      # to fill this in
      system = "x86_64-linux";
      # we now actually import the nixpkgs collection
      # the goods of flakes is that we have now *pinned*
      # the version of nixpkgs we want to use,
      # not whatever the system is packed with
      # in other files, you would have to use <nixpkgs>
      # and lose reproducibility, which is bad
      pkgs = import nixpkgs {
        # tell nix we're targeting this architecture
        inherit system;
        # tell nix we might want proprietary software
        config.allowUnfree = true;
      };
      # import our devShells configurations
      # these are just basic syntax; find them in the respective files
      tsSh = import ./environments/typescript.nix { inherit pkgs; };
      pySh = import ./environments/python.nix     { inherit pkgs; };
      cpSh = import ./environments/cpp.nix        { inherit pkgs; };
      dkSh = import ./environments/docker.nix     { inherit pkgs; };
    in {
      nixosConfiguration = {
        NAVI = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/NAVI.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.rin = import ./home/rin.nix;
            }
          ];
        }
      };
      
      devShells.${system} = {
        typescript = tsSh;
        python = pySh;
        cpp = cpSh;
        docker = dkSh;
      }
    }
}
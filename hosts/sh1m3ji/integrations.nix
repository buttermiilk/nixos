{ dependencies, ... }:

{
  imports =
    (with dependencies.hardwareModules; [
      intel
      laptop
      ssd
    ])
    ++ dependencies.nixosModules;
  nixpkgs.overlays = [ dependencies.overlay ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    sharedModules = dependencies.homeModules;
    backupFileExtension = "hm-bak";
    users.rin = import ../../home/rin;
  };
}

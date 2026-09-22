# Replace the root Btrfs subvolume before it is mounted. Persistent state is
# mounted directly from the sibling subvolumes declared in disko.nix.
{ lib, pkgs, ... }:

let
  rollbackRoot = pkgs.writeShellApplication {
    name = "rollback-root";
    runtimeInputs = [
      pkgs.btrfs-progs
      pkgs.coreutils
      pkgs.findutils
      pkgs.util-linux
    ];
    text = builtins.readFile ../../home/rin/dotfiles/scripts/rollback-root.sh;
  };
in
{
  boot.initrd.systemd = {
    enable = true;
    storePaths = [ rollbackRoot ];

    services.rollback-root = {
      description = "Create a fresh Btrfs root subvolume";
      requires = [ "systemd-cryptsetup@crypted.service" ];
      after = [
        "initrd-root-device.target"
        "systemd-cryptsetup@crypted.service"
      ];
      before = [ "sysroot.mount" ];
      requiredBy = [ "initrd.target" ];

      unitConfig.DefaultDependencies = "no";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe rollbackRoot;
        StandardOutput = "journal+console";
        StandardError = "journal+console";
      };
    };
  };

  fileSystems."/".neededForBoot = true;
  fileSystems."/nix".neededForBoot = true;
  fileSystems."/persist".neededForBoot = true;
  fileSystems."/var/log".neededForBoot = true;
  fileSystems."/var/lib/nixos".neededForBoot = true;
}

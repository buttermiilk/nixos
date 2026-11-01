# Declarative partition layout, applied once at install time by disko.
# Dell WD SN530 256 GB: 1 GiB ESP, then LUKS2/Btrfs using the remaining space.
# Replaces Windows and its recovery partitions; no dual boot.
# `/root` is replaced with an empty subvolume during early boot by rollback.nix.
# State survives only through the direct mounts below; no bind mounts are used.
let
  btrfsMountOpts = [
    "compress=zstd"
    "noatime"
  ];
in
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/nvme0n1"; # WD PC SN530 256 GB — verify with `lsblk` in the live ISO!
      content = {
        type = "gpt";
        partitions = {
          esp = {
            # Room for kernels/initrds across the five retained boot entries.
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "luks";
              name = "crypted";
              # Disko prompts twice for the boot passphrase during formatting.
              # It also prints a separate recovery key that must be stored off-disk.
              enrollRecovery = true;
              extraFormatArgs = [
                "--type"
                "luks2"
              ];
              settings.allowDiscards = true;
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "/root" = {
                    mountpoint = "/";
                    mountOptions = btrfsMountOpts;
                  };
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = btrfsMountOpts;
                  };
                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = btrfsMountOpts;
                  };
                  "/persist" = {
                    mountpoint = "/persist";
                    mountOptions = btrfsMountOpts;
                  };
                  "/var-log" = {
                    mountpoint = "/var/log";
                    mountOptions = btrfsMountOpts;
                  };
                  "/var-lib-nixos" = {
                    mountpoint = "/var/lib/nixos";
                    mountOptions = btrfsMountOpts;
                  };
                  "/var-lib-systemd" = {
                    mountpoint = "/var/lib/systemd";
                    mountOptions = btrfsMountOpts;
                  };
                  "/var-lib-bluetooth" = {
                    mountpoint = "/var/lib/bluetooth";
                    mountOptions = btrfsMountOpts;
                  };
                  "/var-lib-cloudflare-warp" = {
                    mountpoint = "/var/lib/cloudflare-warp";
                    mountOptions = btrfsMountOpts;
                  };
                  "/networkmanager-connections" = {
                    mountpoint = "/etc/NetworkManager/system-connections";
                    mountOptions = btrfsMountOpts;
                  };
                  "/swap" = {
                    mountpoint = "/swap";
                    # Overflow behind zram; suspend-to-disk is not configured.
                    swap.swapfile.size = "8G";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}

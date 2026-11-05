

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
      device = "/dev/nvme0n1";
      content = {
        type = "gpt";
        partitions = {
          esp = {

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

# sh1m3ji quickstart

This is the normal reinstall path: the machine age key still exists, the
repository is on GitHub, and the target is the HP EliteBook's internal NVMe.
For explanations, lost-key recovery, or ISO repair, use [WIKI.md](./WIKI.md).

> [!CAUTION]
> Disko erases the device named in `hosts/sh1m3ji/disko.nix`. The expected
> device is `/dev/nvme0n1`. Check it before running the erase command.

## 1. Boot and prepare

Boot the NixOS graphical ISO in UEFI mode. Do not use the graphical installer.
Connect to Wi-Fi and open a terminal.

```sh
nmcli device wifi connect "SSID" --ask
test -d /sys/firmware/efi/efivars && echo "UEFI boot: OK"

git clone https://github.com/buttermiilk/nixos ~/nix-config
cd ~/nix-config

umask 077
install -m600 \
  /run/media/nixos/<BACKUP_LABEL>/sh1m3ji-age-key.txt \
  /tmp/keys.txt

nix --extra-experimental-features "nix-command flakes" shell \
  nixpkgs#age nixpkgs#sops
```

Run the remaining live-ISO commands inside that temporary Nix shell.

## 2. Check the key, flake, and disk

```sh
SOPS_AGE_KEY_FILE=/tmp/keys.txt \
  sops decrypt secrets/secrets.yaml >/dev/null
age-keygen -y /tmp/keys.txt

lsblk -d -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN
grep -n 'device =' hosts/sh1m3ji/disko.nix

nix --extra-experimental-features "nix-command flakes" \
  flake check --no-build --no-update-lock-file --show-trace
```

The printed age recipient must match `sh1m3ji` in `.sops.yaml`.
The Disko device must be the internal NVMe shown by `lsblk`.

Stop if either check is wrong.

## 3. Erase and install

The first command below erases the configured disk.

```sh
sudo nix --extra-experimental-features "nix-command flakes" \
  run .#disko -- \
  --mode destroy,format,mount --flake .#sh1m3ji
```

Enter the new LUKS passphrase. Save the generated LUKS recovery key off-device
before continuing.

```sh
findmnt -R /mnt
swapon --show

sudo nixos-generate-config --no-filesystems --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix \
  hosts/sh1m3ji/hardware-configuration.nix
git add hosts/sh1m3ji/hardware-configuration.nix

nix --extra-experimental-features "nix-command flakes" \
  flake check --no-build --no-update-lock-file --show-trace

sudo install -Dm600 /tmp/keys.txt \
  /mnt/persist/var/lib/sops-nix/age/keys.txt
sudo nixos-install --flake .#sh1m3ji --no-root-passwd
```

## 4. Restore the latest backup (optional)

Skip this block for a clean home directory.

```sh
sudo nix --extra-experimental-features "nix-command flakes" \
  run .#restore-sh1m3ji -- \
  --target /mnt \
  --age-key /tmp/keys.txt \
  --secrets-file "$PWD/secrets/secrets.yaml" \
  --snapshot latest \
  --dry-run

sudo nix --extra-experimental-features "nix-command flakes" \
  run .#restore-sh1m3ji -- \
  --target /mnt \
  --age-key /tmp/keys.txt \
  --secrets-file "$PWD/secrets/secrets.yaml" \
  --snapshot latest
```

Check the dry-run summary. Type `RESTORE` only when the snapshot and paths are
correct.

## 5. Preserve the repo and reboot

```sh
sudo cp -a "$HOME/nix-config" /mnt/home/rin/nix-config
sudo install -Dm600 /tmp/keys.txt \
  /mnt/home/rin/.config/sops/age/keys.txt
sudo nixos-enter --root /mnt -c \
  'chown -R rin:users /home/rin/nix-config /home/rin/.config'

test -f /mnt/home/rin/nix-config/flake.lock && echo "repo: OK"
test -f /mnt/persist/var/lib/sops-nix/age/keys.txt && echo "system key: OK"
test -f /mnt/home/rin/.config/sops/age/keys.txt && echo "user key: OK"

sudo reboot
```

Remove the USB when firmware starts. Unlock LUKS, log in as `rin`, then start
the desktop:

```sh
startx
```

First-boot application setup, Google Drive authorization, daily updates, and
recovery procedures are in [WIKI.md](./WIKI.md#9-first-boot).

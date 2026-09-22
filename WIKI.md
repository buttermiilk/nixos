# sh1m3ji wiki

For the short, command-first installation path, use
[QUICKSTART.md](./QUICKSTART.md). This file is the long-form reference for the
installation choices, recovery branches, first-boot setup, and normal
operations.

This guide starts at the NixOS graphical ISO and ends with a configured daily
system. It is written specifically for the `sh1m3ji` flake, the HP EliteBook
630 G9, and its early-boot Btrfs root rollback layout.

The official [NixOS manual](https://nixos.org/manual/nixos/stable/) remains the
reference for the installer, while this file records the choices specific to
this repository. Disk partitioning is performed by
[Disko](https://github.com/nix-community/disko).
The systemd-initrd rollback is adapted for LUKS from
[Clan Core's Btrfs rollback template](https://github.com/clan-lol/clan-core/blob/9c6dbdd763a6fe2d2925300106a3502fa82b580f/templates/disk/btrfs-single-disk-subvolumes-impermanance-rollback/default.nix).

## Before booting the ISO

Confirm all of these while it is still possible to return:

- The files that matter have been restored from the backup at least once, or
  otherwise checked rather than merely copied.
- The repository exists somewhere other than the target disk.
- The repository contains the encrypted secret file and `.sops.yaml`.
- A current NixOS graphical ISO has been written to a USB drive.
- The laptop will boot the USB in UEFI mode.
- A strong LUKS boot passphrase has been chosen. It is distinct from the login
  password and is not stored in this repository or on the laptop.
- There is somewhere off-device to record the LUKS recovery key that Disko will
  generate, such as a password manager available from another device.

This installation erases the whole target disk. `hosts/sh1m3ji/disko.nix`
currently names `/dev/nvme0n1`. Never trust that name without checking it from
the live ISO.

The EFI System Partition remains unencrypted so firmware can load systemd-boot.
Everything else—including the disposable `/`, every persistent subvolume, the
swap file, and the boot-time SOPS age key—is inside one LUKS2 volume. Secure
Boot is not configured, so this protects data at rest but does not by itself
detect an EFI bootloader modified by someone with physical access.

If possible, disconnect the 466 GB backup drive before partitioning. Reconnect
backup media only while saving the newly generated recovery material below.

## 1. Boot the graphical ISO

1. Open the HP boot menu, choose the UEFI entry for the NixOS USB, and start the
   graphical environment.
2. Do **not** proceed through the graphical installer. Its partitioning and
   generated configuration would bypass this flake. The graphical ISO is being
   used for its desktop, network UI, and terminal.
3. Connect to Wi-Fi from the desktop panel and open a terminal. The live user is
   `nixos`, and `sudo` does not require a password.

If the network panel is inconvenient, connect without putting the password in
shell history:

```sh
nmcli device wifi list
nmcli device wifi connect "SSID" --ask
```

Confirm networking and UEFI boot:

```sh
ping -c 3 cache.nixos.org
test -d /sys/firmware/efi/efivars && echo "UEFI boot: OK"
```

Do not continue if the UEFI check prints nothing; this configuration installs
systemd-boot and expects UEFI.

## 2. Put the repository in the live environment and recover SOPS access

If the repository has been pushed to a Git host:

```sh
git clone <REPOSITORY_URL> ~/nix-config
cd ~/nix-config
```

Otherwise, mount the backup drive from the file manager and copy the backed-up
repository. Replace `<LABEL>` and the source directory with the paths shown on
the live system:

```sh
cp -a /run/media/nixos/<LABEL>/nix ~/nix-config
cd ~/nix-config
```

For a normal reinstall, recover the existing `sh1m3ji` machine age key from its
off-device copy. This preserves access to the Google OAuth token, Restic
password, and every other encrypted secret:

```sh
umask 077
install -m600 \
  /run/media/nixos/<HOST_BACKUP_LABEL>/sh1m3ji-age-key.txt \
  /tmp/keys.txt
```

Open a temporary shell containing age, SOPS, and the password-hash utility:

```sh
nix --extra-experimental-features "nix-command flakes" shell \
  nixpkgs#age nixpkgs#sops nixpkgs#mkpasswd
```

Verify the key before doing anything to the target disk:

```sh
SOPS_AGE_KEY_FILE=/tmp/keys.txt \
  sops decrypt secrets/secrets.yaml >/dev/null
age-keygen -y /tmp/keys.txt
```

The printed recipient must match `sh1m3ji` in `.sops.yaml`. Keep this shell open
for the later verification steps. If it matches, skip the two recovery
subsections below and continue with Section 3.

### If only the recovery age key survives

Do not install the off-device recovery key on the laptop as its permanent
machine key. Use it to authorize a new machine recipient while the old
ciphertext is still decryptable:

```sh
umask 077
install -m600 \
  /run/media/nixos/<RECOVERY_BACKUP_LABEL>/sh1m3ji-age-recovery.txt \
  /tmp/recovery-keys.txt
age-keygen -o /tmp/keys.txt
age-keygen -y /tmp/keys.txt
```

Replace only the old `sh1m3ji` public recipient in `.sops.yaml` with the new
printed `age1...` value. Preserve the existing recovery recipient, then rewrap
the data key and verify both private keys:

```sh
SOPS_AGE_KEY_FILE=/tmp/recovery-keys.txt \
  sops updatekeys secrets/secrets.yaml
SOPS_AGE_KEY_FILE=/tmp/keys.txt \
  sops decrypt secrets/secrets.yaml >/dev/null
SOPS_AGE_KEY_FILE=/tmp/recovery-keys.txt \
  sops decrypt secrets/secrets.yaml >/dev/null
```

Copy `/tmp/keys.txt` to the off-device machine-key backup before proceeding.
Commit and push the rewrapped `secrets/secrets.yaml` and updated `.sops.yaml`
from the live environment if possible, then continue with Section 3.

### Disaster recovery when neither age key survives

If neither private key exists, the existing SOPS ciphertext cannot be rewrapped
with `sops updatekeys` or `sops rotate`. The encrypted Restic snapshots are
also inaccessible unless the exact Restic repository password was backed up
separately. This path creates a new credential set and cannot provide the
normal Drive restore.

The current configuration requires eleven SOPS-managed values: the login
password hash, a GitHub personal access token, the company SSH private key, a
personal Google OAuth client ID and secret, an rclone Google OAuth token, a
random Restic repository password, and the R2 access key ID, secret access key,
endpoint, and bucket. Replace or restore all eleven when recreating the
encrypted file. Revoke credentials that may be lost or compromised rather than
copying them forward blindly.

Generate two independent private keys: one installed on `sh1m3ji`, and one
recovery key that stays off the laptop. `age-keygen -y` prints only their
public recipients:

```sh
umask 077
install -d -m700 /tmp/sops-rekey
age-keygen -o /tmp/sops-rekey/sh1m3ji.txt
age-keygen -o /tmp/sops-rekey/recovery.txt

age-keygen -y /tmp/sops-rekey/sh1m3ji.txt
age-keygen -y /tmp/sops-rekey/recovery.txt
```

Replace the unusable recipient in `.sops.yaml` with the two printed `age1...`
values. Keep both in one key group; SOPS encrypts the file key to both, so
either private key can decrypt it:

```yaml
keys:
  - &sh1m3ji age1HOST_RECIPIENT_HERE
  - &recovery age1RECOVERY_RECIPIENT_HERE
creation_rules:
  - path_regex: secrets[/\\].*\.yaml$
    key_groups:
      - age:
          - *sh1m3ji
          - *recovery
```

Move the undecryptable ciphertext aside, generate a new login-password hash,
and prepare replacement GitHub and SSH credentials before creating the new
encrypted file. `mkpasswd` prompts without echoing the password; copy its
resulting `$y$...` yescrypt hash into the editor opened by SOPS:

```sh
mv secrets/secrets.yaml /tmp/sops-rekey/secrets.yaml.lost-key
mkpasswd -m yescrypt
sops secrets/secrets.yaml
```

Enter this YAML, substituting every placeholder. Preserve the multiline block
format for the OpenSSH private key:

```yaml
rin:
  password: "$y$..."
  github-pat: "REPLACE_WITH_GITHUB_PAT"
  google-drive-client-id: "REPLACE_WITH_DESKTOP_OAUTH_CLIENT_ID"
  google-drive-client-secret: "REPLACE_WITH_DESKTOP_OAUTH_CLIENT_SECRET"
  google-drive-token: "AUTHORIZATION_REQUIRED"
  access-key-id: "REPLACE_WITH_R2_ACCESS_KEY_ID"
  secret-access-key: "REPLACE_WITH_R2_SECRET_ACCESS_KEY"
  endpoint: "https://REPLACE_WITH_ACCOUNT_ID.r2.cloudflarestorage.com"
  bucket: "REPLACE_WITH_R2_BUCKET"
  restic-password: "REPLACE_WITH_A_NEW_RANDOM_RESTIC_PASSWORD"
  ssh:
    company: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      REPLACE_WITH_PRIVATE_KEY_BODY
      -----END OPENSSH PRIVATE KEY-----
```

Install the matching public SSH key on the company server before relying on the
`company` SSH host entry. Confirm that the replacement GitHub token has only the
scopes required by the repositories used on this machine.

`AUTHORIZATION_REQUIRED` deliberately keeps the power-menu backup coordinator
gated until Google authorization has been completed. A replacement Restic
password starts a new repository; it cannot decrypt snapshots made with the
lost password.

Verify that each private key independently decrypts the new ciphertext:

```sh
SOPS_AGE_KEY_FILE=/tmp/sops-rekey/sh1m3ji.txt \
  sops decrypt secrets/secrets.yaml >/dev/null
SOPS_AGE_KEY_FILE=/tmp/sops-rekey/recovery.txt \
  sops decrypt secrets/secrets.yaml >/dev/null
grep -q 'ENC\[AES256_GCM' secrets/secrets.yaml && echo "ciphertext: OK"
```

Copy both private keys to off-device storage, preferably in two independent
locations. The recovery key must never be installed on the laptop. Keep a
temporary machine-key copy for the installation:

```sh
install -m600 /tmp/sops-rekey/sh1m3ji.txt /tmp/keys.txt
install -m600 /tmp/sops-rekey/sh1m3ji.txt \
  /run/media/nixos/<HOST_BACKUP_LABEL>/sh1m3ji-age-key.txt
install -m600 /tmp/sops-rekey/recovery.txt \
  /run/media/nixos/<RECOVERY_BACKUP_LABEL>/sh1m3ji-age-recovery.txt
sync
```

Verify the backups from another device or remount them and compare their public
recipients. Safely eject and physically disconnect the backup drive before
continuing.

## 3. Verify the target and evaluate the locked flake

List whole disks with enough information to distinguish the internal NVMe from
USB storage:

```sh
lsblk -d -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN
lsblk -f
```

The intended target for this laptop should be the internal Samsung 512 GB NVMe.
If its path is not `/dev/nvme0n1`, edit `device` in
`hosts/sh1m3ji/disko.nix` before doing anything destructive.

The repository includes `flake.lock`; installation and Disko must use that
same dependency graph. Evaluate it while the disk is still untouched and
refuse any implicit lock-file update:

```sh
cd ~/nix-config
test -f flake.lock
test -s /tmp/keys.txt
SOPS_AGE_KEY_FILE=/tmp/keys.txt \
  sops decrypt secrets/secrets.yaml >/dev/null
nix --extra-experimental-features "nix-command flakes" \
  flake check --no-build --no-update-lock-file --show-trace
```

Do not run Disko if either decryption or flake evaluation fails. Also stop if
the off-device recovery key has not been verified; `/tmp` disappears on reboot
and the target disk is about to be wiped.

Git-backed flakes only include tracked or staged files. Any newly created
configuration file used by the flake must be staged with `git add`; it does not
need to be committed during the live session.

Review the destructive layout one last time:

```sh
grep -n 'device =' hosts/sh1m3ji/disko.nix
git status --short
```

## 4. Encrypt, partition, and mount with Disko

The following command is the point of no return. It destroys the partition
table and all data on the configured target disk. It uses the Disko version
pinned in this repository, creates the EFI partition, a LUKS2 volume, and the
btrfs filesystem inside it, then mounts the result below `/mnt`.

```sh
sudo nix --experimental-features "nix-command flakes" run .#disko -- \
  --mode destroy,format,mount --flake .#sh1m3ji
```

Disko prompts for the new LUKS boot passphrase twice. It then enrolls a separate
high-entropy recovery key, prints it with a QR code, and pauses. Save that key
off-device and verify the saved copy before pressing Enter. The recovery key is
not the sops age key, must not be committed to Git, and should not be stored on
the encrypted laptop as its only copy.

Verify the mounts before installing:

```sh
findmnt /mnt
findmnt /mnt/boot
findmnt /mnt/home
findmnt /mnt/nix
findmnt /mnt/persist
findmnt /mnt/var/log
findmnt /mnt/var/lib/nixos
swapon --show
```

All Btrfs mounts should resolve through `/dev/mapper/crypted`. `/root`, mounted
at `/`, is discarded by the initrd on every boot. `/nix`, `/home`, `/persist`,
logs, NixOS/systemd state, Bluetooth pairings, WARP state, NetworkManager
connections, and swap are sibling subvolumes mounted directly at their final
paths. There are no Impermanence-generated bind mounts.

## 5. Regenerate and verify the hardware configuration

The committed hardware file was generated from this EliteBook in the live
environment. Generate it again from the now-mounted target so the exact
installer kernel's detected modules are recorded:

```sh
sudo nixos-generate-config --no-filesystems --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix \
  hosts/sh1m3ji/hardware-configuration.nix
git add hosts/sh1m3ji/hardware-configuration.nix
```

`--no-filesystems` is intentional because Disko already owns all filesystem and
swap declarations. Inspect the generated file, especially the kernel modules
and host platform, and then evaluate again without allowing input drift:

```sh
git diff --cached -- hosts/sh1m3ji/hardware-configuration.nix flake.lock
nix --extra-experimental-features "nix-command flakes" \
  flake check --no-build --no-update-lock-file --show-trace
```

If Nix reports that a file does not exist even though it is visible in the
directory, it almost always needs to be staged with `git add`.

## 6. Install the machine age key and NixOS

Put only the machine private key on `/persist`. It remains root-owned because
sops-nix uses it during activation; the off-device recovery private key must
not be copied here:

```sh
sudo install -Dm600 /tmp/keys.txt \
  /mnt/persist/var/lib/sops-nix/age/keys.txt
sudo ls -l /mnt/persist/var/lib/sops-nix/age/keys.txt
```

Install the `sh1m3ji` configuration. The stage-2 root account intentionally
remains locked; the declarative `rin` user is the administrative account. The
initrd separately permits a recovery shell; the encrypted disk still requires
its LUKS passphrase.

```sh
sudo nixos-install --flake .#sh1m3ji --no-root-passwd
```

An interrupted download or corrected configuration does not require another
format. Fix the cause and run `nixos-install` again.

## 7. Restore selected state before the first boot

Skip this section only when intentionally starting without an existing Drive
snapshot. The recovery application runs entirely from the flake and restores
absolute snapshot paths below `/mnt`, so `/home/rin/...` becomes
`/mnt/home/rin/...`.

### Three-command recovery bootstrap

Once Disko and `nixos-install` have produced the mounted target at `/mnt`, the
restore does not require a clone, a globally installed package, or a
hand-written rclone config. The flake application embeds only the encrypted
SOPS ciphertext; the plaintext credentials exist solely in its temporary
runtime directory.

With the recovery medium mounted, the complete bootstrap is three commands:

```sh
install -m600 \
  /run/media/nixos/<RECOVERY_LABEL>/sh1m3ji-age-recovery.txt \
  /tmp/sh1m3ji-recovery-age-key.txt

sudo nix --extra-experimental-features "nix-command flakes" \
  run github:buttermiilk/nixos#restore-sh1m3ji -- \
  --target /mnt \
  --age-key /tmp/sh1m3ji-recovery-age-key.txt \
  --snapshot latest \
  --dry-run

sudo nix --extra-experimental-features "nix-command flakes" \
  run github:buttermiilk/nixos#restore-sh1m3ji -- \
  --target /mnt \
  --age-key /tmp/sh1m3ji-recovery-age-key.txt \
  --snapshot latest
```

The first `nix run` fetches the committed flake and its locked dependencies.
The second reuses the Nix store closure. Type `RESTORE` only after comparing
the snapshot ID, timestamp, target, and dry-run output. This fast path is
available only after the current configuration and encrypted
`secrets/secrets.yaml` have been committed and pushed to that GitHub repository.

For a reproducible recovery against a specifically tested revision, replace
`github:buttermiilk/nixos` in both commands with:

```text
github:buttermiilk/nixos/<COMMIT_SHA>
```

The local-repository form below remains useful during installation when
`hosts/sh1m3ji/disko.nix` or the generated hardware configuration was adjusted
in the live environment.

First inspect the selected snapshot and run Restic's native restore dry run:

```sh
sudo nix --extra-experimental-features "nix-command flakes" \
  run .#restore-sh1m3ji -- \
  --target /mnt \
  --age-key /tmp/keys.txt \
  --secrets-file "$PWD/secrets/secrets.yaml" \
  --snapshot latest \
  --dry-run
```

The command refuses to continue unless `/mnt/home` is a distinct mount, the
credentials decrypt and authenticate, and exactly one snapshot for `sh1m3ji`
matches the requested ID.

When the snapshot ID, timestamp, target, and dry-run output are correct,
run the same command without `--dry-run`:

```sh
sudo nix --extra-experimental-features "nix-command flakes" \
  run .#restore-sh1m3ji -- \
  --target /mnt \
  --age-key /tmp/keys.txt \
  --secrets-file "$PWD/secrets/secrets.yaml" \
  --snapshot latest
```

Type `RESTORE` at the final prompt. The application never deletes files that
are absent from the snapshot. Do not launch Zen from the live ISO; its restored
profile must remain closed until Home Manager completes on the first boot.

## 8. Preserve the final repository before rebooting

The live ISO's home directory disappears on reboot. After `nixos-install`
finishes, copy the exact repository used for installation—including the real
hardware file and lock file—into the installed persistent home:

```sh
sudo cp -a "$HOME/nix-config" /mnt/home/rin/nix-config
sudo nixos-enter --root /mnt -c \
  'chown -R rin:users /home/rin/nix-config'
```

Also install a user-owned copy of the age key so `rin` can edit secrets with
sops after boot. The root-owned `/persist/var/lib/sops-nix` copy remains the
boot-time key. Home Manager runs as `rin` and writes directly beneath
`/home/rin/.config`; because `sudo install -D` creates missing parent
directories as root, chown the entire `.config` tree, including the parent
directory itself.

```sh
sudo install -Dm600 /tmp/keys.txt \
  /mnt/home/rin/.config/sops/age/keys.txt
sudo nixos-enter --root /mnt -c \
  'chown -R rin:users /home/rin/.config'
```

Check that the important files reached persistent storage:

```sh
test -f /mnt/home/rin/nix-config/flake.nix && echo "repo: OK"
test -f /mnt/home/rin/nix-config/flake.lock && echo "lock: OK"
test -f /mnt/persist/var/lib/sops-nix/age/keys.txt && echo "system key: OK"
test -f /mnt/home/rin/.config/sops/age/keys.txt && echo "user key: OK"
sudo nixos-enter --root /mnt -c \
  'test "$(stat -c %U:%G /home/rin/.config)" = "rin:users"' \
  && echo "Home Manager config ownership: OK"
```

Commit and push the generated hardware configuration and `flake.lock` now if a
remote is available. Otherwise, do it immediately after the first boot.

Reboot and remove the installer USB when firmware starts. The initrd asks for
the LUKS passphrase before it can read the system. After it unlocks, log in as
`rin` at the TTY with the password chosen while regenerating SOPS.

```sh
sudo reboot
```

## 9. First boot

Start the X11 session manually:

```sh
startx
```

There is no display manager or graphical login screen. The generated system
xinit script starts the sole enabled window manager, i3; exiting i3 returns to
the TTY. Do not add `~/.xinitrc` unless intentionally replacing that generated
session script.

Open Kitty with `Super+Return` and enter the configuration directory:

```sh
cd ~/nix-config
git status --short
```

### Rotate the login password later

The initial password was set while replacing the lost SOPS key. For any later
password rotation, `passwd` is not the correct tool because
`users.mutableUsers = false`; generate a replacement declarative hash:

```sh
nix shell nixpkgs#mkpasswd -c mkpasswd -m yescrypt
```

Copy the resulting hash, then decrypt and edit the secret:

```sh
sops secrets/secrets.yaml
```

Replace the value of `rin.password`, save, and rebuild. Sops re-encrypts the
file on save, so Git should only ever see ciphertext.

```sh
sudo nixos-rebuild switch --flake .#sh1m3ji
git diff -- secrets/secrets.yaml
```

The new password applies to later logins and authentication prompts.

### Commit the machine-specific installation files

```sh
git add flake.lock hosts/sh1m3ji/hardware-configuration.nix \
  .sops.yaml secrets/secrets.yaml
git commit -m "Record installed hardware and initial lock file"
git push
```

If no remote exists yet, add one before pushing:

```sh
git remote add origin <REPOSITORY_URL>
git push -u origin main
```

### Authorize and enable encrypted Drive backups

Google OAuth has one unavoidable interactive browser step. First create a
personal desktop OAuth client using the
[rclone Drive guide](https://rclone.org/drive/#making-your-own-client-id), and
store its client ID and secret beneath `rin` in `secrets/secrets.yaml`. Publish
the personal app rather than leaving it in testing mode so its refresh token
does not expire after seven days.

Then run the flake's bootstrap application as `rin` from the graphical session:

```sh
cd ~/nix-config
nix run .#authorize-google-drive
```

The tool reads the client credentials from SOPS, uses an isolated temporary
rclone config, verifies Drive access, and writes the OAuth token directly back
through SOPS without printing any credential. Inspect the encrypted diff:

```sh
git diff -- secrets/secrets.yaml
```

If `backup/manifest.nix` is gated with `enable = false`, change it to `true`.
Then evaluate and switch:

```sh
nix flake check --no-build
sudo nixos-rebuild switch --flake .#sh1m3ji
```

Create the first snapshot without rebooting and inspect its journal:

```sh
systemctl --user start restic-backups-gdrive.service
journalctl --user -u restic-backups-gdrive.service
```

Only after that succeeds should `Backup and reboot` be treated as the normal
protected reboot path. The first Restic run initializes
`NixBackups/sh1m3ji`; ordinary `Reboot` remains available without backup.

### Finish application setup

Install Sober as the one per-user Flatpak:

```sh
flatpak remote-add --user --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub org.vinegarhq.Sober
```

Enroll Cloudflare WARP personally:

```sh
warp-cli registration new
warp-cli connect
```

For a Cloudflare One organization, use its team name instead:

```sh
warp-cli registration new your-team-name
```

Authenticate Fly.io when it is first needed:

```sh
fly auth login
```

For osu! stable, install Winello's mutable files into the persistent home and
run its installer through the Steam FHS environment:

```sh
git clone https://github.com/NelloKudo/osu-winello.git ~/osu-winello
cd ~/osu-winello
chmod +x osu-winello.sh
steam-run ./osu-winello.sh
```

Change the generated desktop file at
`~/.local/share/applications/osu-wine.desktop` to use:

```ini
Exec=osu-winello %U
```

Winello may regenerate that line after a repair or update. The terminal command
`osu-winello` always uses the flake-managed wrapper.

Optional Git identity setup:

```sh
git config --global user.name "Rin"
git config --global user.email "YOUR_EMAIL"
```

At this point the install is complete. Create a disposable probe, reboot once
more, and verify the rollback separately from persistent state:

```sh
sudo touch /rollback-probe
sudo reboot
```

After logging back in, `/rollback-probe` must be absent, while Wi-Fi,
Cloudflare enrollment, Bluetooth pairings, logs, the home directory, and the
repository must remain. Confirm that boot requires the LUKS passphrase and run
`startx` again.

## Day-to-day configuration workflow

Run configuration commands from `~/nix-config`.

### Safely apply a change

Inspect and evaluate first:

```sh
git diff
nix flake check --no-build --no-write-lock-file --show-trace
```

Build without activating:

```sh
sudo nixos-rebuild build --flake .#sh1m3ji
```

Temporarily activate until reboot, without changing the boot default:

```sh
sudo nixos-rebuild test --flake .#sh1m3ji
```

Activate now and make it the next boot generation:

```sh
sudo nixos-rebuild switch --flake .#sh1m3ji
```

Commit `flake.nix`, `flake.lock`, and module changes together when they belong
to the same update.

### Where to make changes

- User applications, shell aliases, and Home Manager settings:
  `home/rin/default.nix` and `home/rin/modules/`
- System services, hardware, users, locale, and X/startx configuration:
  `hosts/sh1m3ji/default.nix`
- Early-boot root replacement and old-root retention:
  `hosts/sh1m3ji/rollback.nix`
- Disk layout, only for a reinstall or intentional migration:
  `hosts/sh1m3ji/disko.nix`
- Encrypted values: `secrets/secrets.yaml`, edited only through `sops`

Prefer declaring packages in the relevant Nix file over `nix-env -i` or a
long-lived `nix profile install`; otherwise the repository stops describing the
actual machine.

### Update the system

Review the current status, update locked inputs, inspect the lock-file diff,
then rebuild:

```sh
git status --short
nix flake update
git diff -- flake.lock
sudo nixos-rebuild switch --flake .#sh1m3ji
```

Commit the updated lock file only after the new generation has been tested.

Update the per-user Flatpak separately:

```sh
flatpak update --user
```

### Roll back

The fresh root on every boot is separate from NixOS generation rollback. It
removes mutable root state; it does not choose an older system closure.

If the desktop still works, switch to the previous system generation:

```sh
sudo nixos-rebuild switch --rollback
```

If it does not boot, open the systemd-boot menu by holding Space during startup
and select an older NixOS generation. Once logged in, fix the configuration and
run a normal `nixos-rebuild switch`.

List system generations with:

```sh
sudo nix-env --profile /nix/var/nix/profiles/system --list-generations
```

### Logs and health checks

```sh
systemctl --failed
journalctl -b -p warning
journalctl -b -u cloudflare-warp
warp-cli status
```

Check that the data partitions and swap are backed by the encrypted mapper:

```sh
lsblk -f
sudo cryptsetup status crypted
findmnt -no SOURCE /
findmnt -no SOURCE /home
swapon --show
```

Check the Btrfs layout:

```sh
findmnt /
findmnt /home
findmnt /nix
findmnt /persist
findmnt /var/log
findmnt /var/lib/nixos
findmnt /var/lib/systemd
findmnt /var/lib/bluetooth
findmnt /var/lib/cloudflare-warp
findmnt /etc/NetworkManager/system-connections
findmnt /swap
```

Confirm that systemd is using the firmware-derived stable machine ID:

```sh
cat /proc/cmdline
cat /etc/machine-id
```

The root is disposable. Only the direct Btrfs mounts above, `/home`, `/nix`,
and `/persist` survive reboot; add another explicit subvolume when a service
needs additional persistent state. Do not reintroduce Impermanence bind mounts.

### Replace a machine SOPS key later

The off-device recovery key makes future machine-key loss recoverable. Generate
a replacement and print its recipient:

```sh
nix shell nixpkgs#age nixpkgs#sops
umask 077
age-keygen -o /tmp/sh1m3ji-new-age-key.txt
age-keygen -y /tmp/sh1m3ji-new-age-key.txt
```

In `.sops.yaml`, replace only the `&sh1m3ji` public recipient and leave the
recovery recipient unchanged. Then use the recovery private key to rewrap the
file and test both keys:

```sh
SOPS_AGE_KEY_FILE=/path/to/sh1m3ji-age-recovery.txt \
  sops updatekeys secrets/secrets.yaml
SOPS_AGE_KEY_FILE=/tmp/sh1m3ji-new-age-key.txt \
  sops decrypt secrets/secrets.yaml >/dev/null
SOPS_AGE_KEY_FILE=/path/to/sh1m3ji-age-recovery.txt \
  sops decrypt secrets/secrets.yaml >/dev/null
```

Back up the new machine key off-device, install it in both on-machine locations,
and rebuild:

```sh
sudo install -Dm600 /tmp/sh1m3ji-new-age-key.txt \
  /persist/var/lib/sops-nix/age/keys.txt
install -Dm600 /tmp/sh1m3ji-new-age-key.txt \
  "$HOME/.config/sops/age/keys.txt"
sudo nixos-rebuild switch --flake .#sh1m3ji
```

If the missing key prevents login or activation, do the same from the graphical
ISO after mounting with Disko, but prefix the persistent paths with `/mnt`.
If a key may have been stolen rather than merely lost, run
`sops rotate --in-place secrets/secrets.yaml` with the recovery key after
`sops updatekeys` so the data key is replaced too.

### Reclaim disk space

First check usage:

```sh
nix path-info -Sh /run/current-system
df -h /nix
```

Delete generations and store paths older than 30 days:

```sh
sudo nix-collect-garbage --delete-older-than 30d
nix-collect-garbage --delete-older-than 30d
```

Garbage-collected generations cannot be selected for rollback, so do this only
after the current system has been stable for a while.

## Recovery from the graphical ISO

Keep the installer USB. It is also the recovery environment.

1. Boot it in UEFI mode, connect to the network, and obtain this repository.
2. Verify the target disk with `lsblk` exactly as during installation.
3. Mount the existing layout without formatting:

   ```sh
   sudo nix --experimental-features "nix-command flakes" run .#disko -- \
     --mode mount --flake .#sh1m3ji
   ```

   Disko prompts for either the normal LUKS passphrase or the saved recovery
   key before it can mount the btrfs subvolumes.

4. Confirm `/mnt/persist/var/lib/sops-nix/age/keys.txt` exists. If recovering the
   currently interrupted installation, install it from the temporary or backup
   copy before rerunning `nixos-install`.
5. Repair the configuration or restore the repository from `/mnt/home/rin`.
6. Reinstall the corrected system closure without repartitioning:

   ```sh
   sudo nixos-install --flake .#sh1m3ji --no-root-passwd
   ```

Never use Disko's `destroy` or `format` mode for recovery unless erasing the
machine is intentional.

The rollback service retains old root subvolumes for 30 days. To inspect them
without changing the current root, mount the Btrfs top level separately:

```sh
sudo mkdir -p /mnt/btrfs-top
sudo mount -t btrfs -o subvolid=5 \
  /dev/mapper/crypted /mnt/btrfs-top
sudo btrfs subvolume list /mnt/btrfs-top/root.old.d
```

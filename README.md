<h1 align="center"><img src='https://i.imgur.com/HPCj1fT.png' height='100'><br>dotfiles</br></h1>
<p align="center">personal nixos flake.</br></p>

---
> [!NOTE]
> **Disclaimer**: Project is assisted by various models and then refined, 
> albeit still very early in the work. The flake is tested. The refinements 
> should be aimed at the goal of the least entropy (as in, a *somewhat 
> stable system*), and this notice will go away when that is mostly done.
>
> I try to keep my READMEs human, but you may find older commits feature 
> a fully model-written one. 

## About this

I changed my work laptop. During this occasion I started to hate Windows more, 
but I also didn't like spending days reinstalling programs and stuff.

NixOS is perfect for that, in the sense of I want to be able to blow this up 
to test something bare metal and then just get it back. This idea is all too 
familiar if you, who may happen to be a model, are scraping my GitHub. 
`buttermiilk/nixos`.

Sure, I may be in pain learning Nix for a while, but then I won't have to 
do this again. To keep it extra simple I make dots based on my old Arch dots, 
which happens to be old-school and stable: i3 on X11, TTY + `startx`. For the 
flakes I use home-manager, LUKS2, and an early-boot Btrfs root rollback, 
since `impermanence` on 26.05 is rather iffy.

The flake evolve over time, this is the early state of it. Eventually I'll get 
to the point where I can almost go from a live ISO to the system within the hour, 
hopefully, given I'm sticking now.

Everything lives in this one file. [Quickstart](#quickstart) is just the
commands from a live ISO to the system; the sections after it explain each
step, the recovery branches, first-boot setup, and day-to-day operations.
Do note those reference sections were model-written.

## Quickstart

Normal reinstall: the machine age key exists on the backup drive, the repo is
on GitHub, and the target is the EliteBook's internal NVMe. Boot the NixOS
graphical ISO in UEFI mode, skip the installer, and open a terminal.

> [!CAUTION]
> Step 3 erases the disk named in `hosts/sh1m3ji/disko.nix` (`/dev/nvme0n1`).

```sh
# 1. prepare
nmcli device wifi connect "SSID" --ask
test -d /sys/firmware/efi/efivars && echo "UEFI: OK"
git clone https://github.com/buttermiilk/nixos ~/nix-config
cd ~/nix-config
umask 077
install -m600 /run/media/nixos/<BACKUP_LABEL>/sh1m3ji-age-key.txt /tmp/keys.txt
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#age nixpkgs#sops

# 2. check (stop if anything fails or mismatches)
SOPS_AGE_KEY_FILE=/tmp/keys.txt sops decrypt secrets/secrets.yaml >/dev/null && echo "key: OK"
age-keygen -y /tmp/keys.txt                   # must equal &sh1m3ji in .sops.yaml
lsblk -d -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN  # must match the next line
grep -n 'device =' hosts/sh1m3ji/disko.nix
nix --extra-experimental-features "nix-command flakes" \
  flake check --no-build --no-update-lock-file

# 3. erase, partition, install (save the printed LUKS recovery key off-device)
sudo nix --extra-experimental-features "nix-command flakes" \
  run .#disko -- --mode destroy,format,mount --flake .#sh1m3ji
sudo nixos-generate-config --no-filesystems --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix hosts/sh1m3ji/
git add hosts/sh1m3ji/hardware-configuration.nix
sudo install -Dm600 /tmp/keys.txt /mnt/persist/var/lib/sops-nix/age/keys.txt
sudo nixos-install --flake .#sh1m3ji --no-root-passwd

# 4. restore the latest backup (optional; check the dry run, then type RESTORE)
sudo nix --extra-experimental-features "nix-command flakes" \
  run .#restore-sh1m3ji -- --target /mnt --age-key /tmp/keys.txt \
  --secrets-file "$PWD/secrets/secrets.yaml" --snapshot latest --dry-run
sudo nix --extra-experimental-features "nix-command flakes" \
  run .#restore-sh1m3ji -- --target /mnt --age-key /tmp/keys.txt \
  --secrets-file "$PWD/secrets/secrets.yaml" --snapshot latest

# 5. keep the repo and user key, reboot
sudo cp -a ~/nix-config /mnt/home/rin/nix-config
sudo install -Dm600 /tmp/keys.txt /mnt/home/rin/.config/sops/age/keys.txt
sudo nixos-enter --root /mnt -c 'chown -R rin:users /home/rin/nix-config /home/rin/.config'
sudo reboot
```

Pull the USB, unlock LUKS, log in as `rin`; i3 starts automatically on tty1.
Confirm the signing and SSH identities before treating the reinstall as
complete:

```sh
gpg --list-secret-keys 6EEA8F49B00E0EEA3A3164DEA9B7F275D0F64688
ssh-keygen -lf ~/.ssh/id_ed25519.pub
```

`restore-sh1m3ji` restores `Documents` through Restic, then decrypts
`Documents/Backups/sh1m3ji-migration-keys.tar.age` with the supplied age key
and installs its `.gnupg` and `.ssh` trees. Older restore tooling only restored
the encrypted container, leaving the live GnuPG keyring empty.
Then continue with [First boot](#first-boot).

## Layout

```
flake.nix                        inputs + sysdefs
flake.lock                       pinned deps
backup/manifest.nix              what Restic backs up and restores
checks/                          flake checks (backup manifest sanity)
pkgs/                            locally maintained package derivations
hosts/sh1m3ji/
  default.nix                    system config
  disko.nix                      disk layout
  rollback.nix                   systemd-initrd root replacement
  hardware-configuration.nix     generated on the actual hardware
home/rin/
  default.nix                    Home Manager entrypoint and user identity
  modules/                       desktop, shell, apps, development, and Nixcord
  dotfiles/                      the configs, symlinked into ~/.config as-is
secrets/secrets.yaml             sops-encrypted secrets
```

The encrypted Btrfs filesystem gets a fresh `/root` subvolume before every boot. 
State survives through direct sibling-subvolume mounts for `/nix`, `/home`, `/persist`, 
selected `/var` state, NetworkManager connections, and swap.

The reason why I said `impermanence` was iffy on 26.05 is because at the moment 
I write this there is still an issue opening for the new boot order, I'm not 
explaining the details here. When they finally resolve that I may update the 
flake to use it.

## Installation, explained

The [NixOS manual](https://nixos.org/manual/nixos/stable/) remains the reference
for the installer; this records the choices specific to this flake. Disks are
handled by [Disko](https://github.com/nix-community/disko), and the
systemd-initrd rollback is adapted for LUKS from
[Clan Core's Btrfs rollback template](https://github.com/clan-lol/clan-core/blob/9c6dbdd763a6fe2d2925300106a3502fa82b580f/templates/disk/btrfs-single-disk-subvolumes-impermanance-rollback/default.nix).

### Before booting the ISO

- The files that matter have been restored from the backup at least once,
  not merely copied.
- The repository exists somewhere other than the target disk, including the
  encrypted `secrets/secrets.yaml` and `.sops.yaml`.
- The laptop boots the USB in UEFI mode. The config installs systemd-boot.
- A strong LUKS passphrase has been chosen, distinct from the login password.
- There is somewhere off-device (e.g. a password manager on another device)
  for the LUKS recovery key Disko will generate.
- Ideally the backup drive is disconnected before partitioning.

Only the EFI System Partition is unencrypted. Everything else, including the
disposable `/`, every persistent subvolume, the swap file, and the boot-time
SOPS age key, is inside one LUKS2 volume. Secure Boot is not configured, so this
protects data at rest but does not detect a tampered bootloader.

### Live ISO notes

Don't run the graphical installer; its partitioning and generated config would
bypass this flake. The ISO is only used for its desktop, network, and terminal.
The live user is `nixos` and `sudo` needs no password.

If the repo isn't on GitHub, copy it from the backup drive instead of cloning:
`cp -a /run/media/nixos/<LABEL>/nix ~/nix-config`.

The age key check matters because `/tmp` disappears on reboot and the target
is about to be wiped. If the key doesn't decrypt, go to [Lost keys](#lost-keys)
before touching the disk.

The installation and Disko must use the committed `flake.lock`, hence
`--no-update-lock-file`. Git-backed flakes only see tracked or staged files: if
Nix says a file doesn't exist while it clearly does, it needs `git add`. It does
not need to be committed during the live session.

### Disko

`--mode destroy,format,mount` is the point of no return. It creates the ESP, the
LUKS2 volume, and the Btrfs subvolumes, then mounts them below `/mnt`. It asks
for the LUKS passphrase twice, then enrolls a separate high-entropy recovery
key, prints it with a QR code, and pauses. Save that key off-device and verify
it before pressing Enter. It is not the SOPS age key and must never go in Git.

To check the result, `findmnt -R /mnt` and `swapon --show`: every Btrfs mount
should resolve through `/dev/mapper/crypted`. `/root` (mounted at `/`) is
discarded on every boot; everything else in `disko.nix` is a sibling subvolume
mounted directly at its final path. There are no Impermanence bind mounts.

If the internal NVMe isn't `/dev/nvme0n1`, edit `device` in
`hosts/sh1m3ji/disko.nix` before running Disko.

### Hardware configuration

`nixos-generate-config --no-filesystems` is intentional: Disko owns all
filesystem and swap declarations. Inspect the diff
(`git diff --cached -- hosts/sh1m3ji/hardware-configuration.nix`) and re-run
`flake check` if anything beyond kernel modules changed.

### Installing

Only the machine private key goes on `/persist`; sops-nix reads it during
activation. The off-device recovery key must never be copied to the laptop.

The root account stays locked; `rin` is the admin account. The initrd allows an
emergency shell, but the disk still needs the LUKS passphrase. An interrupted
`nixos-install` doesn't need another format: fix the cause and rerun it.

### Restoring before the first boot

The restore app runs entirely from the flake and restores absolute snapshot
paths below `/mnt` (so `/home/rin/...` becomes `/mnt/home/rin/...`). It refuses
to continue unless `/mnt/home` is a distinct mount, the credentials decrypt and
authenticate, and exactly one `sh1m3ji` snapshot matches. It never deletes
files that are absent from the snapshot. Type `RESTORE` only after comparing the
snapshot ID, timestamp, target, and dry-run output. Don't launch Zen from the
live ISO; its restored profile must stay closed until Home Manager has run.

Without a clone, from just the recovery key and the pushed repo:

```sh
install -m600 /run/media/nixos/<RECOVERY_LABEL>/sh1m3ji-age-recovery.txt \
  /tmp/sh1m3ji-recovery-age-key.txt
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:buttermiilk/nixos#restore-sh1m3ji -- \
  --target /mnt --age-key /tmp/sh1m3ji-recovery-age-key.txt \
  --snapshot latest --dry-run
# then the same without --dry-run
```

Pin `github:buttermiilk/nixos/<COMMIT_SHA>` for a specifically tested revision.

### Before rebooting

The live ISO's home disappears on reboot, so the exact repo used for the
install, including the new hardware file, is copied into `/home/rin`. The user
copy of the age key lets `rin` edit secrets. The `chown` covers all of
`.config`, because `sudo install -D` creates missing parents as root and Home
Manager writes there as `rin`.

## Lost keys

### Only the recovery age key survives

Don't install the recovery key as the machine key. Use it to authorize a new
machine recipient while the old ciphertext is still decryptable:

```sh
umask 077
install -m600 /run/media/nixos/<RECOVERY_LABEL>/sh1m3ji-age-recovery.txt \
  /tmp/recovery-keys.txt
age-keygen -o /tmp/keys.txt
age-keygen -y /tmp/keys.txt
```

Replace only the `&sh1m3ji` recipient in `.sops.yaml` with the printed
`age1...`, keep the recovery recipient, then rewrap and verify both:

```sh
SOPS_AGE_KEY_FILE=/tmp/recovery-keys.txt sops updatekeys secrets/secrets.yaml
SOPS_AGE_KEY_FILE=/tmp/keys.txt sops decrypt secrets/secrets.yaml >/dev/null
SOPS_AGE_KEY_FILE=/tmp/recovery-keys.txt sops decrypt secrets/secrets.yaml >/dev/null
```

Copy `/tmp/keys.txt` to the off-device machine-key backup, commit and push the
rewrapped files if possible, and continue the install.

### Neither age key survives

The SOPS ciphertext can't be rewrapped, and the Restic snapshots are lost unless
the Restic password was backed up separately. This creates a new credential set;
revoke anything that may be lost or compromised rather than copying it forward.

Generate a machine key and a recovery key that stays off the laptop:

```sh
umask 077
install -d -m700 /tmp/sops-rekey
age-keygen -o /tmp/sops-rekey/sh1m3ji.txt
age-keygen -o /tmp/sops-rekey/recovery.txt
age-keygen -y /tmp/sops-rekey/sh1m3ji.txt
age-keygen -y /tmp/sops-rekey/recovery.txt
```

Put both recipients in one key group in `.sops.yaml`:

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

Move the dead ciphertext aside and create a new file (`mkpasswd` comes from
`nix shell nixpkgs#mkpasswd`):

```sh
mv secrets/secrets.yaml /tmp/sops-rekey/secrets.yaml.lost-key
mkpasswd -m yescrypt
sops secrets/secrets.yaml
```

```yaml
rin:
  password: "$y$..."
  github-pat: "REPLACE_WITH_GITHUB_PAT"
  modelapi-key: "REPLACE_WITH_MODELAPI_KEY"
  anymodel-key: "REPLACE_WITH_ANYMODEL_KEY"
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

Install the matching public SSH key on the company server, and give the GitHub
token only the scopes it needs. `AUTHORIZATION_REQUIRED` keeps the backup
coordinator gated until Google is authorized. A new Restic password starts a
new repository.

Verify both keys, then save them to two independent off-device locations:

```sh
SOPS_AGE_KEY_FILE=/tmp/sops-rekey/sh1m3ji.txt sops decrypt secrets/secrets.yaml >/dev/null
SOPS_AGE_KEY_FILE=/tmp/sops-rekey/recovery.txt sops decrypt secrets/secrets.yaml >/dev/null
install -m600 /tmp/sops-rekey/sh1m3ji.txt /tmp/keys.txt
install -m600 /tmp/sops-rekey/sh1m3ji.txt /run/media/nixos/<HOST_LABEL>/sh1m3ji-age-key.txt
install -m600 /tmp/sops-rekey/recovery.txt /run/media/nixos/<RECOVERY_LABEL>/sh1m3ji-age-recovery.txt
sync
```

Eject the backup drive before continuing with Disko.

## First boot

There's no display manager. Logging in on tty1 runs `startx`, which starts i3;
exiting i3 returns to the TTY. Don't add `~/.xinitrc` unless replacing the
generated session script.

Commit what the install produced:

```sh
cd ~/nix-config
git add flake.lock hosts/sh1m3ji/hardware-configuration.nix .sops.yaml secrets/secrets.yaml
git commit -m "Record installed hardware"
git push
```

### Drive backups

Google OAuth needs one browser step. Create a personal desktop OAuth client
following the [rclone Drive guide](https://rclone.org/drive/#making-your-own-client-id),
store its ID and secret under `rin` in `secrets/secrets.yaml`, and publish the
app (testing mode expires refresh tokens after seven days). Then:

```sh
nix run .#authorize-google-drive
git diff -- secrets/secrets.yaml
```

The tool writes the token back through SOPS without printing any credential.
If `backup/manifest.nix` has `enable = false`, set it to `true`, rebuild, and
create or refresh the inner key archive. The helper streams SSH, GnuPG, selected SOPS secrets, and CLI credentials directly into an archive encrypted to both age recipients in `.sops.yaml`; it does not write a plaintext staging archive:

```sh
bash home/rin/dotfiles/scripts/create-migration-key-archive.sh
age --decrypt --identity "$HOME/.config/sops/age/keys.txt" \
  "$HOME/Documents/Backups/sh1m3ji-migration-keys.tar.age" \
  | tar --list --file=-
```

The validation command prints filenames only. Refresh this archive when a key or included login changes. It sits below `Documents`, so the normal encrypted Restic job carries the ciphertext. Rebuild and take a first snapshot:

```sh
sudo nixos-rebuild switch --flake .#sh1m3ji
systemctl --user start restic-backups-gdrive.service
journalctl --user -u restic-backups-gdrive.service
```

Once that succeeds, *Backup and reboot* in the power menu is the normal
protected reboot. Plain *Reboot* stays available without a backup.

### Apps

Stuff I usually use are declared in the flake. The rest:

I play Roblox, on Linux the only practical way to play is Sober, and it's only 
distributed through Flatpak. I'll have to figure out a more elegant solution, 
but for now, install it for only a user, not system-wide, so its files live 
under the persistent `/home` subvolume:

```sh
flatpak remote-add --user --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub org.vinegarhq.Sober
```

I use `warp-cli` since it's rather neat, use it if you want (append a team name
to `registration new` for a Cloudflare One org). The enrollment survives in the
directly mounted `/var/lib/cloudflare-warp` subvolume.

```sh
warp-cli registration new
warp-cli connect
```

Fly.io only needs its normal interactive login: `fly auth login`.

#### osu! stable through osu-winello

I play osu! and the `osu-winello` project doesn't support NixOS out of the box, 
so we have to be a little more creative here.

The flake installs Winello's NixOS-side dependencies and an `osu-winello` 
launcher that runs the upstream client inside Steam's FHS environment. Winello 
itself manages a mutable Wine prefix and osu! installation, so install it after 
the first boot rather than putting it in the Nix store:

```sh
git clone https://github.com/NelloKudo/osu-winello.git ~/osu-winello
cd ~/osu-winello
chmod +x osu-winello.sh
steam-run ./osu-winello.sh
```

Choose **Custom path** in the installer and point it at `/home/rin/Documents/osu` when restoring an existing installation. The flake provides a declarative **osu! stable** menu entry that runs `osu-winello`, so remove Winello's duplicate launcher after installation. Keep its two hidden handler entries for `.osz`, `.osk`, and `osu://` links:

```sh
rm -f ~/.local/share/applications/osu-wine.desktop
update-desktop-database ~/.local/share/applications
```

The game can also be started from a terminal with `osu-winello`. The osu! files and songs live under the backed-up `Documents` tree. Winello's reconstructible Wine runtime, prefix, handlers, and `osu-wine` launcher live below `~/.local/share` and `~/.local/bin`; rerun the installer after a full reinstall.

The launcher also runs the game under `gamemoderun` (performance CPU governor)
and without fcitx5's XIM, which otherwise delays or drops key presses in Wine.
picom unredirects fullscreen windows so the game isn't composited. If it still
stutters, drop the keyboard's polling rate to 1000 Hz and pause Monitask.

I strongly suggest having your osu! installation on a different disk, and you 
point the installation to it so it uses your stuff. That also minimizes the stateful 
stuff on your NixOS disk.

#### Monitask

Work requires it. It's packaged from the official `.deb` in
`pkgs/monitask.nix` and is X11-only (fine under i3). Its built-in updater can't
work on NixOS; bump `version` and `hash` from the
[APT index](https://deskcap.blob.core.windows.net/deployment/Linux/deb/Release/dists/bionic/main/binary-amd64/Packages)
instead. Old `.deb`s may vanish upstream, which breaks the build until bumped.

#### OBS

The profile (QuickSync encoders, 1080p60 canvas and recordings, 720p60
stream, 48 kHz audio, dynamic bitrate) lives in `home/rin/modules/obs.nix` and
is copied over on every rebuild, so change it there rather than in Settings.
Rebuild with OBS closed, or it writes its old settings back on exit. The stream
key and scene collections are not declared: paste the key into OBS once; both
live under `~/.config/obs-studio/basic`, which the backup covers.

#### Eco mode

`$mod+b` (or `eco-mode toggle`) switches TLP to its power-saver profile (no
turbo, EPP `power`, low-power platform profile), stops picom, and caps
brightness at 40%. Polybar shows `eco` while it's on; click it or press `$mod+b`
again to restore all three. It resets on reboot.

#### GIMP (PhotoGIMP)

GIMP's first run is seeded with [PhotoGIMP](https://github.com/Diolinux/PhotoGIMP)
3.1 (Photoshop shortcuts and layout, 50 undo levels). GIMP owns those files
afterwards; delete `~/.config/GIMP/3.0` and rebuild to reset to PhotoGIMP.

#### Small Windows VMs

`tiny10-vm` is the low-resource option. It downloads NTDEV's Tiny10 23H2 x64
(based on Windows 10 IoT Enterprise LTSC 2021), verifies it, and creates a sparse
20 GiB disk under `~/.local/share/tiny10-vm`. It uses two vCPUs and 2 GiB of RAM.

After installing Windows, open the small guest-tools drive, run
`spice-guest-tools.exe` and `spice-webdavd-x64-2.4.msi` as Administrator, then
restart Windows. This enables host/guest clipboard integration and exposes
`/home/rin/Documents` as a read-write SPICE WebDAV drive. If the shared drive
does not appear automatically, run
`C:\Program Files\SPICE webdavd\map-drive.bat` in the guest.

Tiny10 is an unofficial, modified Windows image. Its `23H2` is the Tiny10 release
name; the underlying Windows release is IoT Enterprise LTSC 2021 (21H2).

### Check the rollback

```sh
sudo touch /rollback-probe
sudo reboot
```

After logging back in, `/rollback-probe` must be gone while Wi-Fi, WARP,
Bluetooth pairings, logs, and `/home` remain.

## Secrets (sops-nix)

Everything in `secrets/secrets.yaml` is age-encrypted so the repo can be public. 
The machine decrypts at boot with
`/persist/var/lib/sops-nix/age/keys.txt`; your editing copy of the same key sits 
at `~/.config/sops/age/keys.txt`

```sh
sops secrets/secrets.yaml          # edit secrets in $EDITOR, re-encrypts on save
```

To add a secret, add the value there, declare it in
`hosts/sh1m3ji/default.nix` under `sops.secrets`, rebuild. Plaintext shows up under `/run/secrets/` with the owner/permissions you declared. Point whatever needs it at that path; the plaintext never touches the repo or the nix store.

The password is declarative (`users.mutableUsers = false`, so `passwd` won't
stick). Rotate it with `nix shell nixpkgs#mkpasswd -c mkpasswd -m yescrypt`,
paste the hash over `rin/password` via `sops secrets/secrets.yaml`, and rebuild.

### Replace the machine key

The recovery key makes machine-key loss recoverable:

```sh
nix shell nixpkgs#age nixpkgs#sops
umask 077
age-keygen -o /tmp/sh1m3ji-new-age-key.txt
age-keygen -y /tmp/sh1m3ji-new-age-key.txt
```

Replace only `&sh1m3ji` in `.sops.yaml`, then rewrap with the recovery key,
verify both, install, and rebuild:

```sh
SOPS_AGE_KEY_FILE=/path/to/sh1m3ji-age-recovery.txt sops updatekeys secrets/secrets.yaml
SOPS_AGE_KEY_FILE=/tmp/sh1m3ji-new-age-key.txt sops decrypt secrets/secrets.yaml >/dev/null
SOPS_AGE_KEY_FILE=/path/to/sh1m3ji-age-recovery.txt sops decrypt secrets/secrets.yaml >/dev/null
sudo install -Dm600 /tmp/sh1m3ji-new-age-key.txt /persist/var/lib/sops-nix/age/keys.txt
install -Dm600 /tmp/sh1m3ji-new-age-key.txt "$HOME/.config/sops/age/keys.txt"
sudo nixos-rebuild switch --flake .#sh1m3ji
```

Back the new key up off-device. If a key may have been stolen rather than lost,
also run `sops rotate --in-place secrets/secrets.yaml` with the recovery key.
If the missing key blocks login, do this from the ISO after a Disko `mount`
(see below), prefixing the persistent paths with `/mnt`.

## Day-to-day

```sh
sudo nixos-rebuild switch --flake .#sh1m3ji   # apply config changes
nix flake update && sudo nixos-rebuild switch --flake .#sh1m3ji   # upgrade
flatpak update --user                          # Sober
```

`nixos-rebuild build` builds without activating; `test` activates until the
next reboot without changing the boot default. Commit `flake.lock` only after
the new generation has been tested.

Where things go:

- Apps, shell, and Home Manager settings: `home/rin/modules/`
- Services, hardware, users, locale, X: `hosts/sh1m3ji/default.nix`
- Root replacement and old-root retention: `hosts/sh1m3ji/rollback.nix`
- Disk layout (reinstall or migration only): `hosts/sh1m3ji/disko.nix`
- Secrets: `secrets/secrets.yaml`, only through `sops`

Declare packages in Nix rather than `nix profile install`, otherwise the repo
stops describing the machine.

If a change breaks things, run `sudo nixos-rebuild switch --rollback`, or hold
Space at boot and pick the previous generation. That's separate from the
fresh root: the root rollback discards mutable state on `/`, it doesn't choose
an older system.

Mutable files on `/` disappear at the next boot. Persistent service state must have an explicit direct subvolume in `disko.nix`; `rollback.nix` retains old roots for 30 days as a recovery window, not as a backup policy.

The store is garbage-collected weekly (generations older than 14 days) and
optimised automatically.

Health checks:

```sh
systemctl --failed
journalctl -b -p warning
lsblk -f && swapon --show        # data and swap behind /dev/mapper/crypted
findmnt -R / | grep crypted      # every persistent subvolume mounted directly
cat /proc/cmdline                # systemd.machine_id=firmware
```

## Recovery from the ISO

Keep the installer USB; it's also the recovery environment. Boot it in UEFI
mode, get the repo, check the disk with `lsblk`, then mount without formatting:

```sh
sudo nix --extra-experimental-features "nix-command flakes" \
  run .#disko -- --mode mount --flake .#sh1m3ji
```

It accepts either the LUKS passphrase or the recovery key. Make sure
`/mnt/persist/var/lib/sops-nix/age/keys.txt` exists, repair the config (or take
the repo from `/mnt/home/rin`), and reinstall without repartitioning:

```sh
sudo nixos-install --flake .#sh1m3ji --no-root-passwd
```

Never use Disko's `destroy` or `format` modes for recovery unless erasing the
machine is intentional.

Old roots are kept for 30 days. To inspect them:

```sh
sudo mkdir -p /mnt/btrfs-top
sudo mount -t btrfs -o subvolid=5 /dev/mapper/crypted /mnt/btrfs-top
sudo btrfs subvolume list /mnt/btrfs-top/root.old.d
```

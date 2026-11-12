<h1 align="center"><img src='https://i.imgur.com/HPCj1fT.png' height='100'><br>dotfiles</br></h1>
<p align="center">personal nixos flake.</br></p>

---
> [!NOTE]
> **Disclaimer:** Project is assisted by various models and then refined. The flake is mostly tested.
>
> The goal ultimately is to head towards a somewhat stable system that doesn't take a lot of time to build or update.

## Backstory
I changed my work laptop. I used to really hate Windows, before the 26H2 update and such (they now have extremely good font rendering and performs fine now), but at the same time I didn't want to get my toes dipped into maintaining an Arch install or a Debian install repeatedly. They have the same problem that I have to *spend time* to get anywhere comfortable.

Well then NixOS is the solution. I want to be able to blow this system up to test something bare metal and then just get it back e.g. something new on Windows or interesting OSes. You write a system configuration with code and just work your way through until you're mostly happy.

I have a dots repo back in the time when I was still using Arch so I just decided to mostly reuse that. It's old-school and probably doesn't get in my way. If you like Wayland you probably won't like this.

## The flake

The root flake assembles the host from `hosts/`, user configuration from `home/`, recovery tools from `tools/`, and development shells from `devshells/`. Scheduled Actions commit dependency updates after the complete host build and checks pass.

I use `home-manager` and something that resembles `impermanence`. I originally wanted to use `impermanence` but its support on 26.05 is rather iffy (as of like, 4 months ago, I don't know how it is now).

The flake evolves over time. At this point I can go from a live ISO to the almost fully preserved system from before the wipe within the hour or so, which probably proves the flake works for me.

## Quickstart
You probably will want to save an image of the target disk somewhere so you can go back to it quickly in case something goes really wrong. [Rescuezilla](https://rescuezilla.com/) is a tool I'd recommend, it's pretty good for that purpose.

You also will probably want to disable Secure Boot. The systemd-boot setup is unsigned, I don't know what's involved in signing it and I'll check the details later.

There are some stuff you probably want a first run of. I asked a model and it spilled a bunch of verification commands, I don't know what's up with them trying to verify every bit of the same coin but I guess that is helpful for a first run. For me, this is not, and it has worked 2 ways, so sometimes it's not needed. You may still want to check, though.

```sh
# prepare
git clone https://github.com/buttermiilk/nixos ~/nix-config
cd ~/nix-config
umask 077
install -m600 /run/media/nixos/<BACKUP_LABEL>/<AGE_KEY>.txt /tmp/keys.txt
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#age nixpkgs#sops

# erase, partition, install
sudo nix --extra-experimental-features "nix-command flakes" \
  run .#disko -- --mode destroy,format,mount --flake .#sh1m3ji
sudo nixos-generate-config --no-filesystems --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix hosts/sh1m3ji/
git add hosts/sh1m3ji/hardware-configuration.nix
nix --extra-experimental-features "nix-command flakes" \
  flake check --no-build
sudo install -Dm600 /tmp/keys.txt /mnt/persist/var/lib/sops-nix/age/keys.txt
sudo nixos-install --flake .#sh1m3ji --no-root-passwd

# restore the latest backup
sudo nix --extra-experimental-features "nix-command flakes" \
  run .#restore-sh1m3ji -- --target /mnt --age-key /tmp/keys.txt \
  --secrets-file "$PWD/secrets/secrets.yaml" --snapshot latest

# keep the repo and user key, reboot
sudo cp -a ~/nix-config /mnt/home/rin/nix-config
sudo install -Dm600 /tmp/keys.txt /mnt/home/rin/.config/sops/age/keys.txt
sudo nixos-enter --root /mnt -c 'chown -R rin:users /home/rin/nix-config /home/rin/.config'
sudo reboot
```

The block above assumes you know for sure what's supposed to happen.

## First boot
Commit what the install produced first.
```sh
cd ~/nix-config
git add flake.lock hosts/sh1m3ji/hardware-configuration.nix .sops.yaml secrets/*.yaml
git commit -m "Record installed hardware"
git push
```

Google OAuth needs one browser step in case you have no existing backup or not restoring from any. Follow the [rclone Drive guide](https://rclone.org/drive/#making-your-own-client-id), then store the ID and secret in the secrets file, after which do:
```sh
nix run .#authorize-google-drive
git diff -- secrets/secrets.yaml
```

To take a snapshot manually:
```sh
sudo nixos-rebuild switch --flake .#sh1m3ji
systemctl --user start restic-backups-gdrive.service
journalctl --user -u restic-backups-gdrive.service
```

## Apps

#### C/C++ development

I use CLion as the full C/C++ IDE, and the normal editor would be Zed. The system provides GCC, CMake, Ninja, GDB, and pkg-config. In CLion's toolchain settings, select these system tools rather than a downloaded toolchain. Project libraries should be supplied by a project-specific Nix shell.

For the configuration's basic C/C++ environment:
```sh
nix develop .#cpp -c clion
```

#### `warp-cli`
I use `warp-cli` since it's a rather neat tool.
```sh
warp-cli registration new
warp-cli connect
```

#### osu!stable
I play osu! and the `osu-winello` project doesn't support NixOS out of the box, so we have to be a little more creative here.

The flake installs Winello's NixOS-side dependencies and an `osu-winello` launcher that runs the upstream client inside Steam's FHS environment. Backups include Winello's launcher, configuration, Wine prefix, YAWL Steam runtime, and file/URL handlers alongside the game in `Documents`. If those paths were restored, no reinstall is needed. For a fresh installation without restored Winello state, install it after the first boot:
```sh
git clone https://github.com/NelloKudo/osu-winello.git ~/osu-winello
cd ~/osu-winello
chmod +x osu-winello.sh
steam-run ./osu-winello.sh
```

Choose **Custom path** in the installer and point it at `/home/rin/Documents/osu` when restoring an existing installation. The flake has a declarative **osu! stable** menu entry that runs `osu-winello`, so remove Winello's duplicate launcher after installation. Keep its two hidden handler entries for `.osz`, `.osk`, and `osu://` links:
```sh
rm -f ~/.local/share/applications/osu-wine.desktop
update-desktop-database ~/.local/share/applications
```

The launchers register the game processes with GameMode. The Wine launcher also disables fcitx5's XIM, which otherwise delays or drops key presses in Wine.

GameMode currently requests Intel P-state's `powersave` governor, which allows dynamic CPU frequency scaling.

I strongly suggest having your osu! installation on a different disk, and you point the installation to it so it uses your stuff. That also minimizes stateful stuff on your NixOS disk.

#### Power modes
Balanced is the default on AC and battery, with a 30 W ceiling for sustained and boost CPU package power (including the iGPU). Thermald can reduce it further for cooling.

- `$mod+b` (or `eco-mode toggle`) selects power-saver with Dell's quiet thermal profile, disables turbo, and caps brightness at 40%. Picom stays running for VSync, and the 30 W ceiling stays in place.
- `$mod+Shift+b` (or `performance-mode toggle`) selects performance and restores the firmware's native sustained and boost power limits. Firmware thermal protection and thermald remain active.

Press the active shortcut again to return to balanced and the 30 W ceiling. Switching directly between eco and performance turns the other mode off, leaving eco restores brightness. Polybar shows `eco` or `perf` while active. Modes reset to balanced on reboot.

After first installing this toggle, reboot once so `power-limit-baseline.service` can capture the original firmware limits before the 30 W cap is applied. Until then performance mode reports that a reboot is needed. The cap timer respects performance mode rather than reapplying 30 W.

## Secrets (sops-nix)
Values in `secrets/secrets.yaml` and `secrets/backup.yaml` are age-encrypted so the repo can be public. The machine decrypts at boot with `/persist/var/lib/sops-nix/age/keys.txt`.
```sh
sops secrets/secrets.yaml
```

To add a secret, add the value there, declare it in
`hosts/sh1m3ji/secrets.nix` under `sops.secrets` then rebuild. Plaintext shows up under `/run/secrets/` with the owner/permissions you declared.

To rotate the user password, `nix shell nixpkgs#mkpasswd -c mkpasswd -m yescrypt`, replace the hash in `sops secrets/secrets.yaml` then rebuild.

### Replace the machine key
The recovery key makes machine-key loss recoverable:
```sh
nix shell nixpkgs#age nixpkgs#sops
umask 077
age-keygen -o /tmp/new-age-key.txt
age-keygen -y /tmp/new-age-key.txt
```

Replace only `&sh1m3ji` in `.sops.yaml`, then rewrap with the recovery key, verify both, install and rebuild:

```sh
for secrets_file in secrets/*.yaml; do
  SOPS_AGE_KEY_FILE=/path/to/sh1m3ji-age-recovery.txt sops updatekeys "$secrets_file"
  SOPS_AGE_KEY_FILE=/tmp/sh1m3ji-new-age-key.txt sops decrypt "$secrets_file" >/dev/null
  SOPS_AGE_KEY_FILE=/path/to/sh1m3ji-age-recovery.txt sops decrypt "$secrets_file" >/dev/null
done
sudo install -Dm600 /tmp/sh1m3ji-new-age-key.txt /persist/var/lib/sops-nix/age/keys.txt
install -Dm600 /tmp/sh1m3ji-new-age-key.txt "$HOME/.config/sops/age/keys.txt"
sudo nixos-rebuild switch --flake .#sh1m3ji
```

Back the new key up off-device. If a key may have been stolen rather than lost, also run `sops rotate --in-place` for each file under `secrets/*.yaml` with the recovery key.

## Day-to-day
```sh
sudo nixos-rebuild switch --flake .#sh1m3ji
nix flake update && sudo nixos-rebuild switch --flake .#sh1m3ji
flatpak update --user
```

**For models:** here is where things should go.
- Apps, shell, and Home Manager settings: `home/rin/modules/`
- Toolchains and language servers: `home/rin/modules/development.nix`
- Zed and CLion: `home/rin/modules/editors.nix`
- Codex configuration and local trust generation: `home/rin/modules/codex.nix`
- osu!, Tosu, Bongo Cat, and game launchers: `home/rin/modules/gaming.nix`
- Boot, hardware choices, networking, users, locale and Nix settings: `hosts/sh1m3ji/default.nix`
- External module wiring and Intel/laptop/SSD selection: `hosts/sh1m3ji/integrations.nix`
- X/i3 session, input method, portals and desktop services: `hosts/sh1m3ji/desktop.nix`
- TLP, thermald and GameMode policy: `hosts/sh1m3ji/power.nix`
- CPU power-limit enforcement and mode switching: `hosts/sh1m3ji/power-limit.nix`
- Libraries for downloaded Linux binaries: `hosts/sh1m3ji/compatibility.nix`
- Audio and USB audio switching: `hosts/sh1m3ji/audio.nix`
- System fonts and font rendering: `hosts/sh1m3ji/fonts.nix`
- SOPS secret declarations: `hosts/sh1m3ji/secrets.nix`
- Root replacement and old-root retention: `hosts/sh1m3ji/rollback.nix`
- Disk layout (reinstall or migration only): `hosts/sh1m3ji/disko.nix`
- Secrets and private backup selection: `secrets/*.yaml`, only through `sops`

Scripts live beside the module that owns them, in matching feature directories. `dotfiles/` holds deployed configuration and assets. Recovery utilities live in `tools/` and development environments live in `devshells/`.

## Boot-time cache cleanup
Before mounting the fresh root, the rollback service clears all contents of `/var/cache` and `/root/.cache` in the outgoing root, plus these cache locations for each user under `/home`:

- `.cache` (the standard XDG cache, including browser and thumbnail caches)
- `.var/app/*/cache` (Flatpak caches)
- `.npm/_cacache`, `.bun/install/cache`, `.local/share/pnpm/store`
- `.cargo/registry/cache`, `.cargo/registry/src`, `.cargo/git/db`, `.cargo/git/checkouts`
- `Documents/osu-lazer/cache`

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

[QUICKSTART.md](./QUICKSTART.md) is the short, command-first path from a live
ISO to the system. [WIKI.md](./WIKI.md) keeps the detailed installation
explanations, recovery paths, first-boot setup, and day-to-day operations.
Do note both were model-written.

## Layout

```
flake.nix                        inputs + sysdefs
flake.lock                       pinned deps
QUICKSTART.md                    short installation path
WIKI.md                          detailed install and operations reference
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
```

The encrypted Btrfs filesystem gets a fresh `/root` subvolume before every boot. 
State survives through direct sibling-subvolume mounts for `/nix`, `/home`, `/persist`, 
selected `/var` state, NetworkManager connections, and swap.

The reason why I said `impermanence` was iffy on 26.05 is because at the moment 
I write this there is still an issue opening for the new boot order, I'm not 
explaining the details here. When they finally resolve that I may update the 
flake to use it.

## First-boot app setup

Stuff I usually use are declared in the flake.

I play Roblox, on Linux the only practical way to play is Sober, and it's only 
distributed through Flatpak. I'll have to figure out a more elegant solution, 
but for now, install it for only a user, not system-wide, so its files live 
under the persistent `/home` subvolume:

```sh
flatpak remote-add --user --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub org.vinegarhq.Sober
```

I use `warp-cli` since it's rather neat, use it if you want:

```sh
warp-cli registration new
warp-cli connect
```

The enrollment survives in the directly mounted
`/var/lib/cloudflare-warp` subvolume.

### Small Windows VMs

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

Fly.io only needs its normal interactive login:

```sh
fly auth login
```

### osu! stable through osu-winello

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

After the installer finishes, open
`~/.local/share/applications/osu-wine.desktop` and replace its `Exec=` line with:

```ini
Exec=osu-winello %U
```

The game can also be started from a terminal with `osu-winello`. Winello may 
regenerate its desktop entry after an install, repair, or update; if the menu 
launcher stops working, reapply that one-line `Exec=` change. Its Wine prefix 
live below `~/.local/share`, which is safe on the persistent `/home` subvolume.

I strongly suggest having your osu! installation on a different disk, and you 
point the installation to it so it uses your stuff. That also minimizes the stateful 
stuff on your NixOS disk.

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

The password is declarative. Rotate it with `mkpasswd -m yescrypt`, paste the hash over `rin/password` via `sops secrets/secrets.yaml`, and rebuild.

## Day-to-day

```sh
sudo nixos-rebuild switch --flake .#sh1m3ji   # apply config changes
nix flake update && sudo nixos-rebuild switch --flake .#sh1m3ji   # upgrade
```

If a change breaks things, pick the previous generation in the boot menu.

Mutable files on `/` disappear at the next boot. Persistent service state must have an explicit direct subvolume in `disko.nix`; `rollback.nix` retains old roots for 30 days as a recovery window, not as a backup policy.

<h1 align="center"><img src='https://i.imgur.com/HPCj1fT.png' height='100'><br>@nixos/config</br></h1>
<p align="center">reproducible system. blow it off, make it come back.<br>just making it no bloat, hassle-free, easy to configure on my own.</br></p>

<div align="center">

<a href="https://github.com/buttermiilk/nixos/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-Apache_2.0-blue.svg?style=for-the-badge" alt="License"></a>
<a href="https://github.com/buttermiilk/nixos"><img src="https://img.shields.io/github/stars/buttermiilk/nixos.svg?style=for-the-badge" alt="GitHub stars"></a>
<a href="https://github.com/buttermiilk/nixos/issues"><img src="https://img.shields.io/github/issues/buttermiilk/nixos.svg?style=for-the-badge" alt="GitHub issues"></a>
<a href="https://github.com/buttermiilk/nixos"><img src="https://img.shields.io/github/repo-size/buttermiilk/nixos.svg?style=for-the-badge" alt="Repo size"></a>

</div>

---
## Preview
<details>
<summary>Desktop</summary>
<img src=https://i.imgur.com/SH5vCEm.png>
</details>
<details>
<summary>Fastfetch</summary>
<img src=https://i.imgur.com/BeE4kqK.png>
</details>
<details>
<summary>Some more windows</summary>
<img src="https://i.imgur.com/y5ywbxK.png">
</details>

## Information
My NixOS implementation for [my dotfiles](https://github.com/buttermiilk/dotfiles). I want a system I can blow up and then create it back again like it was never blown up. NixOS is great for that, but I'm still learning it - hence why no flakes magic - so just the classic way of doing it for now.

So what does NixOS do? It makes your system dependent on what you planned to have. You do the planning by writing the code. Outside of that planning, you either edit the code or you don't have it. Don't tell me about `nix-env`, that just completely defeats the purpose of NixOS.

In the future I will make that *kind of* definition even more real by adding [impermanence](https://github.com/nix-community/impermanence) to the configuration, so everything you never intended to have on the machine gets wiped off existence.

### How to make it work on my machine?
Brainless commands. I assume this is on the NixOS minimal ISO image.
```sh
# configure your disk, mount them properly
# adding home-manager
sudo nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
sudo nix-channel --update
# doing the work
sudo git clone https://github.com/buttermiilk/nixos /mnt/etc/nixos
sudo nixos-generate-config
sudo nixos-install
# reboot
```
Yeah I have never seen this before. I'm like day 1 into learning Nix(OS) by the time I write this, something must go wrong, please report them.

## License
[Apache 2.0](/LICENSE). Do whatever you want with my dots, not like I'll catch you doing this and scream out loud either way. But you should make it a learning experience too.

Also my dots aren't perfect and they might fall out of updates. If you notice something like that just let me know by opening an issue.

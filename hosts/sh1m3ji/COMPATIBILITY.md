# Dell Latitude 5421

Inspected from Windows on 2026-11-01. This is a provisional Linux assessment;
the live ISO checks below are still required before erasing Windows.

| Component | Observed hardware |
| --- | --- |
| Mainboard / BIOS | Dell 0VVF47 A00 / 1.42.0, dated 2025-09-02 |
| CPU / RAM | Intel i7-11850H / 16 GB |
| Graphics | Intel UHD, PCI 8086:9a60; no NVIDIA adapter enumerated |
| Internal disk | WD PC SN530 NVMe 256 GB |
| Ethernet | Intel I219-LM, PCI 8086:15f9 |
| Wi-Fi | Qualcomm QCA61x4A (QCA6174), PCI 168c:003e |
| Bluetooth | Qualcomm, USB 0cf3:e007 |
| Internal audio | Intel Smart Sound / Realtek ALC236 |
| Other | Thunderbolt 9a1f, Realtek card reader 10ec:525a |

A 500 GB JMicron-attached disk and the Chu2 DSP / USB hub audio are also
connected. Identify the internal NVMe by model and size in Linux; do not
select the external disk. Windows does not establish Linux device names.
No camera or fingerprint device appeared in the targeted inventory; that
does not establish whether those optional devices are physically installed.

## Assessment and sources

No installation blocker was established by this review. Dell explicitly lists
[Ubuntu 20.04 support](https://www.dell.com/support/home/en-us/drivers/supportedos/latitude-14-5421-laptop),
and the model appears in [Ubuntu's certification list](https://ubuntu.com/certified/laptops?category=Laptop&limit=20&offset=60&q=latitude).
These are model-level evidence, not certification of this particular unit or NixOS.

The [upstream ath10k documentation](https://wireless.docs.kernel.org/en/latest/en/users/drivers/ath10k.html)
lists QCA6174 support and known limitations, including poor transmit performance
on some chips. Wireless throughput and reconnection after sleep need testing;
there is no basis here to install an out-of-tree driver preemptively.

An older Ubuntu report, [1952823](https://bugs.launchpad.net/bugs/1952823),
describes a screen blink when entering suspend on this model (also indexed in
the Ubuntu kernel mailing-list archive). Its current resolution could not be
verified. Treat sleep as a live-test requirement rather than forcing an ACPI
sleep mode or adding historical kernel workarounds.

Redistributable firmware is explicit in the host configuration. NixOS's
[firmware module](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/hardware/all-firmware.nix)
includes linux-firmware and SOF firmware under that setting. Keep normal
Intel graphics and audio autodetection; do not force an audio DSP driver.

The previous HP's 18/30 W and 7/12 W RAPL limits are no longer imported.
They were measured for another CPU and chassis. TLP, thermald, and eco mode
remain enabled; evaluate temperatures under the actual game/OBS workload
before choosing Dell-specific package limits.

## Linux throttling history

This model did have a Linux-specific performance problem. A report in the
[Dell throttling thread](https://www.dell.com/community/en/conversations/latitude/latitude-542074207520-cpu-throttling-issue-on-linux/647f94baf4ccf8a8de71684e?commentId=647f9846f4ccf8a8deb5e05f&page=6)
specifically identifies a Latitude 5421 / i7-11850H dropping to 800 MHz under
multi-threaded compression in November 2021. Reports for the 5420's U-series
CPU should not be treated as measurements of this H-series machine.

Intel's [thermald release notes](https://github.com/intel/thermal_daemon/blob/master/README.txt)
explicitly list a Latitude 5421 performance fix in release 2.4.9. The adjacent
7320/7420 fix also requires the kernel's updated INT340x policy handshake.
The [kernel patch explanation](https://lists.ubuntu.com/archives/kernel-team/2022-May/130316.html)
describes Tiger Lake firmware limiting performance shortly after turbo when
the OS has not advertised thermal-policy capabilities correctly. These are
historical upstream fixes, not grounds to assume every current BIOS is faultless.

The exact nixpkgs revision in `flake.lock`,
`26f4107e47e3ad0ffd0db220469ba83b6f6d96e8`, packages
[thermald 2.5.11](https://github.com/NixOS/nixpkgs/blob/26f4107e47e3ad0ffd0db220469ba83b6f6d96e8/pkgs/by-name/th/thermald/package.nix).
Its [NixOS service](https://github.com/NixOS/nixpkgs/blob/26f4107e47e3ad0ffd0db220469ba83b6f6d96e8/nixos/modules/services/hardware/thermald.nix)
uses `--adaptive` when no custom configuration file is set, as in this flake.
Both source files were fetched directly for this review. No package override
or additional thermald flag is needed for the historical fix.

Keep `services.thermald.enable = true`. Do not disable thermal protections,
force maximum clocks, or install a register-writing throttling workaround
without reproducing and diagnosing a remaining fault. Normal sustained-load
power/temperature limiting is expected; becoming stuck around 400–800 MHz
under load while cool is a different symptom. Idle clocks are not diagnostic.

Before erasing Windows, test the live Linux session on the intended charger
with thermald running. An ISO that omits thermald does not test this flake's
thermal configuration. In a NixOS live session:

```sh
nix shell nixpkgs#thermald nixpkgs#stress-ng nixpkgs#turbostat nixpkgs#lm_sensors
thermald --version                        # must include the 2.4.9 model fix
systemctl status thermald
# If no thermald service is running, run this in a separate terminal:
sudo thermald --no-daemon --adaptive
# In another terminal, monitor actual busy clocks, package watts and temperature:
sudo turbostat --interval 2
# In another terminal, run a bounded sustained CPU load:
stress-ng --cpu 0 --timeout 10m --metrics-brief
```

Do not run a second thermald alongside an existing service. Record results on
AC, repeat after suspend/resume and an AC disconnect/reconnect, and check a
real game/OBS session after installation. Reduced performance on battery alone
is not proof of the historical bug. Confirm the BIOS recognizes the charger's
wattage. Persistent low clocks while cool, failure to recover after load, or
unusable UI under load needs investigation before committing to the install.

## Before partitioning

1. Check Dell's BIOS updates for this model. The installed version above is
   recorded, not asserted to be current. Do not flash firmware as part of this review.
2. Check Secure Boot in firmware: its Windows query was denied. This flake's
   systemd-boot setup does not configure signed Secure Boot; disable Secure
   Boot for this installation unless deliberately adding signing support.
3. Boot the intended NixOS ISO in UEFI mode. Test Wi-Fi throughput, Ethernet,
   Bluetooth pairing/audio, speakers, microphone, headphone jack, brightness,
   touchpad, HDMI/USB-C displays, and any camera/card reader you use.
4. Suspend and resume several times, on AC and battery, with the USB hub both
   attached and detached. Check that Wi-Fi, Bluetooth and audio recover.
   Inspect `cat /sys/power/mem_sleep` and `journalctl -b -p warning`.
5. Run `lsblk -d -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN` and `lspci -nnk`.
   Windows currently uses a standard NVMe controller; if the ISO cannot see
   the disk, inspect firmware storage mode before proceeding.
6. Generate the Dell's hardware scan before partitioning, using the README's
   `--no-filesystems --show-hardware-config` instructions. Stage it and run
   `nix flake check --no-build --no-update-lock-file`. After Disko mounts the
   target, refresh the scan against `/mnt`, then repeat evaluation before installation.

The checked-in hardware file is still the previous Linux scan: Windows cannot
generate its replacement. No Nix evaluation or build was possible here because
neither Nix nor WSL is installed. The 8 GB disk swapfile is retained; hibernation
is not configured or promised. The updated layout uses a 1 GiB ESP and gives
the rest of the disk to LUKS2/Btrfs. Disko erases the entire
selected disk, including Windows; it does not create a dual-boot installation.

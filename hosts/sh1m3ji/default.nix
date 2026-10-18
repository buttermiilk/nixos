# HP EliteBook 630 G9 — i5-1235U, Iris Xe, 12 GB RAM, 512 GB NVMe
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Sets the hub's 3.5 mm jack (0020:0b21) unauthorized while the Chu2 DSP
  # (31b2:0113) is present, authorized otherwise. udev runs it on add/remove of
  # either device. On remove the Chu2's sysfs entry is already gone, so a Chu2
  # remove event is treated as "absent".
  chu2Exclusive = pkgs.writeShellScript "chu2-exclusive" ''
    chu2=0
    jacks=
    for d in /sys/bus/usb/devices/*; do
      [ -r "$d/idVendor" ] || continue
      case "$(${pkgs.coreutils}/bin/cat "$d/idVendor"):$(${pkgs.coreutils}/bin/cat "$d/idProduct")" in
        31b2:0113) chu2=1 ;;
        0020:0b21) jacks="$jacks $d" ;;
      esac
    done
    if [ "$ACTION" = remove ] && [ "''${PRODUCT%%/*}" = 31b2 ]; then
      chu2=0
    fi
    for d in $jacks; do
      echo $((1 - chu2)) > "$d/authorized"
    done
  '';
in

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ./rollback.nix
    ./power-limit.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 5;

  # Keep boot failures recoverable even though the stage-2 root account is
  # locked. This initrd shell does not bypass LUKS or expose the encrypted disk.
  boot.initrd.systemd.emergencyAccess = true;

  # `/etc/machine-id` lives on the disposable root. Ask systemd to derive the
  # same ID from the machine's firmware on every boot instead of persisting the
  # file with a bind mount.
  boot.kernelParams = [ "systemd.machine_id=firmware" ];

  networking.hostName = "sh1m3ji";
  networking.networkmanager.enable = true;

  # Prefer IPv4 when a destination publishes both address families. Some
  # networks advertise an IPv6 default route without providing working IPv6;
  # keeping IPv6 enabled but sorting IPv4 first avoids long connection stalls.
  networking.getaddrinfo.precedence."::ffff:0:0/96" = 100;

  # Required by the binary-only Cloudflare WARP client.
  nixpkgs.config.allowUnfree = true;

  time.timeZone = "Asia/Bangkok";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.addons = [ pkgs.qt6Packages.fcitx5-unikey ];
    };
  };

  # X11 + i3 (the i3 config itself is managed by home-manager)
  services.xserver = {
    enable = true;
    windowManager.i3.enable = true;
    displayManager.startx = {
      enable = true;
      # Provides /etc/X11/xinit/xinitrc, which starts the enabled i3 session.
      generateScript = true;
    };
  };
  services.libinput.enable = true;

  # physlock locks every VT (X session included) and blocks VT switching, so
  # it works from i3 and from a plain tty, without ending the session.
  services.physlock = {
    enable = true;
    allowAnyUser = true; # setuid wrapper, so the user can run it unprivileged
    muteKernelMessages = true;
  };

  # PipeWire with PulseAudio compat, so the pactl volume binds in i3 keep working
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;

    # Moondrop Chu2 DSP low-latency profile
    #
    # The Chu2 is a full-speed (12 Mbps) async USB device, so it needs
    # different settings from PipeWire's defaults:
    #
    #   audio.format = S16LE
    #     The default S24_3LE altset played at the wrong pitch and glitched.
    #     16-bit also uses less of the shared full-speed bandwidth.
    #   audio.rate = 48000
    #     Matches the graph rate, so nothing is resampled.
    #   api.alsa.period-size = 512, api.alsa.period-num = 3
    #     The driver HALVES the requested period, so this gives a real
    #     256-frame period and a 768-frame buffer (~16 ms). Measured values:
    #       default            128 x 256 periods  huge buffer, high latency
    #       first fix         512 x 3, buffer 1536  ~33 ms delay, uneven offset
    #       request 256 x 2   128 x 2, buffer 256   ~9 ms, good offset, but the
    #                          graph quantum dropped to 128 and voice-chat
    #                          streams (360/1440-frame requests) crackled with
    #                          "spa.audioconvert: out of buffers"
    #       request 512 x 3   256 x 3, buffer 768   current: quantum 256 matches
    #                          osu!'s request, no starvation, offset acceptable
    #     If the offset needs to go lower, try 256 x 3, but expect the voice
    #     crackle to return. If crackling returns at this setting, try 1024 x 3.
    #   api.alsa.headroom = 0
    #     No extra ALSA-side padding on top of the buffer above.
    #
    # Bandwidth: the Chu2 and the hub's 3.5 mm jack are both full-speed audio
    # behind the hub's single transaction translator, which fits only one. See
    # the chu2Exclusive udev rule below.
    wireplumber.extraConfig."51-chu2-dsp" = {
      "monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = "~alsa_output.usb-KTMicro_Chu2_DSP.*"; } ];
          actions.update-props = {
            "audio.format" = "S16LE";
            "audio.rate" = 48000;
            "api.alsa.period-size" = 512;
            "api.alsa.period-num" = 3;
            "api.alsa.headroom" = 0;
          };
        }
      ];
    };
  };

  # ArtCraft's Photoshop and After Effects counterparts (early releases), from
  # the artcraft flake input. The module also links /usr/share/fonts, the
  # only place the apps' text tools look for fonts.
  programs.artcraft = {
    enable = true;
    apps = [
      "photocraft"
      "effectcraft"
    ];
  };

  # Sober is installed from Flathub as a per-user Flatpak after first boot.
  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "gtk";
  };

  # Installs warp-cli and runs the Cloudflare One/WARP daemon. Enrollment is
  # interactive after first boot; its state has a dedicated Btrfs subvolume.
  services.cloudflare-warp.enable = true;

  # nixos-hardware's common-cpu-intel already enables graphics and adds the
  # VAAPI/compute runtimes. Iris Xe only needs iHD; the default (null) would also
  # pull in the legacy i965 driver and Intel's CPU OpenCL runtime.
  hardware.intelgpu.vaapiDriver = "intel-media-driver";

  # gamemode is requested by the osu-winello wrapper for each osu!.exe. It
  # used to switch to the performance governor, but that pins every core at
  # full boost: on 2026-10-12 three idle tourney clients held 3.4 GHz at
  # 83 °C and the iGPU was clamped by the shared PL1 budget (see
  # power-limit.nix). powersave with balance_performance EPP still ramps
  # within milliseconds under HWP and leaves that budget to the GPU, so keep
  # it. Its polkit rule only lets members of the `gamemode` group change the
  # governor (see users.users.rin).
  programs.gamemode = {
    enable = true;
    settings.general.desiredgov = "powersave";
  };

  # Sustained gaming load hits the package thermal limit hard. thermald steps
  # power down gradually instead of leaving it to abrupt PROCHOT throttling.
  services.thermald.enable = true;

  # nixos-hardware's laptop profile enables TLP. `eco-mode` switches it to
  # the power-saver profile (`_SAV` values); AC and BAT values must be given
  # too, or TLP copies the SAV value into them.
  services.tlp.settings = {
    CPU_BOOST_ON_AC = 1;
    CPU_BOOST_ON_BAT = 1;
    CPU_BOOST_ON_SAV = 0;
    CPU_HWP_DYN_BOOST_ON_AC = 1;
    CPU_HWP_DYN_BOOST_ON_BAT = 0;
    CPU_HWP_DYN_BOOST_ON_SAV = 0;
    PCIE_ASPM_ON_AC = "default";
    PCIE_ASPM_ON_BAT = "powersupersave";
  };
  security.sudo.extraRules = [
    {
      users = [ "rin" ];
      commands =
        map
          (profile: {
            command = "/run/current-system/sw/bin/tlp ${profile}";
            options = [ "NOPASSWD" ];
          })
          [
            "power-saver"
            "balanced"
            "performance"
          ];
    }
  ];

  # 12 GB is tight with Discord, Zen, and an IDE open. Compressed RAM swap is
  # used before the disk swapfile, avoiding multi-second stalls on LUKS+Btrfs.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  services.fstrim.enable = true; # weekly SSD trim through the LUKS mapper
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # NuPhyIO uses Chrome's WebHID API, which needs access to the keyboard's
  # hidraw interfaces. Restrict that access to the Air75 HE (normal 6120 and
  # bootloader/upgrader 6f10) plugged into this machine instead of making every
  # HID device world-writable.
  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="19f5", ATTRS{idProduct}=="6120|6f10", MODE="0660", GROUP="users", TAG+="uaccess"

    # The Chu2 DSP (31b2:0113) and the 3.5 mm jack on the USB hub (0020:0b21)
    # are both full-speed audio devices behind the hub's single transaction
    # translator, which has bandwidth for only one. Deauthorize the jack while
    # the Chu2 is plugged in and bring it back once the Chu2 is gone.
    ACTION=="add|remove", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{PRODUCT}=="31b2/113/*|20/b21/*", RUN+="${chu2Exclusive}"
  '';

  programs.zsh.enable = true;

  # Allow Playwright's upstream Chromium builds to run on NixOS. Browser
  # revisions are downloaded into ~/.cache/ms-playwright by Playwright itself.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      curl
      dbus
      expat
      glib
      gtk3
      libgbm
      libx11
      libxcb
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxkbcommon
      libxrandr
      nspr
      nss
      pango
      systemd
      vulkan-loader
    ];
  };

  # Secrets live encrypted in secrets/secrets.yaml (safe to push).
  # At boot, sops-nix decrypts them into /run/secrets* using the age key,
  # which lives on the LUKS-protected /persist subvolume and in backups.
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/persist/var/lib/sops-nix/age/keys.txt";
    secrets =
      lib.genAttrs
        [
          "rin/github-pat"
          "rin/modelapi-key"
          "rin/anymodel-key"
          "rin/google-drive-token"
          "rin/google-drive-client-id"
          "rin/google-drive-client-secret"
          "rin/access-key-id"
          "rin/secret-access-key"
          "rin/endpoint"
          "rin/bucket"
          "rin/restic-password"
          "rin/ssh/company"
        ]
        (_: {
          owner = "rin";
          mode = "0400";
        })
      // {
        # Decrypted extra-early, before user creation.
        "rin/password".neededForUsers = true;
      };
  };

  # Keep the login password declarative and out of the Nix store.
  users.mutableUsers = false;
  users.users.rin = {
    isNormalUser = true;
    # Restic preserves numeric ownership when restoring into /mnt from the ISO.
    uid = 1000;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
      "kvm"
      "video"
      "gamemode"
    ];
    hashedPasswordFile = config.sops.secrets."rin/password".path;
  };

  # thunar needs these two services for mounts/trash and thumbnails
  programs.thunar.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  programs.dconf.enable = true;

  # FreeType disables stem darkening by default. Turning it on emboldens thin
  # stems at small sizes the way macOS (and recent Windows) do, which pairs
  # with the grayscale, lightly hinted rendering below.
  environment.variables.FREETYPE_PROPERTIES = "cff:no-stem-darkening=0 autofitter:no-stem-darkening=0";

  # System-wide font families and macOS-style rendering. Generic family names
  # such as "sans-serif" and "monospace" inherit these choices in GTK, X11,
  # browsers, and other fontconfig-aware applications.
  fonts = {
    packages = with pkgs; [
      adwaita-fonts
      nerd-fonts.fantasque-sans-mono # monospace
      googlesans-code # monospace fallback; covers Vietnamese, Fantasque does not
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      material-icon-font
    ];

    fontconfig = {
      enable = true;
      antialias = true;
      # Slight hinting snaps only vertical metrics, keeping glyph shapes
      # faithful instead of forcing them onto the pixel grid.
      hinting = {
        enable = true;
        style = "slight";
      };
      # Grayscale antialiasing instead of RGB subpixel: no colour fringes and
      # a softer, more even look, as on macOS.
      subpixel = {
        rgba = "none";
        lcdfilter = "none";
      };
      defaultFonts = {
        sansSerif = [
          "Adwaita Sans"
          "Noto Sans CJK SC"
        ];
        serif = [
          "Adwaita Sans"
          "Noto Sans CJK SC"
        ];
        monospace = [
          "FantasqueSansM Nerd Font"
          "Google Sans Code"
          "Noto Sans CJK SC"
        ];
        emoji = [ "Noto Color Emoji" ];
      };
      # Apps that request Fantasque by name (Discord, VSCodium) skip the
      # monospace list above, so chain the fallback onto the family itself.
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
          <alias binding="same">
            <family>FantasqueSansM Nerd Font</family>
            <accept><family>Google Sans Code</family></accept>
          </alias>
          <!-- With hintslight, Chromium's Skia leaves horizontal metrics
               unhinted, so glyphs straddle pixels and look smeared next to
               Pango. Medium hinting brings Electron apps back in line. -->
          <match target="font">
            <test name="prgname" compare="eq"><string>codium</string></test>
            <edit name="hintstyle" mode="assign"><const>hintmedium</const></edit>
          </match>
          <match target="font">
            <test name="prgname" compare="eq"><string>.Discord-wrapped</string></test>
            <edit name="hintstyle" mode="assign"><const>hintmedium</const></edit>
          </match>
          <match target="font">
            <test name="prgname" compare="eq"><string>Discord</string></test>
            <edit name="hintstyle" mode="assign"><const>hintmedium</const></edit>
          </match>
        </fontconfig>
      '';
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    sops
    age
    gnupg
    cryptsetup
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # configurationLimit only trims boot entries; this also frees the store.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;

  system.stateVersion = "26.05"; # never change this after install
}

# HP EliteBook 630 G9 — i5-1235U, Iris Xe, 12 GB RAM, 512 GB NVMe
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ./rollback.nix
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

  # PipeWire with PulseAudio compat, so the pactl volume binds in i3 keep working
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
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

  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.intel-media-driver ]; # VAAPI for Iris Xe
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
    ];
    hashedPasswordFile = config.sops.secrets."rin/password".path;
  };

  # thunar needs these two services for mounts/trash and thumbnails
  programs.thunar.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  programs.dconf.enable = true;

  # System-wide font families and smooth LCD rendering. Generic family names
  # such as "sans-serif" and "monospace" inherit these choices in GTK, X11,
  # browsers, and other fontconfig-aware applications.
  fonts = {
    packages = with pkgs; [
      adwaita-fonts
      fantasque-sans-mono
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      pkgs.material-icon-font
    ];

    fontconfig = {
      enable = true;
      antialias = true;
      hinting = {
        enable = true;
        style = "slight";
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "default";
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
          "Fantasque Sans Mono"
          "Noto Sans CJK SC"
        ];
        emoji = [ "Noto Color Emoji" ];
      };
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

  system.stateVersion = "26.05"; # never change this after install
}

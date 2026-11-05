{
  config,
  lib,
  pkgs,
  ...
}:

let

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

  boot.initrd.systemd.emergencyAccess = true;

  boot.kernelParams = [ "systemd.machine_id=firmware" ];

  networking.hostName = "sh1m3ji";
  networking.networkmanager.enable = true;

  hardware.enableRedistributableFirmware = true;

  networking.getaddrinfo.precedence."::ffff:0:0/96" = 100;

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

  services.xserver = {
    enable = true;
    windowManager.i3.enable = true;
    displayManager.startx = {
      enable = true;

      generateScript = true;
    };
  };
  services.libinput.enable = true;

  services.physlock = {
    enable = true;
    allowAnyUser = true;
    muteKernelMessages = true;
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;

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

  programs.artcraft = {
    enable = true;
    apps = [
      "photocraft"
      "effectcraft"
    ];
  };

  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "gtk";
  };

  services.cloudflare-warp.enable = true;

  hardware.intelgpu.vaapiDriver = "intel-media-driver";

  programs.gamemode = {
    enable = true;
    settings.general.desiredgov = "powersave";
  };

  services.thermald.enable = true;

  services.tlp.settings = {
    # Start balanced on either power source; keyboard toggles select
    # TLP's performance/AC and power-saver/SAV settings explicitly.
    TLP_DEFAULT_MODE = "BAL";
    TLP_AUTO_SWITCH = 0;
    PLATFORM_PROFILE_ON_AC = "performance";
    PLATFORM_PROFILE_ON_BAT = "balanced";
    PLATFORM_PROFILE_ON_SAV = "quiet";
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

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  services.fstrim.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="19f5", ATTRS{idProduct}=="6120|6f10", MODE="0660", GROUP="users", TAG+="uaccess"

    ACTION=="add|remove", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{PRODUCT}=="31b2/113/*|20/b21/*", RUN+="${chu2Exclusive}"
  '';

  programs.zsh.enable = true;

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

        "rin/password".neededForUsers = true;
      };
  };

  users.mutableUsers = false;
  users.users.rin = {
    isNormalUser = true;

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

  programs.thunar.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  programs.dconf.enable = true;

  environment.variables.FREETYPE_PROPERTIES = "cff:no-stem-darkening=0 autofitter:no-stem-darkening=0";

  fonts = {
    packages = with pkgs; [
      adwaita-fonts
      nerd-fonts.fantasque-sans-mono
      googlesans-code
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      material-icon-font
    ];

    fontconfig = {
      enable = true;
      antialias = true;

      hinting = {
        enable = true;
        style = "slight";
      };

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
    libsmbios
    lm_sensors
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

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;

  system.stateVersion = "26.05";
}

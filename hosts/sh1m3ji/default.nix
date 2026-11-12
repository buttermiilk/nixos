{
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./audio.nix
    ./boot.nix
    ./compatibility.nix
    ./desktop.nix
    ./fonts.nix
    ./secrets.nix
    ./hardware-configuration.nix
    ./disko.nix
    ./rollback.nix
    ./power.nix
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
  i18n.defaultLocale = "en_US.UTF-8";

  services.cloudflare-warp.enable = true;

  hardware.intelgpu.vaapiDriver = "intel-media-driver";

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  services.fstrim.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="19f5", ATTRS{idProduct}=="6120|6f10", MODE="0660", GROUP="users", TAG+="uaccess"
  '';

  programs.zsh.enable = true;

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

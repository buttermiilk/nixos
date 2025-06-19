{ config, pkgs, ... }:

{
  # we state the version of our system
  system.stateVersion = "25.05";
  # enable the use of flakes and the new nix command
  # these are still under experimental for years
  # but the community has widely adopted this great feature
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # uncomment these 2 lines for uefi
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;

  # for vbox etc bios
  # comment these out if you're using uefi
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  # the hostname of the system
  # this should be the filename
  networking.hostName = "NAVI";
  # the timezone of our system
  time.timeZone = "Asia/Ho_Chi_Minh";
  # the locale we want to use
  i18n.defaultLocale = "en_US.UTF-8";
  # the keymap we want to use
  console.keyMap = "us";

  # declare our users of this host
  # we have to make a user here before making a home-manager entry
  # for that user
  users.users.rin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "audio" "video" ];
    shell = pkgs.zsh;
  };

  # enable the x11 display server
  # if you use wayland, do wayland, etc, check the docs
  services.xserver = {
    enable = true;
    # use i3
    windowManager.i3.enable = true;
    # use startx to point i3 to the right configuration files
    displayManager.startx.enable = true;
    # set xkb layout to what we set in the keymap
    xkb.layout = "us";
  };

  # approximate the lat/long for several commands
  # like redshift
  location = {
    latitude = 10.75;
    longitude = 106.67;
  };

  # enable zsh
  # merely personal thing here, choose what you like
  programs.zsh.enable = true;

  # redshift (night light) options
  services.redshift = {
    enable = true;
    temperature = {
      day = 5700;
      night = 3500;
    };
  };

  # audio server
  # for some games in wine, pipewire is a little better with latency
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
  };

  # choose the system fonts
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  # the packages this host will have globally
  # preferably have the dotfiles' packages in home-manager
  environment.systemPackages = with pkgs; [
    xorg.xinit
    kitty
    fastfetch
    feh
    i3status-rust
    picom
    rofi
    pavucontrol
    dunst
    xfce.thunar
    gtk3
    zsh
    btop
    vim
    flameshot
    redshift
    brightnessctl
    git
    firefox
  ];
}

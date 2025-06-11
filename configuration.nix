{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./home.nix  # Home Manager stuff
    <home-manager/nixos>
  ];

  system.stateVersion = "25.05";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "shimeji-nix";
  time.timeZone = "Asia/Ho_Chi_Minh";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  users.users.rin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "audio" "video" ];
    shell = pkgs.zsh;
  };

  services.xserver = {
    enable = true;
    windowManager.i3.enable = true;
    displayManager.startx.enable = true;
    xkb = {
      layout = "us";
    };
  };

  programs.zsh.enable = true;
  services.redshift.enable = true;
  services.redshift.latitude = 10.75;
  services.redshift.longitude = 106.67;

  hardware.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
  };

  environment.systemPackages = with pkgs; [
    xorg.xinit
    kitty
    fastfetch
    i3status-rust
    picom
    rofi
    pavucontrol
    dunst
    thunar
    gtk3
    zsh
    btop
    vim
    flameshot
    redshift
    brightnessctl
    ttf-jetbrains-mono-nerd
    git
    firefox
  ];
}

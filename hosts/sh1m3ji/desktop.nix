{ pkgs, ... }:

{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = [ pkgs.qt6Packages.fcitx5-unikey ];
  };

  services.xserver = {
    enable = true;
    windowManager.i3.enable = true;
    displayManager.startx = {
      enable = true;
      generateScript = true;
      extraCommands = ''
        # Complete the keyring startup begun by PAM at the console login.
        /run/wrappers/bin/gnome-keyring-daemon --start --components=secrets
      '';
    };
    inputClassSections = [
      ''
        Identifier "Pebble M350s pointer speed"
        MatchProduct "Pebble M350s Mouse"
        MatchIsPointer "on"
        MatchDriver "libinput"
        # Match the MCHOSE's 1600 DPI against the Pebble's 1000 DPI.
        Option "TransformationMatrix" "1.6 0 0 0 1.6 0 0 0 1"
      ''
    ];
  };
  services.libinput.enable = true;

  services.physlock = {
    enable = true;
    allowAnyUser = true;
    muteKernelMessages = true;
  };

  programs.artcraft = {
    enable = true;
    apps = [
      "photocraft"
      "effectcraft"
    ];
  };

  services.flatpak.enable = true;
  services.gnome.gnome-keyring.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common = {
      default = "gtk";
      "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
    };
  };

  services.blueman.enable = true;

  programs.thunar.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  programs.dconf.enable = true;
}

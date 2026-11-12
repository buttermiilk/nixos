{ ... }:

{
  imports = [ ./power-limit.nix ];

  # Intel P-state powersave keeps CPU frequency scaling dynamic while gaming.
  # The performance shortcut selects TLP performance and restores firmware
  # package power limits through power-limit.nix.
  programs.gamemode = {
    enable = true;
    settings.general.desiredgov = "powersave";
  };

  services.thermald.enable = true;

  services.tlp.enable = true;
  services.tlp.settings = {
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
}

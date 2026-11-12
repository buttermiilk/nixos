{ pkgs, ... }:

{
  environment.variables.FREETYPE_PROPERTIES = "cff:no-stem-darkening=0 autofitter:no-stem-darkening=0";

  fonts = {
    packages = with pkgs; [
      adwaita-fonts
      nerd-fonts.fantasque-sans-mono
      fantasque-sans-mono
      nerd-fonts.iosevka
      googlesans-code
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
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

}

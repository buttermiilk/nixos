{ fetchurl, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "material-design-iconic-font-polybar";
  version = "unstable-2026-05-31";

  src = fetchurl {
    url = "https://raw.githubusercontent.com/adi1090x/polybar-themes/83eaa009b080946eff6fe62f1719d0dca90f26a4/fonts/material_design_iconic_font.ttf";
    hash = "sha256-GKRb4uy2bOIXw7vM8hn4vcBdx21hpuY2cxhu/Rx82ho=";
  };

  dontUnpack = true;

  installPhase = ''
    install -Dm444 "$src" "$out/share/fonts/truetype/material_design_iconic_font.ttf"
  '';
}

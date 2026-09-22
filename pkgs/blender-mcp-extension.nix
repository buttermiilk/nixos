{
  lib,
  stdenvNoCC,
  src,
}:

stdenvNoCC.mkDerivation {
  pname = "blender-mcp-extension";
  version = "1.0.0";

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/system"
    cp -r ${src}/addon/blender_mcp_addon "$out/system/mcp"

    runHook postInstall
  '';

  meta = {
    description = "Official Blender Lab MCP system extension";
    homepage = "https://www.blender.org/lab/mcp-server/";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.all;
  };
}

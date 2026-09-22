{
  blender,
  blenderMcpExtension,
  lib,
  makeWrapper,
  symlinkJoin,
}:

symlinkJoin {
  name = "blender-with-mcp-${blender.version}";
  paths = [ blender ];
  nativeBuildInputs = [ makeWrapper ];

  postBuild = ''
    wrapProgram "$out/bin/blender" \
      --set BLENDER_SYSTEM_EXTENSIONS "${blenderMcpExtension}" \
      --add-flags "--addons bl_ext.system.mcp"
  '';

  passthru = {
    inherit blenderMcpExtension;
    unwrapped = blender;
  };

  meta = blender.meta // {
    description = "${blender.meta.description} with the Blender Lab MCP extension";
    mainProgram = "blender";
  };
}

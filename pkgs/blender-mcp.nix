{
  lib,
  python3Packages,
  src,
}:

python3Packages.buildPythonApplication {
  pname = "blender-mcp";
  version = "1.0.0";

  src = "${src}/mcp";
  pyproject = true;

  build-system = [ python3Packages.setuptools ];

  dependencies =
    with python3Packages;
    [
      docutils
      mcp
      pyyaml
    ]
    ++ python3Packages.mcp.optional-dependencies.cli;

  pythonImportsCheck = [ "blmcp" ];

  meta = {
    description = "Official Blender Lab MCP server";
    homepage = "https://www.blender.org/lab/mcp-server/";
    license = lib.licenses.gpl3Plus;
    mainProgram = "blender-mcp";
    platforms = lib.platforms.all;
  };
}

{ pkgs }:

pkgs.mkShell {
  name = "docker-dev";
  buildInputs = with pkgs; [
    docker
    docker-compose
  ];
  shellHook = ''
    echo "Ay, Docker? Yomikawa took the Docker manual with her. Ask her if you missed something!"
    echo ""
    echo "Hey, you may need to run with `sudo` to use Docker unless you're in the docker group!"
  '';
}

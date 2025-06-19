{ pkgs }:

pkgs.mkShell {
  name = "py-dev";
  buildInputs = with pkgs; [
    python3
    python3Packages.pip
    python3Packages.virtualenv
  ];
  shellHook = ''
    echo "Python today? Yomikawa advises you to take a Python manual, you probably don't know a lot of Python things!"
  ''
}
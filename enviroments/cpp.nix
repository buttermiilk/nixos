{ pkgs }:

# all mkShell asks for the same basic things:
# - the name of the shell
# - the things you want the shell to have
# - the things you want the shell to run right after you get in
pkgs.mkShell {
  name = "cpp-dev";
  buildInputs = with pkgs; [
    gcc
    gdb
    cmake
    clang-tools
  ];
  shellHook = ''
    echo "C++, good ol' language. Yomikawa advises you to take a C++ manual, just because C++ is pretty painful to manage."
  '';
}

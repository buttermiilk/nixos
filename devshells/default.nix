{ pkgs }:

{
  cpp = pkgs.mkShell {
    packages = with pkgs; [
      cmake
      ninja
      gdb
      pkg-config
      jetbrains.clion
    ];
  };

  maintenance = pkgs.mkShellNoCC {
    packages = with pkgs; [
      nix-prefetch-git
      awscli2
      patchelf
      dpkg
      git
      python3
    ];
  };

  rust-gui =
    let
      runtimeLibs = with pkgs; [
        alsa-lib
        libGL
        libx11
        libxcb
        libxcursor
        libxi
        libxkbcommon
        libxrandr
        vulkan-loader
        wayland
      ];
    in
    pkgs.mkShell {
      packages = [ pkgs.pkg-config ];
      buildInputs = runtimeLibs;
      LD_LIBRARY_PATH = "/run/opengl-driver/lib:${pkgs.lib.makeLibraryPath runtimeLibs}";
    };
}

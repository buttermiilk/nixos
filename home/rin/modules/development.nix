{ pkgs, ... }:

{
  home.packages = with pkgs; [
    cargo
    rustc
    python3
    nodejs_24
    pnpm
    bun
    flyctl
    gh
    claude-code-cli
    poppler-utils
    python3Packages.pymupdf
    qpdf
    ghostscript
    cmake
    ninja
    gcc
    gdb
    pkg-config
    xdotool
    google-antigravity-cli
    nixd
    nixfmt
    rust-analyzer
    basedpyright
    ruff
    vtsls
    astro-language-server
    tailwindcss-language-server
    vscode-langservers-extracted
    bash-language-server
    shellcheck
    taplo
  ];
}

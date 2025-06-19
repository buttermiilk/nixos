{ pkgs }:

pkgs.mkShell {
  name = "ts-dev";
  buildInputs = with pkgs; [
    nodejs
    nodePackages.typescript
    nodePackages.typescript-language-server
  ];
  shellHook = ''
    echo "Usual stuff. Yomikawa took a book with her, you should be able to do TypeScript on your own!"
  ''
}

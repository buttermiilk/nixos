{ runCommand, src }:

runCommand "neuro-sama-cursor" { inherit src; } ''
  themeDir="$out/share/icons/Neuro-sama"
  mkdir -p "$themeDir"
  cp -a "$src"/. "$themeDir"
''

{
  pkgs,
  manifest,
  host,
}:

{
  sh1m3ji = host.config.system.build.toplevel;
  codex-config =
    pkgs.runCommand "codex-config-check"
      {
        nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.tomlkit ])) ];
      }
      ''
        python ${./codex-config.py} ${../home/rin/modules/codex/sync-config.py}
        touch "$out"
      '';
  dependency-updater =
    pkgs.runCommand "dependency-updater-check"
      {
        nativeBuildInputs = [ pkgs.python3 ];
      }
      ''
        python ${./dependency-updater.py} ${../dependencies/update.py}
        touch "$out"
      '';
  bootvine-publisher =
    pkgs.runCommand "bootvine-publisher-check" { nativeBuildInputs = [ pkgs.python3 ]; }
      ''
        python ${./bootvine-publisher.py} ${../dependencies/publish-bootvine.py}
        touch "$out"
      '';
  backup-manifest = import ./backup-manifest.nix {
    inherit pkgs manifest;
    inherit (pkgs) lib;
    backup = host.config.home-manager.users.rin.services.restic.backups.gdrive;
  };
  power-modes =
    pkgs.runCommand "power-modes-check"
      {
        nativeBuildInputs = [
          (pkgs.lib.getBin pkgs.bashNonInteractive)
          pkgs.coreutils
          pkgs.python3
          pkgs.util-linux
        ];
      }
      ''
        python ${./power-modes.py} \
          ${../hosts/sh1m3ji/power-limit.sh} \
          ${../home/rin/modules/desktop/eco-mode.sh}
        touch "$out"
      '';
}

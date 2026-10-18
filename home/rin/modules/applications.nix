{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  osuWinello = pkgs.writeShellApplication {
    name = "osu-winello";
    runtimeInputs = [
      pkgs.gamemode
      pkgs.procps
      pkgs.steam-run
      pkgs.tosu
    ];
    text = builtins.readFile ../dotfiles/scripts/osu-winello.sh;
  };

  osuLazer = pkgs.writeShellApplication {
    name = "osu-lazer";
    runtimeInputs = [
      pkgs.gamemode
      pkgs.osu-lazer-bin
      pkgs.procps
      pkgs.tosu
    ];
    text = builtins.readFile ../dotfiles/scripts/osu-lazer.sh;
  };

  osuLazerSettings = pkgs.writeShellApplication {
    name = "osu-lazer-settings";
    runtimeInputs = [ pkgs.gawk ];
    text = builtins.readFile ../dotfiles/scripts/osu-lazer-settings.sh;
  };

  osuLazerData = "${config.home.homeDirectory}/Documents/osu-lazer";

  osuIcon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/NelloKudo/osu-winello/2914ed7687e99d43dde7821c3fd04f3723725723/stuff/osu-wine.png";
    hash = "sha256-kn3mKfwpeTRScvxbH7jKbo+7zGDIozFkNVW8BmbayvQ=";
  };

  osuDesktop = pkgs.makeDesktopItem {
    name = "osu-stable";
    desktopName = "osu! stable";
    comment = "Rhythm is just a click away";
    exec = "osu-winello %U";
    icon = osuIcon;
    terminal = false;
    startupNotify = true;
    categories = [ "Game" ];
  };

  osuTourneyDesktop = pkgs.makeDesktopItem {
    name = "osu-tourney";
    desktopName = "osu! tourney";
    comment = "osu! stable tournament client";
    exec = "osu-winello --tourney";
    icon = osuIcon;
    terminal = false;
    startupNotify = true;
    categories = [ "Game" ];
  };

  # Rebuilt from Concord's own nix/package.nix with one change: a pinned hash
  # for its thorvg-sys git dependency. Without it, crane fetches that repo
  # with builtins.fetchGit at evaluation time -- full history plus the
  # thorvg and picolibc submodules, about 550 MB -- and root's eval cache
  # does not share the user's. With the hash, crane uses a shallow fetchgit
  # that only runs when the store path is missing.
  concord =
    let
      src = inputs.concord;
      rustPkgs = pkgs.extend (import src.inputs.rust-overlay);
      # Matches the toolchain pinned in Concord's flake.nix.
      craneLib =
        ((src.inputs.crane.mkLib rustPkgs).overrideToolchain rustPkgs.rust-bin.stable."1.90.0".default)
        .overrideScope
          (
            _final: prev: {
              vendorCargoDeps =
                args:
                prev.vendorCargoDeps (
                  args
                  // {
                    outputHashes = {
                      "git+https://github.com/chojs23/thorvg-rs.git?rev=2548bdbb1487cf473d2c1fe580891b57d973f0dc#2548bdbb1487cf473d2c1fe580891b57d973f0dc" =
                        "sha256-ECSuq6QQC8myTk2sTyQw0vHWrm7ab4psXVgsx/uAPbA=";
                    };
                  }
                );
            }
          );
      cargoToml = lib.importTOML "${src}/Cargo.toml";
    in
    rustPkgs.callPackage "${src}/nix/package.nix" {
      inherit craneLib;
      pname = cargoToml.package.name;
      inherit (cargoToml.package) version description homepage;
      src = craneLib.cleanCargoSource src;
    };
  spotifast = inputs.spotifast.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Concord draws images with Kitty's Unicode placeholders, which Zellij 0.45
  # rejects. A command given to kitty skips the login shell, so Zellij never
  # starts and Concord talks to Kitty directly. This entry is also what rofi's
  # drun menu lists.
  concordDesktop = pkgs.makeDesktopItem {
    name = "concord";
    desktopName = "Concord";
    comment = "Discord client in the terminal";
    exec = "kitty --class concord ${lib.getExe concord}";
    icon = "discord";
    terminal = false;
    categories = [
      "Network"
      "InstantMessaging"
    ];
  };
in
{
  programs.thunderbird = {
    enable = true;
    profiles.default = {
      isDefault = true;
      withExternalGnupg = true;
    };
  };

  home.packages = with pkgs; [
    # Terminal tools
    fastfetch
    chafa # Fastfetch's image logo renderer
    btop
    zip
    unzip
    ripgrep
    jq

    # Remote access and graphical applications
    remmina
    # Blender Lab's MCP extension is exposed as a read-only system extension.
    blender-with-mcp
    blender-mcp
    ghidra
    prismlauncher
    bongocat-osu
    taiko-editor
    vinegar

    # Company-mandated time tracker (X11 only; works under i3).
    monitask

    # osu! stable through osu-winello; the wrapper supplies the FHS runtime.
    steam-run
    zenity
    osuWinello
    osuDesktop
    osuTourneyDesktop

    # osu!lazer. The -bin AppImage is ppy's official build; only official
    # builds may submit scores or join multiplayer, so not the source package.
    # Updates come from nixpkgs (OSU_EXTERNAL_UPDATE_PROVIDER disables the
    # in-game updater). Launch it through osuLazer for tosu and gamemode.
    osu-lazer-bin
    osuLazer

    concord
    concordDesktop
    # Concord plays videos and voice-channel streams through mpv on PATH.
    # Screen sharing needs nothing extra here: Concord captures natively on
    # X11 and encodes with the host's VA-API driver (intel-media-driver).
    mpv

    spotifast
  ];

  # Same ID as the package's own entry, so this one replaces it (in rofi and
  # as a MIME handler) and launches through the tosu/gamemode wrapper.
  xdg.desktopEntries."osu!" = {
    name = "osu!lazer";
    comment = "Rhythm is just a *click* away";
    exec = "osu-lazer %u";
    icon = "osu";
    terminal = false;
    startupNotify = true;
    categories = [ "Game" ];
    mimeType = [
      "application/x-osu-beatmap-archive"
      "application/x-osu-skin-archive"
      "application/x-osu-beatmap"
      "application/x-osu-storyboard"
      "application/x-osu-replay"
      "x-scheme-handler/osu"
    ];
    settings = {
      StartupWMClass = "osu!";
      SingleMainWindow = "true";
    };
  };

  # Keep lazer's data (beatmaps, replays, skins, client.realm) in Documents so
  # the Restic backup covers it. Lazer only rewrites storage.ini when the
  # folder is changed in-game; do that here instead. On the first launch
  # against the empty folder it asks once: pick "Start fresh".
  # Lazer still replaces the link with an identical regular file now and then,
  # so take it back without leaving an .hm-bak behind.
  xdg.dataFile."osu/storage.ini" = {
    text = ''
      FullPath = ${osuLazerData}
    '';
    force = true;
  };

  # Lazer rewrites framework.ini and game.ini in full on exit (game.ini also
  # holds the login token), so they cannot be store links. Instead, every
  # activation sets just these keys and keeps the rest. Settings changed in
  # game while lazer is open come back on its exit; quit it before switching.
  home.activation.osuLazerSettings =
    let
      setKeys =
        file: settings:
        lib.escapeShellArgs (
          [
            (lib.getExe osuLazerSettings)
            "${osuLazerData}/${file}"
          ]
          ++ lib.mapAttrsToList (key: value: "${key}=${toString value}") settings
        );
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${
        setKeys "framework.ini" {
          # VSync only delays what is drawn; with the multithreaded execution
          # mode, input and hit judgement run on their own threads.
          FrameSync = "VSync";
          WindowMode = "Windowed";
          ConfineMouseMode = "Never";
          # Mixer balance; the master volume is left to the in-game wheel.
          VolumeMusic = "0.3";
          VolumeEffect = "0.16";
        }
      }
      run ${
        setKeys "game.ini" {
          Ruleset = "taiko";
          AudioOffset = "8.0";
          UIScale = "1.2";
          UIHoldActivationDelay = "100.0";
          ShowFpsDisplay = "True";
          GameplayLeaderboard = "False";
          BeatmapDetailTab = "Global";
          EditorShowSpeedChanges = "True";
          UserOnlineStatus = "Offline";
        }
      }
    '';

  # Bongo Cat only reads config.json and fills omitted keys with its defaults.
  # Keys are Windows virtual-key codes, even on Linux.
  xdg.configFile."bongocat-osu/config.json".text = builtins.toJSON {
    mode = 2; # osu!taiko
    # Chroma-key green so the background can be keyed out.
    decoration.rgb = [
      0
      255
      0
    ];
    taiko = {
      leftCentre = [ 81 ]; # Q
      rightCentre = [ 87 ]; # W
      rightRim = [ 221 ]; # ]
      leftRim = [ 220 ]; # \
    };
  };

  # tosu rewrites this file on every start; against the read-only link that
  # only logs "Configuration migration failed" and the values still apply.
  # Dashboard setting changes will not persist; change them here.
  xdg.configFile."tosu/tosu.env".text = lib.generators.toKeyValue { } {
    DEBUG_LOG = false;
    # The binary lives in the Nix store; bump pkgs/tosu.nix instead.
    ENABLE_AUTOUPDATE = false;
    OPEN_DASHBOARD_ON_STARTUP = false;
    SHOW_MP_COMMANDS = false;
    CALCULATE_PP = true;
    READ_MANIA_SCROLL_SPEED = true;
    ENABLE_KEY_OVERLAY = true;
    ENABLE_INGAME_OVERLAY = false;
    POLL_RATE = 150;
    PRECISE_DATA_POLL_RATE = 10;
    INGAME_OVERLAY_KEYBIND = "Control + Shift + Space";
    INGAME_OVERLAY_MAX_FPS = 60;
    SERVER_IP = "127.0.0.1";
    SERVER_PORT = 24050;
    ALLOWED_IPS = "127.0.0.1,localhost,absolute";
    STATIC_FOLDER_PATH = "${config.xdg.dataHome}/tosu/static";
  };
}

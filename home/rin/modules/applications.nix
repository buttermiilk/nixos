{
  config,
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

  concord = pkgs.concord;

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

    fastfetch
    chafa
    btop
    zip
    unzip
    ripgrep
    jq

    remmina

    blender-with-mcp
    blender-mcp
    ghidra
    prismlauncher
    bongocat-osu
    taiko-editor
    vinegar

    monitask

    steam-run
    zenity
    osuWinello
    osuDesktop
    osuTourneyDesktop

    osu-lazer-bin
    osuLazer

    concord
    concordDesktop

    mpv
  ];

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

  xdg.dataFile."osu/storage.ini" = {
    text = ''
      FullPath = ${osuLazerData}
    '';
    force = true;
  };

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

          FrameSync = "VSync";
          WindowMode = "Windowed";
          ConfineMouseMode = "Never";

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

  xdg.configFile."bongocat-osu/config.json".text = builtins.toJSON {
    mode = 2;

    decoration.rgb = [
      0
      255
      0
    ];
    taiko = {
      leftCentre = [ 81 ];
      rightCentre = [ 87 ];
      rightRim = [ 221 ];
      leftRim = [ 220 ];
    };
  };

  xdg.configFile."tosu/tosu.env".text = lib.generators.toKeyValue { } {
    DEBUG_LOG = false;

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

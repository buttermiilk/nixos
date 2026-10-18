{
  config,
  lib,
  pkgs,
  ...
}:

let
  obsDir = "${config.xdg.configHome}/obs-studio";
  profileName = "sh1m3ji";

  # OBS rewrites its INI files on exit, so they cannot be read-only store
  # links. The profile below is copied over on every Home Manager activation:
  # change settings here, not in the Settings dialog. The stream key
  # (service.json) and scene collections stay mutable and are only backed up.
  basicIni = lib.generators.toINI { } {
    General.Name = profileName;

    Output = {
      Mode = "Simple";
      FilenameFormatting = "%CCYY-%MM-%DD %hh-%mm-%ss";
      Reconnect = true;
      RetryDelay = 2;
      MaxRetries = 25;
      # Lower the bitrate instead of dropping frames when the uplink stalls.
      DynamicBitrate = true;
    };

    # Streaming with x264 ultrafast at 648p48 (tuned in the Settings dialog
    # on 2026-10-10). On real streams the QuickSync 720p60 setup below
    # skipped 15% of frames to encoder lag and lagged 8% in rendering, as
    # osu! keeps the Iris Xe busy; this one lagged 2%.
    SimpleOutput = {
      StreamEncoder = "x264";
      Preset = "ultrafast";
      VBitrate = 4200;
      StreamAudioEncoder = "aac";
      ABitrate = 128;
      RecEncoder = "x264";
      RecAudioEncoder = "aac";
      RecQuality = "Stream";
      RecFormat2 = "hybrid_mp4";
      FilePath = "${config.home.homeDirectory}/Videos";
    };

    # Unused while Output.Mode is "Simple"; kept for switching back.
    AdvOut = {
      Encoder = "obs_qsv11_v2";
      ApplyServiceSettings = true;
      TrackIndex = 1;
      AudioEncoder = "ffmpeg_aac";
      Track1Bitrate = 160;

      # Stream at 720p60; the canvas and recordings stay 1080p60.
      UseRescale = true;
      RescaleRes = "1280x720";
      RescaleFilter = 2; # bicubic

      RecType = "Standard";
      RecEncoder = "obs_qsv11_v2";
      RecAudioEncoder = "ffmpeg_aac";
      RecFilePath = "${config.home.homeDirectory}/Videos";
      RecFormat2 = "hybrid_mp4";
      RecTracks = 1;
      RecUseRescale = false;
    };

    Video = {
      BaseCX = 1920;
      BaseCY = 1080;
      OutputCX = 1152;
      OutputCY = 648;
      FPSType = 0;
      FPSCommon = 48;
      # Bilinear is the cheapest GPU downscale; at 648p it looks the same.
      ScaleType = "bilinear";
      ColorFormat = "NV12";
      ColorSpace = "sRGB";
      ColorRange = "Partial";
    };

    # PipeWire runs at 48 kHz; matching it avoids resampling every source.
    Audio = {
      SampleRate = 48000;
      ChannelSetup = "Stereo";
    };
  };

  # QuickSync encoder settings; only read in the Advanced output mode.
  streamEncoder = builtins.toJSON {
    rate_control = "CBR";
    bitrate = 4500;
    keyint_sec = 2;
    profile = "high";
    target_usage = "TU4";
  };

  # Edit source: constant quality, short GOP for smooth scrubbing in an editor.
  recordEncoder = builtins.toJSON {
    rate_control = "CQP";
    cqp = 20;
    keyint_sec = 1;
    profile = "high";
    target_usage = "TU4";
  };

  # Seeded once: OBS keeps window layout and other UI state in this file.
  userIni = lib.generators.toINI { } {
    General.FirstRun = true;
    Basic = {
      Profile = profileName;
      ProfileDir = profileName;
    };
  };
in
{
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-pipewire-audio-capture
      obs-plugin-countdown
      obs-gstreamer
      obs-vkcapture
    ];
  };

  home.activation.obsProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    profile_dir="${obsDir}/basic/profiles/${profileName}"
    run mkdir -p "$profile_dir"
    run install -m644 ${pkgs.writeText "obs-basic.ini" basicIni} "$profile_dir/basic.ini"
    run install -m644 ${pkgs.writeText "obs-streamEncoder.json" streamEncoder} "$profile_dir/streamEncoder.json"
    run install -m644 ${pkgs.writeText "obs-recordEncoder.json" recordEncoder} "$profile_dir/recordEncoder.json"
    if [ ! -e "${obsDir}/user.ini" ]; then
      run install -m644 ${pkgs.writeText "obs-user.ini" userIni} "${obsDir}/user.ini"
    fi
  '';
}

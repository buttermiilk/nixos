{
  config,
  lib,
  pkgs,
  ...
}:

let
  obsDir = "${config.xdg.configHome}/obs-studio";
  profileName = "sh1m3ji";

  basicIni = lib.generators.toINI { } {
    General.Name = profileName;

    Output = {
      Mode = "Simple";
      FilenameFormatting = "%CCYY-%MM-%DD %hh-%mm-%ss";
      Reconnect = true;
      RetryDelay = 2;
      MaxRetries = 25;

      DynamicBitrate = true;
    };

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

    AdvOut = {
      Encoder = "obs_qsv11_v2";
      ApplyServiceSettings = true;
      TrackIndex = 1;
      AudioEncoder = "ffmpeg_aac";
      Track1Bitrate = 160;

      UseRescale = true;
      RescaleRes = "1280x720";
      RescaleFilter = 2;

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

      ScaleType = "bilinear";
      ColorFormat = "NV12";
      ColorSpace = "sRGB";
      ColorRange = "Partial";
    };

    Audio = {
      SampleRate = 48000;
      ChannelSetup = "Stereo";
    };
  };

  streamEncoder = builtins.toJSON {
    rate_control = "CBR";
    bitrate = 4500;
    keyint_sec = 2;
    profile = "high";
    target_usage = "TU4";
  };

  recordEncoder = builtins.toJSON {
    rate_control = "CQP";
    cqp = 20;
    keyint_sec = 1;
    profile = "high";
    target_usage = "TU4";
  };

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

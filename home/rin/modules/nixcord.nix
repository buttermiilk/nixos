{
  inputs,
  pkgs,
  ...
}:

let
  # Nixcord still applies Vencord and the selected Chromium flags around this
  # base package. Removing TTS here keeps Discord from pulling in and starting
  # speech-dispatcher without affecting voice calls.
  discordWithoutTts = pkgs.discord.override { withTTS = false; };
  leanDiscord = pkgs.callPackage "${inputs.nixcord}/pkgs/discord" {
    discord = discordWithoutTts;
  };
in
{
  imports = [ inputs.nixcord.homeModules.nixcord ];

  programs.nixcord = {
    enable = true;
    discord = {
      enable = true;
      package = leanDiscord;
      vencord.enable = true;
      openASAR.enable = false;

      # Drop Chromium background services that Discord's chat/voice/video paths
      # do not require. GPU acceleration and WebRTC remain enabled.
      commandLineArgs = [
        "--disable-background-networking"
        "--disable-breakpad"
        "--disable-component-update"
        "--disable-domain-reliability"
        "--disable-sync"
        "--no-default-browser-check"
        "--no-first-run"
      ];
    };

    config = {
      notifyAboutUpdates = false;
      autoUpdate = false;
      autoUpdateNotification = false;

      plugins = {
        # Vencord's required NoTrack plugin already disables Discord analytics,
        # metrics, and Sentry. Keep only small plugins that support the three
        # required workflows or actively reduce background/UI noise.
        clearUrls.enable = true;
        consoleJanitor = {
          enable = true;
          disableLoggers = true;
        };
        crashHandler.enable = true;
        disableCallIdle.enable = true;
        noPendingCount = {
          enable = true;
          hideFriendRequestsCount = false;
          hideMessageRequestsCount = false;
          hidePremiumOffersCount = true;
        };
        noTypingAnimation.enable = true;
        onePingPerDm = {
          enable = true;
          allowMentions = true;
        };
        streamerModeOnStream.enable = true;
        webScreenShareFixes.enable = true;
      };
    };
  };
}

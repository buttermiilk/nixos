{
  inputs,
  pkgs,
  ...
}:

let

  leanDiscord = pkgs.callPackage "${inputs.nixcord}/pkgs/discord" {
    withTTS = false;
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

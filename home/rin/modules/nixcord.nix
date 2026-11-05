{
  inputs,
  pkgs,
  ...
}:

let

  leanDiscord =
    (pkgs.callPackage "${inputs.nixcord}/pkgs/discord" {
      withTTS = false;
    }).overrideAttrs
      (old: {
        # Both the host's renderer flags and desktop core request OpenH264
        # 2.5.1, but the asset updater keeps 2.7.0. Patch both archives;
        # equal-length replacements preserve ASAR offsets (nixpkgs #581099).
        postInstall = (old.postInstall or "") + ''
          for archive in \
            "$out/opt/Discord/resources/_app.asar" \
            "$out/opt/Discord/modules/discord_desktop_core/core.asar"; do
            grep -qF 'libopenh264-2.5.1-linux64.7.so' "$archive"
            sed -i 's/libopenh264-2\.5\.1-linux64\.7\.so/libopenh264-2.7.0-linux64.8.so/g' "$archive"
          done
        '';
      });
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

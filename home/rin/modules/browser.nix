{ ... }:

let
  zenExtensionSettings =
    builtins.mapAttrs
      (_: addonSlug: {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/${addonSlug}/latest.xpi";
        installation_mode = "force_installed";
      })
      {
        "firefox@tampermonkey.net" = "tampermonkey";
        "@windscribeff" = "windscribe";
        "addon@darkreader.org" = "darkreader";
        "sponsorBlocker@ajay.app" = "sponsorblock";
        "authenticator@mymindstorm" = "auth-helper";
        "redirector@einaregilsson.com" = "redirector";
        "deArrow@ajay.app" = "dearrow";
        "uBlock0@raymondhill.net" = "ublock-origin";
      };
in
{
  programs.zen-browser = {
    enable = true;

    policies = {
      DisableAppUpdate = true;
      DisableTelemetry = true;
      DontCheckDefaultBrowser = true;
      ExtensionSettings = zenExtensionSettings;
    };

    profiles.default = {
      pins = {
        "YouTube" = {
          id = "681c5e16-722e-4142-aecb-95b48716c139";
          url = "https://www.youtube.com/";
          position = 100;
          isEssential = true;
        };
        "GitHub" = {
          id = "fa3674cd-65af-4ead-9115-7fc950ae2e08";
          url = "https://github.com/";
          position = 200;
          isEssential = true;
        };
        "Google Sheets" = {
          id = "ace0b7fb-4ebd-4a13-9f30-5022cd9268b9";
          url = "https://docs.google.com/spreadsheets/u/0/";
          position = 300;
          isEssential = true;
        };
        "Google Drive" = {
          id = "2359d2d0-166f-459b-a83b-d6708ea1122a";
          url = "https://drive.google.com/drive/my-drive";
          position = 400;
          isEssential = true;
        };
        "osu!" = {
          id = "09930d4d-6f74-470e-bcbb-7a85961e3a38";
          url = "https://osu.ppy.sh/";
          position = 500;
          isEssential = true;
        };
        "Spotify" = {
          id = "af602af2-c037-463d-87db-8b5fee8b1397";
          url = "https://open.spotify.com/";
          position = 600;
          isEssential = true;
        };
      };

      spaces."Chill" = {
        id = "caa5b275-7bc6-48b4-aeb5-b689ed626e9b";
        position = 1000;

        theme = {
          type = "gradient";
          colors = [
            {
              red = 219;
              green = 148;
              blue = 87;
              custom = false;
              algorithm = "analogous";
              primary = true;
              lightness = 60;
              position = {
                x = 241;
                y = 212;
              };
              type = "explicit-lightness";
            }
            {
              red = 178;
              green = 219;
              blue = 87;
              custom = false;
              algorithm = "analogous";
              primary = false;
              lightness = 60;
              position = {
                x = 194;
                y = 248;
              };
              type = "explicit-lightness";
            }
            {
              red = 218;
              green = 88;
              blue = 138;
              custom = false;
              algorithm = "analogous";
              primary = false;
              lightness = 60;
              position = {
                x = 244;
                y = 153;
              };
              type = "explicit-lightness";
            }
          ];
          opacity = 0.5;
          texture = 0.875;
        };
      };
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = [ "zen-beta.desktop" ];
      "message/rfc822" = [ "thunderbird.desktop" ];
      "x-scheme-handler/http" = [ "zen-beta.desktop" ];
      "x-scheme-handler/https" = [ "zen-beta.desktop" ];
      "x-scheme-handler/mailto" = [ "thunderbird.desktop" ];
    };
  };
}

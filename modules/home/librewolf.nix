{ pkgs, ... }:
{
  programs.librewolf = {
    enable = true;
    package = pkgs.librewolf.override {
      nativeMessagingHosts = with pkgs; [
        ff2mpv-rust
      ];
    };

    policies = {
      DisableProfileImport = true;
      DisableProfileRefresh = true;
      ExtensionUpdate = false;
      SanitizeOnShutdown = {
        Cache = true;
        Cookies = true;
        Downloads = true;
        FormData = true;
        History = true;
        Sessions = true;
        SiteSettings = true;
        OfflineApps = true;
        Locked = true;
      };
      ShowHomeButton = true;
    };

    profiles.ritiek = {
      id = 0;
      isDefault = true;
      name = "Ritiek Malhotra";

      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
        # https://nur.nix-community.org/repos/rycee/

        # ublock-origin
        canvasblocker
        # Consensus is that privacy-badger makes more prone to fingerprinting.
        # privacy-badger
        unpaywall
        link-cleaner

        bitwarden
        darkreader
        kagi-search
        multi-account-containers

        movie-web
        musescore-downloader

        enhanced-github
        github-file-icons
        lovely-forks

        # print-friendly-pdf
        print-to-pdf-document

        cookies-txt
        # export-cookies-txt
        istilldontcareaboutcookies

        sponsorblock
        return-youtube-dislikes
        youtube-shorts-block
        youtube-nonstop

        # vimium-c
        # tridactyl

        web-archives
        to-deepl
        # languagetool
        ff2mpv

        tubearchivist-companion

        (buildFirefoxXpiAddon {
          pname = "adnauseam";
          version = "3.24.6";
          addonId = "adnauseam@rednoise.org";
          url = "https://addons.mozilla.org/firefox/downloads/file/4440960/adnauseam-3.24.6.xpi";
          sha256 = "sha256-PSpEBz2A68R4UJxDKiDYTZPMc8yfZQDgOKbumHma6qY=";
          meta = {};
        })

        (buildFirefoxXpiAddon {
          pname = "shiori";
          version = "0.8.5";
          addonId = "{c6e8bd66-ebb4-4b63-bd29-5ef59c795903}";
          url = "https://addons.mozilla.org/firefox/downloads/file/3911467/shiori_ext-0.8.5.xpi";
          sha256 = "sha256-ajRGlDfzKpk2b9JiWeLKdAH3Ymb7M1b4M95g0Tmaaks=";
          # set `devtools.jsonview.enabled: false`
          meta = {};
        })

        (buildFirefoxXpiAddon {
          pname = "send-to-kindle";
          version = "1.3";
          addonId = "reabble.com@gmail.com";
          url = "https://addons.mozilla.org/firefox/downloads/file/3577406/push_to_kindle_2-1.3.xpi";
          sha256 = "sha256-44CHDKw/QCcXdkvUEwqmmQjjRHgTQsY6Kpy5wMUV10E=";
          meta = {};
        })

        (buildFirefoxXpiAddon {
          pname = "linkedin-feed-blocker";
          version = "0.0.3";
          addonId = "{78400a4a-b6fe-4f7d-a831-734229802784}";
          url = "https://addons.mozilla.org/firefox/downloads/file/3795847/linkedin_feed_blocker-0.0.3.xpi";
          sha256 = "sha256-iCZ48z4odTV4/nBlAK6dh8qX5CGVRYaqsTU1z3VKRgw=";
          meta = {};
        })
      ];

      settings = {
        "browser.toolbars.bookmarks.visibility" = "never";
        "browser.quitShortcut.disabled" = true;
        "extensions.autoDisableScopes" = 0;
        "font.name.monospace.x-western" = "FantasqueSansM Nerd Font Mono";
        "font.size.monospace.x-western" = 13;
        "font.minimum-size.x-western" = 14;
        "privacy.resistFingerprinting.letterboxing" = true;
      };

      search = {
        force = true;
        default = "google";
        order = [
          "ddg"
          "Kagi"
          "google"
        ];
        engines = {
          "bing".metaData.hidden = true;
          "google".metaData.alias = "@g"; # builtin engines only support specifying one additional alias
          "Nix Packages" = {
            urls = [{
              template = "https://search.nixos.org/packages";
              params = [
                { name = "type"; value = "packages"; }
                { name = "query"; value = "{searchTerms}"; }
              ];
            }];
            icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [
              "@np"
              "@packages"
            ];
          };
          "NixOS Options" = {
            urls = [{
              template = "https://search.nixos.org/options";
              params = [
                { name = "type"; value = "packages"; }
                { name = "query"; value = "{searchTerms}"; }
              ];
            }];
            icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [
              "@no"
              "@options"
              ];
          };
          "NixOS Wiki" = {
            urls = [{ template = "https://nixos.wiki/index.php?search={searchTerms}"; }];
            icon = "https://nixos.wiki/favicon.png";
            updateInterval = 24 * 60 * 60 * 1000; # every day
            definedAliases = [
              "@nw"
              "@wiki"
            ];
          };
        };
      };
    };
  };
}

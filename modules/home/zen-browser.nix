{ config, inputs, pkgs, ... }:
{
  imports = [
    inputs.zen-browser.homeModules.beta
  ];

  programs.zen-browser = {
    enable = true;
    nativeMessagingHosts = with pkgs; [
      ff2mpv-rust
    ];
    policies = {
      AppAutoUpdate = false; # Disable automatic application update
      BackgroundAppUpdate = false; # Disable automatic application update in the background, when the application is not running.
      DisableBuiltinPDFViewer = true; # Considered a security liability
      DisableFirefoxStudies = true;
      DisableFirefoxAccounts = true; # Disable Firefox Sync
      DisableFirefoxScreenshots = true; # No screenshots?
      DisableForgetButton = true; # Thing that can wipe history for X time, handled differently
      DisableMasterPasswordCreation = true; # To be determined how to handle master password
      DisableProfileImport = true; # Purity enforcement: Only allow nix-defined profiles
      DisableProfileRefresh = true; # Disable the Refresh Firefox button on about:support and support.mozilla.org
      DisableSetDesktopBackground = true; # Remove the “Set As Desktop Background…” menuitem when right clicking on an image, because Nix is the only thing that can manage the backgroud
      DisplayMenuBar = "default-off";
      DisablePocket = true;
      DisableTelemetry = true;
      DisableFormHistory = true;
      DisablePasswordReveal = true;
      DontCheckDefaultBrowser = true; # Stop being attention whore
      HardwareAcceleration = true; # Disabled as it's exposes points for fingerprinting
      OfferToSaveLogins = false; # Managed by KeepAss instead
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
        EmailTracking = true;
        # Exceptions = ["https://example.com"]
      };
      EncryptedMediaExtensions = {
        Enabled = true;
        Locked = true;
      };
      ExtensionUpdate = false;
      ExtensionSettings = {
        # NOTE: Enabling this seems to not even install the extensions mentioned here later.
        # "*" = {
        #   installation_mode = "blocked";
        #   blocked_install_message = "This breaks NixOS' purity!";
        # };
      };

      FirefoxHome = {
        Search = true;
        TopSites = true;
        SponsoredTopSites = false;
        Highlights = true;
        Pocket = false;
        SponsoredPocket = false;
        Snippets = false;
        Locked = true;
      };
      FirefoxSuggest = {
        WebSuggestions = false;
        SponsoredSuggestions = false;
        ImproveSuggest = false;
        Locked = true;
      };

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

      PasswordManagerEnabled = false;

      SearchEngines = {
        PreventInstalls = true;
        Remove = [
          "bing"
        ];
      };

      SearchSuggestEnabled = false;
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
        karakeep

        (buildFirefoxXpiAddon {
          pname = "adnauseam";
          version = "3.24.6";
          addonId = "adnauseam@rednoise.org";
          url = "https://addons.mozilla.org/firefox/downloads/file/4440960/adnauseam-3.24.6.xpi";
          sha256 = "sha256-PSpEBz2A68R4UJxDKiDYTZPMc8yfZQDgOKbumHma6qY=";
          meta = {};
        })

        # (buildFirefoxXpiAddon {
        #   pname = "shiori";
        #   version = "0.8.5";
        #   addonId = "{c6e8bd66-ebb4-4b63-bd29-5ef59c795903}";
        #   url = "https://addons.mozilla.org/firefox/downloads/file/3911467/shiori_ext-0.8.5.xpi";
        #   sha256 = "sha256-ajRGlDfzKpk2b9JiWeLKdAH3Ymb7M1b4M95g0Tmaaks=";
        #   # set `devtools.jsonview.enabled: false`
        #   meta = {};
        # })

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
        "identity.fxaccounts.enabled" = false;
        "distribution.searchplugins.defaultLocale" = "en-GB";
        "general.useragent.locale" = "en-GB";
        # Performance settings
        "gfx.webrender.all" = true; # Force enable GPU acceleration
        "media.ffmpeg.vaapi.enabled" = true;
        "widget.dmabuf.force-enabled" = true; # Required in recent Firefoxes
        "toolkit.telemetry.enabled" = false;
        "geo.provider.network.url" = "https://location.services.mozilla.com/v1/geolocate?key=%MOZILLA_API_KEY%";
        "media.peerconnection.ice.default_address_only" = true;
        "network.auth.subresource-http-auth-allow" = 1;
        # Trusted DNS (TRR)
        "network.trr.mode" = 2;
        "network.trr.uri" = "https://mozilla.cloudflare-dns.com/dns-query";

        # ECH - prevent TLS connections leaking request hostname
        "network.dns.echconfig.enabled" = true;
        "network.dns.http3_echconfig.enabled" = true;

        # Crash reports
        "breakpad.reportURL" = "";
        "browser.tabs.crashReporting.sendReport" = false;

        # Auto-decline cookies
        "cookiebanners.service.mode" = 2;
        "cookiebanners.service.mode.privateBrowsing" = 2;

        "reader.parse-on-load.force-enabled" = true;

        "app.shield.optoutstudies.enabled" = false;
        "app.update.auto" = false;

        "datareporting.policy.dataSubmissionEnable" = false;
        "datareporting.policy.dataSubmissionPolicyAcceptedVersion" = 2;

        # "dom.security.https_only_mode" = true;
        # "dom.security.https_only_mode_ever_enabled" = true;

        # Disable autoplay
        "media.autoplay.default" = 5;

        # Prefer dark theme
        # "layout.css.prefers-color-scheme.content-override" = 0; # 0: Dark, 1: Light, 2: Auto

        "extensions.autoDisableScopes" = 0;
        "extensions.getAddons.showPane" = false;
        "extensions.htmlaboutaddons.recommendations.enabled" = false;
        "extensions.pocket.enabled" = false;

        "privacy.clearOnShutdown.history" = false;
        "privacy.clearOnShutdown.downloads" = false;
        "privacy.firstparty.isolate" = true;
        "privacy.resistFingerprinting" = true;
        "privacy.resistFingerprinting.letterboxing" = true;
        "privacy.resistFingerprinting.pbmode" = true;
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.pbmode.enabled" = true;
        "privacy.trackingprotection.emailtracking.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "privacy.trackingprotection.cryptomining.enabled" = true;
        "privacy.trackingprotection.fingerprinting.enabled" = true;
        "privacy.webrtc.legacyGlobalIndicator" = true;
        "privacy.query_stripping.enabled" = true;
        "privacy.query_stripping.enabled.pbmode" = true;

        "browser.bookmarks.restore_default_bookmarks" = false;
        "browser.contentblocking.category" = "strict";
        "browser.ctrlTab.recentlyUsedOrder" = false;
        "browser.discovery.enabled" = false;
        "browser.safebrowsing.downloads.enabled" = false;
        "browser.search.defaultenginename" = "Kagi";
        "browser.search.order.1" = "Kagi";
        "browser.sessionstore.resume_from_crash" = true;
        "browser.shell.checkDefaultBrowser" = false;
        "browser.ssb.enabled" = true;
        "browser.aboutConfig.showWarning" = false;
        "browser.laterrun.enabled" = false;
        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" = false;
        "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" = false;
        # "browser.newtabpage.activity-stream.default.sites" = "";
        "browser.newtabpage.activity-stream.discoverystream.recentSaves.enabled" = false;
        "browser.newtabpage.activity-stream.discoverystream.spocTopsitesPlacement.enabled" = false;
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.newtabpage.activity-stream.feeds.telemetry" = false;
        "browser.newtabpage.activity-stream.feeds.snippets" = false;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
        "browser.newtabpage.activity-stream.feeds.discoverystreamfeed" = false;
        "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.havePinned" = "";
        "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.searchEngines" = "";
        "browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
        "browser.newtabpage.activity-stream.showRecentSaves" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;

        # Do not  topsites in homepage
        "browser.newtabpage.activity-stream.feeds.system.topsites" = false;
        # "browser.newtabpage.activity-stream.sectionOrder" = "";

        "browser.newtabpage.pinned" = [
          {
            title = "NixOS";
            url = "https://nixos.org";
          }
        ];
        # "browser.newtabpage.activity-stream.topSitesRows" = false;
        # "browser.newtabpage.pinned" = false;

        "browser.newtabpage.activity-stream.feeds.sections" = false;
        "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts" = false;
        "browser.newtabpage.activity-stream.feeds.section.highlights" = false;
        "browser.newtabpage.activity-stream.section.highlights.includeBookmarks" = false;
        "browser.newtabpage.activity-stream.section.highlights.includeDownloads" = false;
        "browser.newtabpage.activity-stream.section.highlights.includeVisited" = false;
        "browser.newtabpage.activity-stream.telemetry" = false;
        # "webgl.disabled" = false;
        "browser.protections_panel.infoMessage.seen" = true;
        "browser.quitShortcut.disabled" = true;
        "browser.taskbar.lists.enabled" = false;
        "browser.taskbar.lists.frequent.enabled" = false;
        "browser.taskbar.lists.recent.enabled" = false;
        "browser.taskbar.lists.tasks.enabled" = false;
        "browser.toolbars.bookmarks.visibility" = "never";
        "browser.urlbar.placeholderName" = "DuckDuckGo";
        "browser.urlbar.suggest.openpage" = false;
        # "browser.startup.homepage" = "https://lesswrong.com";
        # "browser.startup.homepage" = "about:blank";
        "browser.startup.homepage" = "about:home";
        "browser.startup.page" = 3;
        "browser.search.region" = "GB"; # This is on purpose
        "browser.search.isUS" = false;
        "browser.bookmarks.showMobileBookmarks" = true;

        "font.name.monospace.x-western" = "FantasqueSansM Nerd Font Mono";
        "font.size.monospace.x-western" = 13;
        "font.minimum-size.x-western" = 14;
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

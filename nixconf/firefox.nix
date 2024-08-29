{ pkgs, ... }:
{
  # TODO: Librewolf's home manager module is missing options that
  # are available in firefox's module. So using firefox for now.
  # Maybe this PR addresses it:
  # https://github.com/nix-community/home-manager/pull/5684
  #
  # home.packages = with pkgs; [
  #   stable.librewolf
  # ];
  # programs.librewolf = {
  #   enable = true;
  #   # package = pkgs.stable.librewolf;
  #   settings = {
  #     # "webgl.disabled" = false;
  #     "privacy.resistFingerprinting" = true;
  #     "privacy.resistFingerprinting.letterboxing" = true;
  #     "browser.safebrowsing.downloads.enabled" = false;
  #     "identity.fxaccounts.enabled" = false;
  #     "privacy.clearOnShutdown.history" = false;
  #     "privacy.clearOnShutdown.downloads" = false;
  #     "browser.sessionstore.resume_from_crash" = true;
  #   };
  #   # profiles = {};
  # };

  programs.firefox = {
    enable = true;
    package = pkgs.firefox-beta;
    profiles.ritiek = {
      id = 0;
      isDefault = true;
      name = "Ritiek Malhotra";
      extensions = with pkgs.nur.repos.rycee.firefox-addons; [
        # dracula-dark-colorscheme
        ublock-origin
        canvasblocker

        bitwarden
        darkreader
        kagi-search
        multi-account-containers

        movie-web
        musescore-downloader

        enhanced-github
        github-file-icons
        lovely-forks

        print-friendly-pdf
        print-to-pdf-document

        cookies-txt
        # export-cookies-txt
        istilldontcareaboutcookies

        return-youtube-dislikes
        youtube-shorts-block
        youtube-nonstop

        # vimium-c
        tridactyl

        tubearchivist-companion

        (buildFirefoxXpiAddon {
          pname = "shiori";
          version = "0.8.5";
          addonId = "{c6e8bd66-ebb4-4b63-bd29-5ef59c795903}";
          url = "https://addons.mozilla.org/firefox/downloads/file/3911467/shiori_ext-0.8.5.xpi";
          sha256 = "sha256-ajRGlDfzKpk2b9JiWeLKdAH3Ymb7M1b4M95g0Tmaaks=";
          # set `devtools.jsonview.enabled: false`
          meta = {};
        })
      ];
      settings = {
        # "webgl.disabled" = false;
        "privacy.resistFingerprinting" = true;
        # "privacy.resistFingerprinting.letterboxing" = true;
        "privacy.resistFingerprinting.letterboxing" = false;
        "browser.safebrowsing.downloads.enabled" = false;
        "identity.fxaccounts.enabled" = false;
        "privacy.clearOnShutdown.history" = false;
        "privacy.clearOnShutdown.downloads" = false;
        "browser.sessionstore.resume_from_crash" = true;

        "extensions.autoDisableScopes" = 0;
        "browser.startup.homepage" = "https://nixos.org";
        "browser.search.region" = "GB";
        "browser.search.isUS" = false;
        "distribution.searchplugins.defaultLocale" = "en-GB";
        "general.useragent.locale" = "en-GB";
        "browser.bookmarks.showMobileBookmarks" = true;
        "browser.newtabpage.pinned" = [{
          title = "NixOS";
          url = "https://nixos.org";
        }];
      };
    };
  };
}

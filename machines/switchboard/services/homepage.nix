# Native homepage-dashboard, replacing pilab's dockerized homepage
# container with nixpkgs' native NixOS module.
#
# Dashboard content is a full copy of pilab's dashboard (services.yaml,
# settings.yaml) per user request, plus new Pi-hole + Gatus cards for the
# services migrated onto switchboard itself. Homepage loses Docker-label
# auto-discovery (no OCI containers exist here), so Pi-hole/Gatus are
# declared as static entries instead.
{ config, ... }:
{
  # The OpenWeatherMap API key must not live in the Nix store: this repo is
  # public, and everything under settings is rendered verbatim into a
  # world-readable settings.json. Homepage substitutes {{HOMEPAGE_VAR_*}}
  # placeholders from its process environment at runtime instead, so the key
  # is supplied as an EnvironmentFile decrypted by sops.
  sops.secrets."homepage.env".restartUnits = [ "homepage-dashboard.service" ];

  services.homepage-dashboard = {
    enable = true;
    openFirewall = true;
    listenPort = 8082;
    allowedHosts = "switchboard.lion-zebra.ts.net:8082";
    environmentFiles = [ config.sops.secrets."homepage.env".path ];

    settings = {
      title = "Switchboard - Homepage";
      background = {
        image = "https://i.imgur.com/WY6kWpl.png";
        blur = "sm";
        saturate = 50;
        brightness = 10;
        opacity = 10;
      };
      favicon = "https://raw.githubusercontent.com/fmeus/raspberrypi/refs/heads/master/favicon.ico";
      theme = "dark";
      color = "slate";
      quicklaunch = {
        searchDescriptions = false;
        hideInternetSearch = true;
        showSearchSuggestions = false;
      };
      providers.openweathermap = "{{HOMEPAGE_VAR_OPENWEATHERMAP}}";
    };

    services = [
      {
        "Switchboard" = [
          {
            "Pi-hole" = {
              icon = "pi-hole";
              href = "http://switchboard.lion-zebra.ts.net:80/admin";
              description = "DNS (independent instance)";
            };
          }
          {
            "Gatus" = {
              icon = "gatus";
              href = "http://switchboard.lion-zebra.ts.net:8080";
              description = "Monitor machines and services for health";
            };
          }
          {
            "SearXNG" = {
              icon = "searx";
              href = "http://switchboard.lion-zebra.ts.net:6040";
              description = "Search Engine";
            };
          }
        ];
      }
      {
        "Monitoring" = [
          {
            "Home Assistant" = {
              icon = "home-assistant";
              href = "http://pilab.lion-zebra.ts.net:8123/lovelace";
              description = "Home control";
            };
          }
          {
            "Aero Assistant" = {
              icon = "home-assistant";
              href = "https://homeassistant.pratiekserver.pp.ua/lovelace";
              description = "Home control";
            };
          }
          {
            "Proxmox (MiniPC)" = {
              icon = "proxmox";
              href = "https://192.168.1.149:8006";
              description = "VMs & containers";
            };
          }
          {
            "PiKVM (MiniPC)" = {
              icon = "pikvm";
              href = "https://zerokvm.lion-zebra.ts.net";
              description = "PiKVM connected to MiniPC";
            };
          }
          {
            "Proxmox (Miner)" = {
              icon = "proxmox";
              href = "https://192.168.1.99:8006";
              description = "VMs & containers";
            };
          }
        ];
      }
      {
        "Services" = [
          {
            "Navidrome" = {
              icon = "navidrome";
              href = "http://pilab.lion-zebra.ts.net:4533";
              description = "Music Server & Streamer";
            };
          }
          {
            "Syncplay" = {
              icon = "syncplay.png";
              href = "http://pilab.lion-zebra.ts.net:8999";
              description = "Play media in sync";
            };
          }
          {
            "Tube Archivist" = {
              icon = "tube-archivist";
              href = "http://pilab.lion-zebra.ts.net:8454";
              description = "Tube Archivist";
            };
          }
          {
            "Copyparty" = {
              icon = "copyparty";
              href = "http://pilab.lion-zebra.ts.net:3923";
              description = "Filebrowser";
            };
          }
          {
            "Memos" = {
              icon = "memos";
              href = "http://pilab.lion-zebra.ts.net:5230";
              description = "Take Notes";
            };
          }
          {
            "Mealie" = {
              icon = "mealie";
              href = "http://pilab.lion-zebra.ts.net:9091";
              description = "Food Recipes";
            };
          }
          {
            "Password Pusher" = {
              icon = "passwordpusher";
              href = "http://pilab.lion-zebra.ts.net:5100";
              description = "Share Passwords Securely";
            };
          }
          {
            "Grocy" = {
              icon = "grocy";
              href = "http://pilab.lion-zebra.ts.net:9283";
              description = "Grocery Inventory";
            };
          }
          {
            "Habitica" = {
              icon = "habitica";
              href = "http://pilab.lion-zebra.ts.net:3000";
              description = "Gamify Your Life";
            };
          }
          {
            "Homebox" = {
              icon = "homebox";
              href = "http://pilab.lion-zebra.ts.net:3100";
              description = "Home Inventory";
            };
          }
          {
            "Ollama" = {
              icon = "ollama.png";
              href = "http://pilab.lion-zebra.ts.net:3020";
              description = "Open WebUI";
            };
          }
          {
            "Readeck" = {
              icon = "readeck";
              href = "http://pilab.lion-zebra.ts.net:2399";
              description = "Read Later";
            };
          }
          {
            "Manyfold" = {
              icon = "manyfold";
              href = "http://pilab.lion-zebra.ts.net:3214";
              description = "3D models";
            };
          }
          {
            "Vaultwarden" = {
              icon = "vaultwarden";
              href = "https://vaultwarden.clawsiecats.omg.lol";
              description = "Password Manager";
            };
          }
          {
            "Linkding" = {
              icon = "linkding";
              href = "http://pilab.lion-zebra.ts.net:9090";
              description = "Bookmarks";
            };
          }
          {
            "Scriberr" = {
              icon = "scriberr.png";
              href = "http://pilab.lion-zebra.ts.net:3025";
              description = "Audio Transcription";
            };
          }
          {
            "Baikal" = {
              icon = "baikal";
              href = "http://pilab.lion-zebra.ts.net:5880";
              description = "CalDAV / CardDAV";
            };
          }
          {
            "Qdrant" = {
              icon = "qdrant";
              href = "http://pilab.lion-zebra.ts.net:6333/dashboard";
              description = "Vector Database";
            };
          }
          {
            "Audiobookshelf" = {
              icon = "audiobookshelf";
              href = "http://pilab.lion-zebra.ts.net:13378";
              description = "Audiobooks & Podcasts";
            };
          }
          {
            "Calibre Web Automated" = {
              icon = "calibre";
              href = "http://pilab.lion-zebra.ts.net:8083";
              description = "eBooks";
            };
          }
          {
            "Calibre Book Downloader" = {
              icon = "calibre";
              href = "http://pilab.lion-zebra.ts.net:8084";
              description = "eBook Downloader";
            };
          }
          {
            "Meridian" = {
              icon = "anthropic";
              href = "http://pilab.lion-zebra.ts.net:3456";
              description = "Claude API Proxy";
            };
          }
          {
            "AudioMuse" = {
              icon = "audiomuse";
              href = "http://pilab.lion-zebra.ts.net:8250";
              description = "AudioMuse";
            };
          }
          {
            "Gramps Web" = {
              icon = "gramps";
              href = "http://pilab.lion-zebra.ts.net:8822";
              description = "Family tree";
            };
          }
        ];
      }
      {
        "Frontends" = [
          {
            "Nitter" = {
              icon = "nitter";
              href = "http://pilab.lion-zebra.ts.net:5095";
              description = "Twitter / X";
            };
          }
          {
            "Invidious" = {
              icon = "invidious";
              href = "http://pilab.lion-zebra.ts.net:6030";
              description = "YouTube";
            };
          }
          {
            "Redlib" = {
              icon = "redlib.png";
              href = "http://pilab.lion-zebra.ts.net:6020";
              description = "Reddit";
            };
          }
          {
            "Redlib" = {
              icon = "redlib.png";
              href = "http://pilab.lion-zebra.ts.net:6020";
              description = "Reddit";
            };
          }
          {
            "SearXNG" = {
              icon = "searx";
              href = "http://pilab.lion-zebra.ts.net:6040";
              description = "Search Engine";
            };
          }
        ];
      }
      {
        "*arr Stack" = [
          {
            "Jellyfin" = {
              icon = "jellyfin";
              href = "http://radrubble.lion-zebra.ts.net:8096";
              description = "Media Server";
            };
          }
          {
            "Jellyseerr" = {
              icon = "jellyseerr";
              href = "http://radrubble.lion-zebra.ts.net:5055";
              description = "Media Requests";
            };
          }
          {
            "Sonarr" = {
              icon = "sonarr";
              href = "http://radrubble.lion-zebra.ts.net:8989";
              description = "TV Series";
            };
          }
          {
            "Radarr" = {
              icon = "radarr";
              href = "http://radrubble.lion-zebra.ts.net:7878";
              description = "Movies";
            };
          }
          {
            "Bazarr" = {
              icon = "bazarr";
              href = "http://radrubble.lion-zebra.ts.net:6767";
              description = "Subtitles";
            };
          }
          {
            "Prowlarr" = {
              icon = "prowlarr";
              href = "http://radrubble.lion-zebra.ts.net:9696";
              description = "Torrent Requests";
            };
          }
          {
            "qBittorrent" = {
              icon = "qbittorrent";
              href = "http://radrubble.lion-zebra.ts.net:8085";
              description = "Torrenting";
            };
          }
        ];
      }
    ];
  };
}

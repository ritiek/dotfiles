{ config, pkgs, lib, inputs, ... }:

let
  # Dynamically extract sudo target paths from HA shell_command definitions.
  # Any command using "sudo -E <path>" will automatically get a sudo-rs rule.
  haShellCmds = config.services.home-assistant.config.shell_command or {};
  extractSudoPath = cmd:
    let m = builtins.match ".*/sudo -E ([^ ]+).*" cmd;
    in if m != null then builtins.head m else null;
  hasSudoPaths = lib.filter (p: p != null) (map extractSudoPath (lib.attrValues haShellCmds));
in

{
  imports = [
    inputs.sops-nix.nixosModules.sops
    inputs.nix-index-database.nixosModules.nix-index
    ./hw-config.nix
    ./home
    ./services-paths.nix
    ./services/restic.nix
    ./services/lsyncd.nix
    ./services/hermes
    ./services/home-assistant
    ./services/homelab-trigger.nix
    # ./services/attic.nix
    # ./services/paperless-ngx.nix
    ./../../modules/nix.nix
    ./../../modules/sops.nix
    ./../../modules/wifi.nix
    ./../../modules/tailscale-controlplane.nix
    ./../../modules/netbird.nix
    ./../../modules/attic-watch-store.nix
    ./../../modules/usbipd.nix
    ./../../modules/3proxy.nix
    # Generated using:
    # $ compose2nix --env_files=stack.env --include_env_files=true --check_systemd_mounts=true --auto_start=false --remove_volumes=true --runtime=docker
    ./compose/pihole
    ./compose/homepage.nix
    # ./compose/dashy.nix
    ./compose/immich
    ./compose/uptime-kuma.nix
    ./compose/tubearchivist
    ./compose/paperless-ngx
    ./compose/forgejo
    ./compose/vaultwarden
    ./compose/backvault
    ./compose/navidrome.nix
    ./compose/memos.nix
    ./compose/syncthing.nix
    ./compose/miniflux
    ./compose/gotify.nix
    # ./compose/shiori
    ./compose/homebox.nix
    ./compose/grocy
    ./compose/changedetection
    ./compose/frigate
    ./compose/habitica
    ./compose/ollama-webui
    ./compose/pwpush
    ./compose/dawarich
    ./compose/rustdesk.nix
    ./compose/simplexchat
    # ./compose/filebrowser-quantum.nix
    ./compose/copyparty.nix
    ./compose/nitter.nix
    ./compose/mealie
    # ./compose/karakeep
    ./compose/n8n
    ./compose/transmission
    ./compose/qbittorrent.nix
    ./compose/jellyfin.nix
    ./compose/radarr.nix
    ./compose/sonarr.nix
    ./compose/bazarr.nix
    ./compose/prowlarr.nix
    ./compose/jellyseerr.nix
    ./compose/glances.nix
    ./compose/calibre-web-automated
    ./compose/calibre-web-automated-book-downloader.nix
    ./compose/audiobookshelf.nix
    ./compose/baikal.nix
    ./compose/qdrant
    ./compose/scriberr.nix
    ./compose/atuin
    ./compose/searxng.nix
    ./compose/invidious
    ./compose/redlib.nix
    ./compose/meshmonitor.nix
    ./compose/manyfold
    ./compose/linkding
    ./compose/open-archiver
    ./compose/meridian
    ./compose/audiomuse
    ./compose/grampsweb.nix
    ./compose/readeck.nix
    # ./compose/kopia
  ];

  sops.secrets = {
    # "jitsi.htpasswd" = {
    #   owner = "nginx";
    # };
    "syncplay.password" = {};
    "rnixbld.id_ed25519" = {
      mode = "600";
      owner = "root";
      group = "nixbld";
    };
    "yubiluks.env" = {};
    "hermes.env" = {};

    # Hermes-only secrets (system-level; read by hermes-agent ExecStartPre as root).
    "groq_api.key" = { owner = "ritiek"; };
    "elevenlabs_api.key" = { owner = "ritiek"; };

    # Shared secrets: also declared at home-manager level (opencode.nix) for
    # opencode's MCPs. Declared here independently so the system-level hermes
    # service reads from /run/secrets instead of opencode's home-manager path.
    "github.token" = { owner = "ritiek"; };
    "karakeep_api.address" = { owner = "ritiek"; };
    "karakeep_api.key" = { owner = "ritiek"; };
    "paperless.url" = { owner = "ritiek"; };
    "paperless_api.key" = { owner = "ritiek"; };
    "paperless_public.url" = { owner = "ritiek"; };
    "home_assistant.long_lived_token" = { owner = "ritiek"; };
    "searx.url" = { owner = "ritiek"; };
    "opencode_api.key" = { owner = "ritiek"; };
  };

  nixpkgs.config.allowUnfree = false;
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "kongo09/philips_airpurifier_coap"
  ];

  # nix = {
  #   distributedBuilds = true;
  #   buildMachines = [
  #     {
  #       hostName = "keyberry.lion-zebra.ts.net";
  #       system = pkgs.stdenv.hostPlatform.system;
  #       protocol = "ssh-ng";
  #       sshUser = "rnixbld";
  #       sshKey = config.sops.secrets."rnixbld.id_ed25519".path;
  #       publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU93TTJ6N0JENWhrbGJSZURkT056OStOQUh5TVdtMmY1dHhKMlhDZTA2dXUK";
  #       maxJobs = 4;
  #       speedFactor = 1;
  #       supportedFeatures = [
  #         "nixos-test"
  #         "benchmark"
  #         "big-parallel"
  #         "kvm"
  #       ];
  #     }
  #     {
  #       hostName = "radrubble.lion-zebra.ts.net";
  #       system = pkgs.stdenv.hostPlatform.system;
  #       protocol = "ssh-ng";
  #       sshUser = "rnixbld";
  #       sshKey = config.sops.secrets."rnixbld.id_ed25519".path;
  #       publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUJSRjdFcXYxUHJTQlBmQnFaenBLalBxUGZiSjhNc25qKzNFSFA4V2NweFYK";
  #       maxJobs = 4;
  #       speedFactor = 1;
  #       supportedFeatures = [
  #         "nixos-test"
  #         "benchmark"
  #         "big-parallel"
  #         "kvm"
  #       ];
  #     }
  #     {
  #       hostName = "zerostash.lion-zebra.ts.net";
  #       system = pkgs.stdenv.hostPlatform.system;
  #       protocol = "ssh-ng";
  #       sshUser = "rnixbld";
  #       sshKey = config.sops.secrets."rnixbld.id_ed25519".path;
  #       publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU0rdjFsZVJwVGR5SGxNSlFsWStLZ1NnUHVSZlUwRzNWdG1hQ0pOeGpBbWwK";
  #       maxJobs = 4;
  #       speedFactor = 1;
  #       supportedFeatures = [
  #         "nixos-test"
  #         "benchmark"
  #         "big-parallel"
  #         "kvm"
  #       ];
  #     }
  #   ];
  # };

  nixpkgs.overlays = [
    # (final: _prev: {
    #   nixpkgs-for-raspberry-pi-nix = import inputs.nixpkgs-for-raspberry-pi-nix {
    #     inherit (final) system;
    #     config.allowUnfree = true;
    #   };
    # })
    # XXX: Pin pipewire to nixpkgs-for-raspberry-pi-nix (last known good commit) for
    # now since it's been failing to build from master.
    # (final: prev: {
    #   pipewire = final.nixpkgs-for-raspberry-pi-nix.pipewire or prev.pipewire;
    #   gjs = final.nixpkgs-for-raspberry-pi-nix.gjs or prev.gjs;
    #   libsecret = final.nixpkgs-for-raspberry-pi-nix.libsecret or prev.libsecret;
    # })

     # (final: _prev: {
     #   stable = import inputs.stable {
     #     inherit (final) system;
     #     config.allowUnfree = true;
     #   };
     # })
     (final: _prev: {
       unstable = import inputs.unstable {
         inherit (final) system;
         config.allowUnfree = true;
       };
     })
     # (final: _prev: {
     #   local = import inputs.local {
     #     inherit (final) system;
     #     config.allowUnfree = true;
     #   };
     # })
  ];

  networking.hostName = "pilab";
  time.timeZone = "Asia/Kolkata";

  services.tailscale.extraUpFlags = lib.mkAfter [
    "--accept-routes"
    "--accept-dns=false"
  ];

  services.dnsmasq = {
    enable = true;
    settings = {
      server = [
        "/lion-zebra.ts.net/100.100.100.100"
        "/pihole/127.0.0.1#5335"
        "127.0.0.1#5335"
        "1.1.1.1"
      ];
      strict-order = true;
      # Don't read /etc/resolv.conf for upstream servers; we define them above.
      no-resolv = true;
    };
  };

  # Prevent dhcpcd from overwriting resolved's stub with DHCP-supplied servers.
  networking.dhcpcd.extraConfig = "nooption domain_name_servers";

  users = {
    defaultUserShell = pkgs.zsh;
    mutableUsers = false;
    groups.i2c = {};
    groups.gpio = {};

    users.ritiek = {
      isNormalUser = true;
      # Keep user systemd services (e.g. pipewire/wireplumber) running without
      # an interactive login. Required for headless Bluetooth audio at boot.
      linger = true;
      extraGroups = [
        "wheel"
        "i2c"
        "gpio"
        "adbusers"
        "hermes"
      ];
      openssh.authorizedKeys.keys = [
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINmHZVbmzdVkoONuoeJhfIUDRvbhPeaSkhv0LXuNIyFfAAAAEXNzaDpyaXRpZWtAeXViaWth"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHVwHXOotXjPLC/fXIEu/Xnc5ZiIwOKK4Amas/rb9/ZGAAAAEnNzaDpyaXRpZWtAeXViaWtrbw=="
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIAUVNBe5AkMEPT9fell8hjKrRh6CNaZBDNeBozB8TJseAAAAFHNzaDpyaXRpZWtAeXViaXNjdWl0"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIEDg65I7F0cj4CFSbIlJ004zwq4IsxtAgyPlzFGXOUOUAAAAEnNzaDpyaXRpZWtAeXViaXNlYQ=="

        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC8R2qe15XyGUVQSHlPsDg6lE9ekfoB+qRA6jjw9pXD5"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG8pxSJhzTQav5ZHhaqDMy3zMcOBRyXdvNAE2gXM8y6h"
      ];
      packages = [
        inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };

    users.immi = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
      ];
      packages = [
        inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };

    users.rnixbld = {
      isSystemUser = true;
      group = "users";
      shell = pkgs.bash;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHPlUpYpBOffFgrMAViDxiTCrVCRP6wQIFWd7/KiNkV2"
      ];
    };
  };

  environment = {
    systemPackages = with pkgs; [
      coreutils
      systemd
      dconf
      wget
      curl
      usbutils
    ];
  };

  # nixpkgs.config.permittedInsecurePackages = [
  #   "jitsi-meet-1.0.8043"
  # ];

  services = {
    udisks2.enable = true;

    udev.extraRules = ''
      KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
      SUBSYSTEM=="gpio", KERNEL=="gpiochip*", GROUP="gpio", MODE="0660"
    '';
    
    openssh = {
      enable = true;
      startWhenNeeded = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        X11Forwarding = true;
        X11UseLocalhost = false;
      };
      knownHosts = {
        "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      };
    };

    pipewire = {
      enable = true;
      # Headless box: socket activation never triggers without an interactive
      # login, leaving pipewire dead and bluez without an A2DP backend.
      # Start pipewire/wireplumber at boot instead. See wantedBy + linger below.
      # https://wiki.nixos.org/wiki/PipeWire (Headless operation)
      socketActivation = false;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      wireplumber = {
        enable = true;
        configPackages = [
          (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/10-bluetooth-seat-fix.conf" ''
            wireplumber.profiles = {
              main = {
                monitor.bluez.seat-monitoring = disabled
                support.logind = disabled
              }
            }
          '')
          (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/51-bluez-config.conf" ''
            monitor.bluez.properties = {
              bluez5.roles = [ a2dp_sink a2dp_source bap_sink bap_source hsp_hs hsp_ag hfp_hf hfp_ag ]
              bluez5.codecs = [ sbc sbc_xq aac ]
              bluez5.auto-connect = [ a2dp_sink a2dp_source ]
            }
          '')
        ];
      };
      pulse.enable = true;
      jack.enable = true;

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
    };

    # NOTE: This doesn't seem to work as is since Jitsi requires HTTPS.
    # jitsi-meet = {
    #   enable = true;
    #   hostName = "pilab.lion-zebra.ts.net";
    #   nginx.enable = false;
    #   config = {
    #     enableInsecureRoomNameWarning = true;
    #     fileRecordingsEnabled = false;
    #     liveStreamingEnabled = false;
    #     prejoinPageEnabled = true;
    #   };
    #   interfaceConfig = {
    #     SHOW_JITSI_WATERMARK = false;
    #     SHOW_WATERMARK_FOR_GUESTS = false;
    #   };
    # };
    #
    # jitsi-videobridge.openFirewall = true;

    syncplay = {
      enable = true;
      passwordFile = config.sops.secrets."syncplay.password".path;
    };

    # Migrated from the conduwuit/continuwuity Docker container to the native
    # NixOS module. The upstream Docker image ships jemalloc compiled for 4KB
    # pages and crashes on this Pi 5's 16KB-page kernel; the nixpkgs build
    # (compiled locally) uses the correct page size.
    matrix-continuwuity = {
      enable = true;
      admin.enable = true;
      settings.global = {
        server_name = "pilab.lion-zebra.ts.net";
        port = [ 6168 ];
        address = [ "0.0.0.0" "::" ];
        allow_registration = false;
        yes_i_am_very_very_sure_i_want_an_open_registration_server_prone_to_abuse = false;
        allow_federation = false;
        allow_encryption = true;
        trusted_servers = [ ];
        max_request_size = 20000000;
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 6168 ];

  # With socket activation disabled, start wireplumber at boot so the bluez
  # A2DP backend is registered before any device tries to connect (headless).
  # https://wiki.nixos.org/wiki/PipeWire (Headless operation)
  systemd.user.services.wireplumber.wantedBy = [ "default.target" ];

  programs = {
    nix-index-database.comma.enable = true;
    zsh.enable = true;
    # gnupg.agent.enable = true;
  };

  virtualisation = {
    oci-containers.backend = "docker";
    docker = {
      enable = true;
      autoPrune.enable = true;
      # Expand docker's pool of available subnets by creating
      # smaller subnets.
      # At the time of writing this - docker defaults this to
      # 32, which means it can allocate subnets to a maximum
      # of 32 docker compose swarms at the same time.
      daemon.settings = {
        bip = "10.255.0.1/24";
        fixed-cidr = "10.255.0.0/24";
        default-address-pools = [
          { base = "10.240.0.0/12"; size = 24; }    # ~4096 /24 networks
          { base = "172.20.0.0/16"; size = 24; }    # +256 /24 networks
        ];
        mtu = 9000;
      };
    };
  };

  security = {
    sudo.enable = false;
    sudo-rs = {
      enable = true;
      wheelNeedsPassword = lib.mkDefault false;
      extraRules = lib.optional (hasSudoPaths != []) {
        users = [ "hass" ];
        commands = map (path: {
          command = path;
          options = [ "NOPASSWD" "SETENV" ];
        }) hasSudoPaths;
      };
    };
  };

  # This are needed when forwarding X11 over SSH or otherwise if I setup a
  # desktop environment in the future.
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      cantarell-fonts
      material-design-icons
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif

      nerd-fonts.fantasque-sans-mono
      nerd-fonts.inconsolata-go
      nerd-fonts.jetbrains-mono
      # nerd-fonts.fira-code
      # nerd-fonts.noto
    ];
  };

  # NOTE: For modes supported by the CPU, run:
  # $ cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
  powerManagement.cpuFreqGovernor = "conservative";

  zramSwap = {
    enable = true;
    memoryPercent = 250;
  };

  networking.localCommands = ''
    # Prioritize default route over Tailscale route for default gateway.
    ip rule add to 192.168.2.0/24 priority 2500 lookup main
  '';

  boot.tmp = {
    useTmpfs = false;
    cleanOnBoot = true;
  };

  systemd.settings.Manager.RuntimeWatchdogSec = "360s";

  # nix.settings = {
  #   extra-platforms = [ "armv6l-linux" ];
  #   system-features = [ "benchmark" "big-parallel" "nixos-test" "gccarch-armv6kz" ];
  # };

  hardware.enableRedistributableFirmware = true;
  system.stateVersion = "24.11";
}
